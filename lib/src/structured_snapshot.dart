import 'errors.dart';

/// A replaceable projection of native guided content that is still being generated.
///
/// Containers may be partial; incomplete strings/numbers are withheld rather
/// than repaired. [presentPaths] identifies observed nodes and [completePaths]
/// the native nodes marked complete. Paths are JSON Pointers rooted at #.
/// This is display state, not a final response or permission to run business logic.
final class StructuredSnapshot {
  StructuredSnapshot._({required this.hasValue, required this.value,
    required this.isComplete, required this.presentPaths, required this.completePaths});

  /// Decodes and freezes a native snapshot, rejecting malformed channel payloads.
  factory StructuredSnapshot.fromMap(Map<Object?, Object?> map) {
    final hasValue = map['hasValue'];
    final isComplete = map['isComplete'];
    final present = _paths(map['presentPaths']);
    final complete = _paths(map['completePaths']);
    if (hasValue is! bool || isComplete is! bool || !map.containsKey('value') ||
        !present.contains('#') || !present.toSet().containsAll(complete) ||
        complete.contains('#') != isComplete ||
        (hasValue && !isComplete && map['value'] is! Map && map['value'] is! List) ||
        (!hasValue && (map['value'] != null || isComplete))) {
      _fail();
    }
    return StructuredSnapshot._(hasValue: hasValue, value: _freeze(map['value'], 0),
      isComplete: isComplete, presentPaths: List<String>.unmodifiable(present),
      completePaths: List<String>.unmodifiable(complete));
  }

  /// Whether the root has a safe projection, independently of truthiness/null.
  final bool hasValue;

  /// Immutable projected data; missing/incomplete leaves are not synthesized.
  /// Arrays retain the contiguous available prefix, preserving source indices.
  final Object? value;

  /// Native root completeness; even true remains a snapshot until completion.
  final bool isComplete;

  /// Observed node paths, including a begun leaf whose value is still withheld.
  /// Native traversal order is preserved; array traversal stops at a withheld leaf.
  final List<String> presentPaths;

  /// Observed paths whose native content is complete, without validating facts.
  final List<String> completePaths;

  static List<String> _paths(Object? raw) {
    if (raw is! List) _fail();
    final paths = <String>[];
    for (final path in raw) {
      if (path is! String || !(path == '#' || path.startsWith('#/')) || paths.contains(path) ||
          path.replaceAll('~0', '').replaceAll('~1', '').contains('~')) {
        _fail();
      }
      paths.add(path);
    }
    return paths;
  }

  static Object? _freeze(Object? value, int depth) {
    if (depth > 16) _fail();
    if (value is Map) {
      final result = <String, Object?>{};
      for (final entry in value.entries) {
        if (entry.key is! String) _fail();
        result[entry.key as String] = _freeze(entry.value, depth + 1);
      }
      return Map<String, Object?>.unmodifiable(result);
    }
    if (value is List) return List<Object?>.unmodifiable(value.map((child) => _freeze(child, depth + 1)));
    if (value == null || value is String || value is bool || (value is num && value.isFinite)) return value;
    _fail();
  }

  static Never _fail() => throw const FoundationModelsException(
    code: FoundationModelsErrorCode.parsingFailure,
    message: 'The native structured snapshot payload is invalid.',
    details: <String, Object?>{'decodingStage': 'structuredSnapshot'},
  );
}

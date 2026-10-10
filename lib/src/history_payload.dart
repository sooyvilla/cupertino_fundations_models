import 'errors.dart';

/// Strict shared parsing for versioned history payloads without logging their data.
final class HistoryPayload {
  /// Rejects malformed history with the existing typed package error contract.
  static Never fail() => throw const FoundationModelsException(code: FoundationModelsErrorCode.invalidRequest,
    message: 'The session history payload is malformed or outside its supported profile.');

  /// Copies a string-keyed payload map.
  static Map<String, Object?> map(Object? raw) {
    if (raw is! Map || raw.keys.any((key) => key is! String)) fail();
    return Map<String, Object?>.from(raw);
  }

  /// Reads a string field, allowing empty text only when explicitly requested.
  static String string(Map<String, Object?> map, String key, {bool empty = false}) {
    final value = map[key];
    if (value is! String || (!empty && value.isEmpty)) fail();
    return value;
  }

  /// Reads an optional string without converting other values to text.
  static String? optionalString(Map<String, Object?> map, String key) {
    final value = map[key];
    if (value != null && value is! String) fail();
    return value as String?;
  }

  /// Reads an ordered list.
  static List<Object?> list(Object? value) {
    if (value is! List) fail();
    return List<Object?>.from(value);
  }

  /// Reads an immutable string list.
  static List<String> strings(Object? value) => List<String>.unmodifiable(
    list(value).map((item) { if (item is! String) fail(); return item; }));

  /// Freezes JSON-safe maps/lists without retaining caller mutations.
  static Object? freeze(Object? value, [int depth = 0]) {
    if (depth > 32) fail();
    if (value is Map) return Map<String, Object?>.unmodifiable(map(value).map((key, item) => MapEntry(key, freeze(item, depth + 1))));
    if (value is List) return List<Object?>.unmodifiable(value.map((item) => freeze(item, depth + 1)));
    if (value == null || value is String || value is bool || (value is num && value.isFinite)) return value;
    fail();
  }

  /// Compares registrations structurally, preserving list order but not map order.
  static bool equal(Object? left, Object? right) {
    if (left is Map && right is Map) {
      return left.length == right.length && left.keys.every((key) => right.containsKey(key) && equal(left[key], right[key]));
    }
    if (left is List && right is List) {
      return left.length == right.length && List<bool>.generate(left.length, (index) => equal(left[index], right[index])).every((value) => value);
    }
    return left == right;
  }
}

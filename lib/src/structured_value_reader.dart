import 'structured_partial_field.dart';
import 'structured_snapshot.dart';

/// Structural decoding shared by generated final decoders and partial views.
/// It checks types/presence without validating native guides or business truth.
final class StructuredValueReader {
  /// Reads a closed string-keyed object, rejecting unexpected fields.
  static Map<String, Object?> object(Object? value, String path, Set<String> fields) {
    if (value is! Map || value.keys.any((key) => key is! String || !fields.contains(key))) _fail(path, 'object fields');
    return Map<String, Object?>.from(value);
  }

  /// Reads required/optional presence independently of allowed explicit null.
  static T? field<T>(Map<String, Object?> object, String name, String path,
      T Function(Object?, String) decode, {required bool required, required bool allowNull}) {
    final pointer = childPath(path, name);
    if (!object.containsKey(name)) {
      if (required) _fail(pointer, 'required presence');
      return null;
    }
    final value = object[name];
    if (value == null) {
      if (!allowNull) _fail(pointer, 'non-null value');
      return null;
    }
    return decode(value, pointer);
  }

  /// Reads a string without coercion.
  static String string(Object? value, String path) {
    if (value is! String) _fail(path, 'string');
    return value;
  }

  /// Reads a signed 64-bit integer without rounding fractional values.
  static int integer(Object? value, String path) {
    if (value is! int || value < -9223372036854775808 || value > 9223372036854775807) _fail(path, 'integer');
    return value;
  }

  /// Reads an exact finite number, retaining its original integer/double form.
  static num number(Object? value, String path) {
    if (value is! num || !value.isFinite) _fail(path, 'finite number');
    return value;
  }

  /// Reads a double without silently losing the precision of an integer.
  static double doubleValue(Object? value, String path) {
    final numeric = number(value, path);
    final result = numeric.toDouble();
    if (!result.isFinite || (numeric is int && BigInt.from(result) != BigInt.from(numeric))) _fail(path, 'exact double');
    return result;
  }

  /// Reads a boolean; false remains a valid value.
  static bool boolean(Object? value, String path) {
    if (value is! bool) _fail(path, 'boolean');
    return value;
  }

  /// Converts every list item in source order and returns an immutable list.
  static List<T> list<T>(Object? value, String path, T Function(Object?, String) decode) {
    if (value is! List) _fail(path, 'list');
    return List<T>.unmodifiable([for (var index = 0; index < value.length; index++) decode(value[index], '$path/$index')]);
  }

  /// Converts an explicit nullable value, primarily for nullable list elements.
  static T? nullable<T>(Object? value, String path, T Function(Object?, String) decode) => value == null ? null : decode(value, path);

  /// Resolves an exact case-sensitive enum name without a fallback constant.
  static T enumValue<T extends Enum>(Object? value, String path, List<T> values) {
    final name = string(value, path);
    for (final item in values) { if (item.name == name) return item; }
    _fail(path, 'declared enum name');
  }

  /// Escapes a JSON property name before appending it to a native pointer.
  static String childPath(String path, String name) => '$path/${name.replaceAll('~', '~0').replaceAll('/', '~1')}';

  /// Projects field state without converting unavailable primitive leaves.
  static StructuredPartialField<T> partialField<T>(StructuredSnapshot snapshot, String path,
      T Function(Object?, String) decode, {bool container = false}) {
    final present = snapshot.presentPaths.contains(path);
    final complete = snapshot.completePaths.contains(path);
    final selected = _lookup(snapshot.value, path);
    final available = snapshot.hasValue && present && selected.found && (complete || container);
    return StructuredPartialField<T>(path: path, isPresent: present, isComplete: complete,
      hasValue: available, value: available ? decode(selected.value, path) : null);
  }

  /// Reads a partial object's available fields without requiring final presence.
  static Map<String, Object?> partialObject(StructuredSnapshot snapshot, String path, Set<String> fields) {
    final selected = _lookup(snapshot.value, path);
    if (!snapshot.hasValue || !selected.found) return <String, Object?>{};
    return object(selected.value, path, fields);
  }

  /// Converts the contiguous safe array prefix, withholding incomplete leaves.
  static List<T> partialList<T>(StructuredSnapshot snapshot, Object? value, String path,
      T Function(Object?, String) decode, {bool containers = false}) {
    if (value is! List) _fail(path, 'list');
    final result = <T>[];
    for (var index = 0; index < value.length; index++) {
      final pointer = '$path/$index';
      if (!snapshot.completePaths.contains(pointer) && !containers) break;
      result.add(decode(value[index], pointer));
    }
    return List<T>.unmodifiable(result);
  }

  static ({bool found, Object? value}) _lookup(Object? value, String path) {
    if (path == '#') return (found: true, value: value);
    if (!path.startsWith('#/')) _fail(path, 'JSON Pointer');
    var cursor = value;
    for (final raw in path.substring(2).split('/')) {
      if (raw.replaceAll('~0', '').replaceAll('~1', '').contains('~')) _fail(path, 'JSON Pointer escape');
      final name = raw.replaceAll('~1', '/').replaceAll('~0', '~');
      if (cursor is Map && cursor.containsKey(name)) { cursor = cursor[name]; }
      else if (cursor is List) {
        final index = int.tryParse(name);
        if (index == null || index < 0 || index >= cursor.length || '$index' != name) return (found: false, value: null);
        cursor = cursor[index];
      } else { return (found: false, value: null); }
    }
    return (found: true, value: cursor);
  }

  static Never _fail(String path, String expected) => throw FormatException('Expected $expected at $path.');
}

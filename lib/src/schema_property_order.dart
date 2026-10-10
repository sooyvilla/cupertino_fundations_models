import 'schema_property.dart';

/// Shared validation for the optional order of every declared object property.
final class SchemaPropertyOrder {
  /// Validates a full permutation; omission preserves native alphabetical order.
  static void validate(String type, Map<String, SchemaProperty>? properties, List<String>? order) {
    if (order == null) return;
    final fields = properties?.keys.toSet() ?? <String>{};
    if (type.toLowerCase() != 'object' || order.toSet().length != order.length ||
        order.length != fields.length || !fields.containsAll(order)) {
      throw ArgumentError.value(order, 'propertyOrder', 'Declare each object property exactly once.');
    }
  }
}

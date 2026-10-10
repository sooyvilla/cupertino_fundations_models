/// Opts a concrete Dart model into the separate development-time generator.
/// Manual StructuredSchema definitions and app decoders remain available.
final class StructuredModel {
  /// Selects the schema label, optional guides/order and generative constructor.
  /// Nullable properties are optional by default; [explicitNulls] permits present
  /// null and requires native null-schema support on OS 26.4 or newer.
  const StructuredModel({this.name, this.description, this.propertyOrder,
    this.explicitNulls = false, this.constructor = ''});

  /// Schema name; omission uses the annotated class name.
  final String? name;
  /// Optional native guidance for this object.
  final String? description;
  /// Full permutation of JSON field names; omission keeps native alphabetical order.
  final List<String>? propertyOrder;
  /// Whether nullable object fields accept explicit null, separately from omission.
  final bool explicitNulls;
  /// Public generative constructor name, or empty for the unnamed constructor.
  final String constructor;
}

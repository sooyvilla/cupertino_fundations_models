/// Optional guides and presence choices for a generated model field.
/// Constraints use the same native semantics as SchemaProperty constructors.
final class StructuredField {
  /// Describes a supported field without introducing runtime generation tooling.
  const StructuredField({this.name, this.description, this.required,
    this.minimum, this.maximum, this.pattern, this.minItems, this.maxItems, this.exactItems});

  /// JSON field name; omission uses the Dart field name.
  final String? name;
  /// Optional native field guidance.
  final String? description;
  /// Required presence; omission requires non-nullable fields only.
  /// A non-nullable field cannot be made optional by this generator.
  final bool? required;
  /// Inclusive numeric lower bound, restricted to numeric fields.
  final num? minimum;
  /// Inclusive numeric upper bound, restricted to numeric fields.
  final num? maximum;
  /// Swift regex guidance for a string, not a Dart data validator.
  final String? pattern;
  /// Minimum array count; cannot be combined with [exactItems].
  final int? minItems;
  /// Maximum array count; cannot be combined with [exactItems].
  final int? maxItems;
  /// Exact array count; cannot be combined with range bounds.
  final int? exactItems;
}

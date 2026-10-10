/// A typed display projection retaining native presence and completeness.
/// It is never a terminal model response or permission to use business facts.
final class StructuredPartialField<T> {
  /// Creates field state; present null has [hasValue] true and [value] null.
  const StructuredPartialField({required this.path, required this.isPresent,
    required this.isComplete, required this.hasValue, this.value});
  /// Native JSON Pointer identifying this field in the original snapshot.
  final String path;
  /// Whether the native node has begun, even if its value is withheld.
  final bool isPresent;
  /// Whether this node is natively complete, independently of terminal completion.
  final bool isComplete;
  /// Whether a safe typed projection is supplied, separately from null/truthiness.
  final bool hasValue;
  /// Typed projection, or null for unavailable/present-null values.
  final T? value;
}

/// The reliability of a token count for one measured component.
enum TokenPrecision {
  /// The native tokenizer counted this component.
  exact,
  /// The count is an estimate rather than an exact native measurement.
  estimated,
  /// No usable count is available.
  unavailable,
}

/// A component count that distinguishes zero from unavailable information.
final class TokenMeasurement {
  /// Creates a measurement and an optional explanation of its limitations.
  const TokenMeasurement({
    required this.count,
    required this.precision,
    this.reason,
  });

  /// Decodes a measurement; missing counts always have unavailable precision.
  factory TokenMeasurement.fromMap(Map<Object?, Object?> map) {
    final int? count = map['count'] as int?;
    return TokenMeasurement(
      count: count,
      precision: count == null
          ? TokenPrecision.unavailable
          : TokenPrecision.values.firstWhere(
              (value) => value.name == map['precision'],
              orElse: () => TokenPrecision.unavailable,
            ),
      reason: map['reason'] as String?,
    );
  }

  /// Number of tokens for this component, or null when unknown.
  final int? count;
  /// Whether the supplied count is exact, estimated or unavailable.
  final TokenPrecision precision;
  /// Native explanation when counting is unsupported or otherwise limited.
  final String? reason;
}

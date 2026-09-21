enum TokenPrecision { exact, estimated, unavailable }

final class TokenMeasurement {
  const TokenMeasurement({
    required this.count,
    required this.precision,
    this.reason,
  });

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

  final int? count;
  final TokenPrecision precision;
  final String? reason;
}

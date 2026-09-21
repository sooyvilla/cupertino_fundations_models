import 'availability.dart';
import 'token_measurement.dart';

final class TokenBudget {
  TokenBudget({
    required this.mode,
    required Map<String, TokenMeasurement> components,
    this.maximumResponseTokens,
    this.modelIdentifier,
    this.contextWindowTokens,
  }) : components = Map<String, TokenMeasurement>.unmodifiable(components);

  factory TokenBudget.fromMap(Map<Object?, Object?> map) {
    final raw = map['components'] as Map<Object?, Object?>? ?? const {};
    return TokenBudget(
      mode: ModelMode.values.firstWhere(
        (value) => value.name == map['mode'],
        orElse: () => ModelMode.local,
      ),
      components: <String, TokenMeasurement>{
        for (final entry in raw.entries)
          entry.key as String: TokenMeasurement.fromMap(
            entry.value as Map<Object?, Object?>,
          ),
      },
      maximumResponseTokens: map['maximumResponseTokens'] as int?,
      modelIdentifier: map['modelIdentifier'] as String?,
      contextWindowTokens: map['contextWindowTokens'] as int?,
    );
  }

  final ModelMode mode;
  final String? modelIdentifier;
  final Map<String, TokenMeasurement> components;
  final int? maximumResponseTokens;
  final int? contextWindowTokens;
}

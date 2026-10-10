import 'availability.dart';
import 'token_measurement.dart';

/// Token measurements for the model and context owned by one session.
///
/// Component scopes can overlap, so their sum is not an exact request size.
/// Missing native measurements remain unavailable, including PCC counts.
final class TokenBudget {
  /// Creates a budget with an immutable copy of its component measurements.
  TokenBudget({
    required this.mode,
    required Map<String, TokenMeasurement> components,
    this.maximumResponseTokens,
    this.modelIdentifier,
    this.contextWindowTokens,
  }) : components = Map<String, TokenMeasurement>.unmodifiable(components);

  /// Decodes the native budget without inventing absent counts or window sizes.
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

  /// Session model route used for the measurement.
  final ModelMode mode;
  /// Native model identifier, when exposed by the runtime.
  final String? modelIdentifier;
  /// Measurements keyed by component, such as prompt, schema or transcript.
  final Map<String, TokenMeasurement> components;
  /// Requested response allowance; it is not an observed output count.
  final int? maximumResponseTokens;
  /// Native context window size, when available for this model.
  final int? contextWindowTokens;
}

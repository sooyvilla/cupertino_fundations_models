import 'generation.dart';

/// An app-decoded value paired with its complete original model response.
///
/// Read [value] for the domain type and [response] for text, native route,
/// metadata, nullable usage and termination. The response is retained by
/// identity rather than reconstructed. Decoding does not validate facts or
/// authorize application actions.
final class DecodedModelResponse<T> {
  /// Pairs a value with the response from which it was decoded.
  const DecodedModelResponse({required this.value, required this.response});

  /// Value returned by the caller's decoder, including null if T permits it.
  /// Explicit null input is distinguished from absence by response.hasStructuredValue.
  final T value;

  /// Original final response, with all native metadata and counters preserved.
  final ModelResponse response;
}

import 'generation.dart';

/// A caller-supplied decoder failed after structured generation completed.
///
/// This differs from native schema/JSON failures, which retain the package's
/// FoundationModelsException contract. [response] preserves the successful
/// native result; [cause] and [stackTrace] preserve the decoder failure.
/// Stringification omits the output and cause because they may contain data.
final class StructuredDecodingException implements Exception {
  /// Retains a decoder failure without retrying generation or changing its data.
  const StructuredDecodingException({
    required this.response,
    required this.cause,
    required this.stackTrace,
  });

  /// Original final model response that the decoder could not convert.
  final ModelResponse response;

  /// Original thrown object; inspecting or logging it is the app's decision.
  final Object cause;

  /// Stack captured at the original decoder failure.
  final StackTrace stackTrace;

  @override
  String toString() => 'StructuredDecodingException: the application decoder failed.';
}

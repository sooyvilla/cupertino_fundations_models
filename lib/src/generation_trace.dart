import 'availability.dart';
import 'errors.dart';
import 'generation.dart';
import 'generation_diagnostic_event.dart';
import 'generation_diagnostics.dart';
import 'generation_termination.dart';

/// Internal per-request timing and diagnostic dispatcher.
/// Metadata is frozen at construction and callback failures never stop generation.
final class GenerationTrace {
  /// Creates timing state for an admitted or subsequently subscribed request.
  GenerationTrace({
    required this.requestId,
    required this.sessionId,
    required this.mode,
    required this.configuration,
    required Map<String, Object?> runtimeMetadata,
  }) : runtimeMetadata = Map<String, Object?>.unmodifiable(runtimeMetadata);

  /// Dart correlation identifier for this request.
  final String requestId;
  /// Session that owns the request.
  final String sessionId;
  /// Selected native route.
  final ModelMode mode;
  /// Optional callback and output-capture policy.
  final GenerationDiagnostics? configuration;
  /// Immutable runtime metadata snapshot.
  final Map<String, Object?> runtimeMetadata;
  final Stopwatch _clock = Stopwatch();
  Duration? _firstResponseLatency;
  /// Native correlation identifier, assigned when the transport supplies one.
  String? nativeRequestId;

  /// Emits bounded metadata under the configured diagnostic policy.
  void emit(
    GenerationDiagnosticStage stage, {
    String? output,
    ModelUsage? usage,
    GenerationTermination? termination,
    FoundationModelsErrorCode? errorCode,
  }) {
    if (stage == GenerationDiagnosticStage.started) {
      _clock.start();
    }
    if (stage == GenerationDiagnosticStage.snapshot ||
        stage == GenerationDiagnosticStage.completed) {
      _firstResponseLatency ??= _clock.elapsed;
    }
    final configuration = this.configuration;
    if (configuration == null) {
      return;
    }
    final bool omitted = configuration.captureOutput &&
        output != null &&
        output.length > configuration.maximumOutputCharacters;
    try {
      configuration.onEvent(GenerationDiagnosticEvent(
        requestId: requestId,
        sessionId: sessionId,
        nativeRequestId: nativeRequestId,
        mode: mode,
        stage: stage,
        elapsed: _clock.elapsed,
        firstResponseLatency: _firstResponseLatency,
        runtimeMetadata: runtimeMetadata,
        usage: usage,
        termination: termination,
        errorCode: errorCode,
        output: configuration.captureOutput && !omitted ? output : null,
        outputOmitted: omitted,
      ));
    } on Object {
      return;
    }
  }
}

import 'availability.dart';
import 'generation.dart';
import 'errors.dart';
import 'generation_diagnostic_event.dart';
import 'generation_diagnostics.dart';
import 'generation_termination.dart';

final class GenerationTrace {
  GenerationTrace({
    required this.requestId,
    required this.sessionId,
    required this.mode,
    required this.configuration,
    required Map<String, Object?> runtimeMetadata,
  }) : runtimeMetadata = Map<String, Object?>.unmodifiable(runtimeMetadata);

  final String requestId;
  final String sessionId;
  final ModelMode mode;
  final GenerationDiagnostics? configuration;
  final Map<String, Object?> runtimeMetadata;
  final Stopwatch _clock = Stopwatch();
  Duration? _firstResponseLatency;
  String? nativeRequestId;

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

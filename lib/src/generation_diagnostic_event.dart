import 'availability.dart';
import 'generation.dart';
import 'errors.dart';
import 'generation_termination.dart';

enum GenerationDiagnosticStage { started, snapshot, completed, failed, cancelled }

final class GenerationDiagnosticEvent {
  const GenerationDiagnosticEvent({
    required this.requestId,
    required this.sessionId,
    required this.mode,
    required this.stage,
    required this.elapsed,
    required this.runtimeMetadata,
    this.nativeRequestId,
    this.firstResponseLatency,
    this.usage,
    this.termination,
    this.errorCode,
    this.output,
    this.outputOmitted = false,
  });

  final String requestId;
  final String sessionId;
  final ModelMode mode;
  final GenerationDiagnosticStage stage;
  final Duration elapsed;
  final Map<String, Object?> runtimeMetadata;
  final String? nativeRequestId;
  final Duration? firstResponseLatency;
  final ModelUsage? usage;
  final GenerationTermination? termination;
  final FoundationModelsErrorCode? errorCode;
  final String? output;
  final bool outputOmitted;
}

import 'availability.dart';
import 'errors.dart';
import 'generation.dart';
import 'generation_termination.dart';

/// The request lifecycle point represented by a diagnostic event.
enum GenerationDiagnosticStage {
  /// A request was admitted by its session.
  started,
  /// A cumulative text snapshot arrived.
  snapshot,
  /// A final response was received and cleanup completed.
  completed,
  /// A model, transport or deadline failure ended the request.
  failed,
  /// The request was cancelled.
  cancelled,
}

/// Metadata for one lifecycle point of a generation request.
///
/// Missing native usage or stop reasons remain unknown. [output] is populated
/// only when the app explicitly enables capture and the string fits its limit.
final class GenerationDiagnosticEvent {
  /// Creates an event without performing logging, persistence or network work.
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

  /// Dart request identifier scoped to the session.
  final String requestId;
  /// Session that owns this request.
  final String sessionId;
  /// Model route selected when the session was created.
  final ModelMode mode;
  /// Lifecycle stage being reported.
  final GenerationDiagnosticStage stage;
  /// Time elapsed since admission, excluding work before the request.
  final Duration elapsed;
  /// Runtime and package metadata available to the session.
  final Map<String, Object?> runtimeMetadata;
  /// Native transport identifier when an event supplies one.
  final String? nativeRequestId;
  /// Time to the first text snapshot or final response, when observed.
  final Duration? firstResponseLatency;
  /// Token counters supplied by the native model, if available.
  final ModelUsage? usage;
  /// Typed final outcome when this event represents termination.
  final GenerationTermination? termination;
  /// Native or lifecycle failure code, when applicable.
  final FoundationModelsErrorCode? errorCode;
  /// Exact captured output, or null when capture is disabled or omitted.
  final String? output;
  /// Whether enabled output capture was omitted because it exceeded its limit.
  final bool outputOmitted;
}

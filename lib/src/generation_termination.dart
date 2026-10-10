/// Whether a generation request completed, failed or was interrupted.
enum GenerationStatus {
  /// A final response was delivered.
  completed,
  /// A model, transport or decoding error ended the request.
  failed,
  /// The request was cancelled before successful completion.
  cancelled,
  /// A configured deadline ended the request.
  timedOut,
}

/// Why a request stopped, to the extent the package can establish it.
enum GenerationStopReason {
  /// Apple did not supply a stop reason; completion alone implies no cause.
  unknown,
  /// The request exceeded the selected model's context window.
  contextSizeExceeded,
  /// The model refused the task.
  refusal,
  /// Native content guardrails blocked the request or response.
  guardrailViolation,
  /// The final structured output was incomplete or could not be decoded.
  invalidStructure,
  /// Cancellation ended the request.
  cancelled,
  /// A deadline ended the request.
  timeout,
  /// Another error ended the request.
  error,
}

/// The stream deadline that expired.
enum GenerationTimeoutPhase {
  /// No text snapshot or final response arrived before the first deadline.
  firstResponse,
  /// Response activity stopped for longer than the configured idle interval.
  idle,
  /// The entire request exceeded its configured total duration.
  total,
}

/// A typed outcome without inferring truncation or correctness from token counts.
final class GenerationTermination {
  /// Creates an outcome with an unknown stop reason by default.
  const GenerationTermination({
    required this.status,
    this.reason = GenerationStopReason.unknown,
    this.structuredContentComplete,
    this.nativeReason,
    this.timeoutPhase,
  });

  /// Decodes the native outcome, preserving unknown reasons and absent fields.
  factory GenerationTermination.fromMap(Map<Object?, Object?> map) {
    return GenerationTermination(
      status: GenerationStatus.values.firstWhere(
        (value) => value.name == map['status'],
        orElse: () => GenerationStatus.completed,
      ),
      reason: GenerationStopReason.values.firstWhere(
        (value) => value.name == map['reason'],
        orElse: () => GenerationStopReason.unknown,
      ),
      structuredContentComplete: map['structuredContentComplete'] as bool?,
      nativeReason: map['nativeReason'] as String?,
      timeoutPhase: GenerationTimeoutPhase.values
          .where((value) => value.name == map['timeoutPhase'])
          .firstOrNull,
    );
  }

  /// Whether the request completed or was interrupted.
  final GenerationStatus status;
  /// Known cause, or [GenerationStopReason.unknown] when not supplied.
  final GenerationStopReason reason;
  /// Native structure-completeness flag; this does not validate business facts.
  final bool? structuredContentComplete;
  /// Original native stop description, when supplied.
  final String? nativeReason;
  /// Deadline phase associated with a timeout, when known.
  final GenerationTimeoutPhase? timeoutPhase;
}

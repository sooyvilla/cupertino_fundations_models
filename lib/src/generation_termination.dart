enum GenerationStatus { completed, failed, cancelled, timedOut }

enum GenerationStopReason {
  unknown,
  contextSizeExceeded,
  refusal,
  guardrailViolation,
  invalidStructure,
  cancelled,
  timeout,
  error,
}

enum GenerationTimeoutPhase { firstResponse, idle, total }

final class GenerationTermination {
  const GenerationTermination({
    required this.status,
    this.reason = GenerationStopReason.unknown,
    this.structuredContentComplete,
    this.nativeReason,
    this.timeoutPhase,
  });

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

  final GenerationStatus status;
  final GenerationStopReason reason;
  final bool? structuredContentComplete;
  final String? nativeReason;
  final GenerationTimeoutPhase? timeoutPhase;
}

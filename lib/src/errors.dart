import 'package:flutter/services.dart';

import 'generation_termination.dart';

/// Stable error codes returned by the package.
enum FoundationModelsErrorCode {
  /// The native Apple plugin is unavailable on this platform.
  unsupportedPlatform,
  /// The host OS is older than the requested feature.
  unsupportedOsVersion,
  /// Apple Intelligence is disabled.
  appleIntelligenceDisabled,
  /// Required model assets are not ready.
  assetsUnavailable,
  /// The selected native model cannot currently run.
  modelUnavailable,
  /// PCC is unavailable for this host or request.
  privateCloudUnavailable,
  /// PCC entitlement, signing or host opt-in requirements are missing.
  missingEntitlement,
  /// The selected cloud route exhausted its quota.
  quotaExceeded,
  /// A permitted network-backed feature cannot reach its service.
  networkUnavailable,
  /// The requested model language or locale is unsupported.
  unsupportedLanguage,
  /// Speech recognition permission was denied or restricted.
  speechRecognitionDenied,
  /// Speech recognition is unavailable for the requested mode or locale.
  speechRecognitionUnavailable,
  /// An audio-file transcription deadline expired.
  transcriptionTimeout,
  /// The native picker cannot select or access the requested file.
  fileSelectionUnavailable,
  /// Input, history and output exceed the native model's context window.
  contextSizeExceeded,
  /// The native runtime throttled the request.
  rateLimited,
  /// Native content guardrails blocked input or output.
  guardrailViolation,
  /// The native model refused the task.
  refusal,
  /// The selected model or SDK does not support a requested capability.
  unsupportedCapability,
  /// The transcript contains a native entry the bridge cannot represent.
  unsupportedTranscriptContent,
  /// The native model cannot apply a requested generation guide.
  unsupportedGenerationGuide,
  /// A language-generation deadline expired.
  generationTimeout,
  /// Another request or cleanup operation already owns this session.
  concurrentRequests,
  /// A transcript mutation was attempted while generation was active.
  transcriptMutationWhileResponding,
  /// Final structured output is incomplete or cannot be decoded.
  parsingFailure,
  /// Apple's PCC service is temporarily unavailable.
  privateCloudServiceUnavailable,
  /// Request arguments, schemas or session/response state are invalid.
  invalidRequest,
  /// A registered Dart tool failed, timed out or returned an invalid result.
  toolFailed,
  /// Cancellation ended the native request.
  cancelled,
  /// The bridge or native framework reported another execution failure.
  nativeFailure,
  /// An unrecognized native error code was received.
  unknown,
}

/// Typed schema-import, native and session-lifecycle failure from the package.
///
/// Use [code] for recovery decisions and [details] for contextual fields such
/// as a schema path or timeout phase. Invalid Dart option or constraint values
/// can instead throw [ArgumentError] before native request admission.
/// JSON Schema import failures use `invalidRequest`, `schemaSource: jsonSchema`
/// and an input JSON Pointer in `schemaPath` before invoking native services.
/// App decoder throws use the separate StructuredDecodingException contract;
/// missing or incomplete final data still uses this package's parsingFailure.
final class FoundationModelsException implements Exception {
  /// Creates a failure without executing a recovery action.
  const FoundationModelsException({
    required this.code,
    required this.message,
    this.recoverySuggestion,
    this.details = const <String, Object?>{},
  });

  /// Maps a platform failure and retains its string-keyed native details.
  factory FoundationModelsException.fromPlatformException(
    PlatformException exception,
  ) {
    return FoundationModelsException(
      code: _codeFromName(exception.code),
      message: exception.message ?? 'Foundation Models request failed.',
      recoverySuggestion:
          _detailsFromObject(exception.details)['recoverySuggestion']
              as String?,
      details: _detailsFromObject(exception.details),
    );
  }

  /// Stable code used to choose application recovery behavior.
  final FoundationModelsErrorCode code;
  /// Native or bridge description of the failure.
  final String message;
  /// Suggested recovery action, when available; it is not performed automatically.
  final String? recoverySuggestion;
  /// Context such as schemaPath, timeoutPhase or native termination information.
  final Map<String, Object?> details;

  /// Converts this failure into a typed terminal generation outcome.
  GenerationTermination get termination {
    final reason = switch (code) {
      FoundationModelsErrorCode.contextSizeExceeded => GenerationStopReason.contextSizeExceeded,
      FoundationModelsErrorCode.refusal => GenerationStopReason.refusal,
      FoundationModelsErrorCode.guardrailViolation => GenerationStopReason.guardrailViolation,
      FoundationModelsErrorCode.parsingFailure => GenerationStopReason.invalidStructure,
      FoundationModelsErrorCode.cancelled => GenerationStopReason.cancelled,
      FoundationModelsErrorCode.generationTimeout => GenerationStopReason.timeout,
      _ => GenerationStopReason.error,
    };
    return GenerationTermination(
      status: code == FoundationModelsErrorCode.cancelled
          ? GenerationStatus.cancelled
          : code == FoundationModelsErrorCode.generationTimeout
          ? GenerationStatus.timedOut
          : GenerationStatus.failed,
      reason: reason,
      nativeReason: details['nativeReason'] as String?,
      structuredContentComplete: details['structuredContentComplete'] as bool?,
      timeoutPhase: GenerationTimeoutPhase.values
          .where((value) => value.name == details['timeoutPhase'])
          .firstOrNull,
    );
  }

  @override
  String toString() => 'FoundationModelsException(${code.name}, $message)';
}

FoundationModelsErrorCode _codeFromName(String name) {
  for (final FoundationModelsErrorCode value
      in FoundationModelsErrorCode.values) {
    if (value.name == name) {
      return value;
    }
  }
  return FoundationModelsErrorCode.unknown;
}

Map<String, Object?> _detailsFromObject(Object? value) {
  if (value is Map<Object?, Object?>) {
    return value.cast<String, Object?>();
  }
  return <String, Object?>{};
}

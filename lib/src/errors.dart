import 'package:flutter/services.dart';

/// Stable error codes returned by the package.
enum FoundationModelsErrorCode {
  unsupportedPlatform,
  unsupportedOsVersion,
  appleIntelligenceDisabled,
  assetsUnavailable,
  modelUnavailable,
  privateCloudUnavailable,
  missingEntitlement,
  quotaExceeded,
  networkUnavailable,
  unsupportedLanguage,
  speechRecognitionDenied,
  speechRecognitionUnavailable,
  transcriptionTimeout,
  fileSelectionUnavailable,
  contextSizeExceeded,
  rateLimited,
  guardrailViolation,
  refusal,
  unsupportedCapability,
  unsupportedTranscriptContent,
  unsupportedGenerationGuide,
  generationTimeout,
  concurrentRequests,
  transcriptMutationWhileResponding,
  parsingFailure,
  privateCloudServiceUnavailable,
  invalidRequest,
  toolFailed,
  cancelled,
  nativeFailure,
  unknown,
}

/// Exception type used by every public API in this package.
final class FoundationModelsException implements Exception {
  const FoundationModelsException({
    required this.code,
    required this.message,
    this.recoverySuggestion,
    this.details = const <String, Object?>{},
  });

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

  final FoundationModelsErrorCode code;
  final String message;
  final String? recoverySuggestion;
  final Map<String, Object?> details;

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

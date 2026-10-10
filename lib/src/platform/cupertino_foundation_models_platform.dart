import '../availability.dart';
import '../file_selection.dart';
import '../generation.dart';
import '../schema.dart';
import '../session.dart';
import '../token_budget.dart';
import '../transcription.dart';

/// Internal platform contract used by the public facade.
abstract interface class CupertinoFoundationModelsPlatform {
  /// Queries native feature flags independently of model readiness.
  Future<FoundationModelsCapabilities> getCapabilities();

  /// Returns the native intersection of model and modern Speech locales.
  Future<List<FoundationModelsLanguage>> getSupportedLanguages();

  /// Queries runtime diagnostics for the optional requested locale.
  Future<FoundationModelsDiagnostics> getDiagnostics({
    required String? localeIdentifier,
  });

  /// Checks route readiness under the requested cloud policy and locale.
  Future<ModelAvailability> checkAvailability({
    required ModelMode mode,
    required CloudPolicy cloudPolicy,
    required String? localeIdentifier,
  });

  /// Registers a native session, its policy and Dart tool callbacks.
  Future<FoundationModelSession> createSession({
    required SessionOptions options,
  });

  /// Counts a local prompt when the native tokenizer is supported.
  Future<int> countTokens({required Prompt prompt});

  /// Counts the local transcript for the specified native session.
  Future<int> countSessionTokens({required String sessionId});

  /// Measures request components using the specified session's model.
  Future<TokenBudget> measureTokenBudget({
    required String sessionId,
    required Prompt prompt,
    required GenerationOptions options,
    StructuredSchema? schema,
  });

  /// Opens the native picker and returns a temporary copy or cancellation.
  Future<PickedFoundationModelsFile?> pickFile({
    required FoundationModelsFileKind kind,
  });

  /// Transcribes a file through the selected native Speech route.
  Future<AudioTranscriptionResult> transcribeAudio({
    required AudioTranscriptionRequest request,
  });

  /// Starts one native microphone subscription and cleans up on cancellation.
  Stream<LiveTranscriptionEvent> liveTranscription({
    required LiveTranscriptionRequest request,
  });

  /// Performs a text request on an existing native session.
  Future<ModelResponse> respond({
    required String sessionId,
    required Prompt prompt,
    required GenerationOptions options,
  });

  /// Routes cumulative events for the specified session and optional schema.
  Stream<SessionEvent> stream({
    required String sessionId,
    required Prompt prompt,
    required GenerationOptions options,
    StructuredSchema? schema,
  });

  /// Performs a native schema-guided request on an existing session.
  Future<ModelResponse> generateStructured({
    required String sessionId,
    required Prompt prompt,
    required StructuredSchema schema,
    required GenerationOptions options,
  });

  /// Prepares native resources using an optional prompt prefix.
  Future<void> prewarm({
    required String sessionId,
    required Prompt? promptPrefix,
  });

  /// Cancels the active request and waits for native acknowledgement.
  Future<void> cancelActiveRequest({required String sessionId});

  /// Releases the native session and its transport registrations.
  Future<void> disposeSession({required String sessionId});
}

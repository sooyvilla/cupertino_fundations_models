import '../availability.dart';
import '../file_selection.dart';
import '../generation.dart';
import '../schema.dart';
import '../session.dart';
import '../transcription.dart';

/// Internal platform contract used by the public facade.
abstract interface class CupertinoFoundationModelsPlatform {
  Future<FoundationModelsCapabilities> getCapabilities();

  Future<FoundationModelsDiagnostics> getDiagnostics({
    required String? localeIdentifier,
  });

  Future<ModelAvailability> checkAvailability({
    required ModelMode mode,
    required CloudPolicy cloudPolicy,
    required String? localeIdentifier,
  });

  Future<FoundationModelSession> createSession({
    required SessionOptions options,
  });

  Future<PickedFoundationModelsFile?> pickFile({
    required FoundationModelsFileKind kind,
  });

  Future<AudioTranscriptionResult> transcribeAudio({
    required AudioTranscriptionRequest request,
  });

  Future<ModelResponse> respond({
    required String sessionId,
    required Prompt prompt,
    required GenerationOptions options,
  });

  Stream<SessionEvent> stream({
    required String sessionId,
    required Prompt prompt,
    required GenerationOptions options,
  });

  Future<ModelResponse> generateStructured({
    required String sessionId,
    required Prompt prompt,
    required StructuredSchema schema,
    required GenerationOptions options,
  });

  Future<void> prewarm({
    required String sessionId,
    required Prompt? promptPrefix,
  });

  Future<void> cancelActiveRequest({required String sessionId});

  Future<void> disposeSession({required String sessionId});
}

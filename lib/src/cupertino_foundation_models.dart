import 'availability.dart';
import 'file_selection.dart';
import 'generation.dart';
import 'platform/cupertino_foundation_models_platform.dart';
import 'platform/method_channel_cupertino_foundation_models.dart';
import 'schema.dart';
import 'session.dart';
import 'transcription.dart';

/// Main entry point for Apple Foundation Models from Flutter.
final class CupertinoFoundationModels {
  CupertinoFoundationModels({CupertinoFoundationModelsPlatform? platform})
    : _platform = platform ?? MethodChannelCupertinoFoundationModels();

  final CupertinoFoundationModelsPlatform _platform;

  Future<FoundationModelsCapabilities> getCapabilities() {
    return _platform.getCapabilities();
  }

  Future<FoundationModelsDiagnostics> getDiagnostics({
    String? localeIdentifier,
  }) {
    return _platform.getDiagnostics(localeIdentifier: localeIdentifier);
  }

  Future<ModelAvailability> checkAvailability({
    ModelMode mode = ModelMode.automatic,
    CloudPolicy cloudPolicy = CloudPolicy.never,
    String? localeIdentifier,
  }) {
    return _platform.checkAvailability(
      mode: mode,
      cloudPolicy: cloudPolicy,
      localeIdentifier: localeIdentifier,
    );
  }

  Future<bool> supportsFullPower({
    CloudPolicy cloudPolicy = CloudPolicy.whenExplicit,
  }) async {
    final FoundationModelsCapabilities capabilities = await _platform
        .getCapabilities();
    if (!capabilities.supportsFullPower) {
      return false;
    }
    if (cloudPolicy == CloudPolicy.never) {
      return capabilities.supports(ModelCapability.fullPower) &&
          capabilities.preferredMode == ModelMode.local;
    }
    return capabilities.supports(ModelCapability.fullPower);
  }

  Future<FoundationModelSession> createSession({
    SessionOptions options = const SessionOptions(),
  }) async {
    return _platform.createSession(options: options);
  }

  Future<PickedFoundationModelsFile?> pickFile({
    FoundationModelsFileKind kind = FoundationModelsFileKind.any,
  }) {
    return _platform.pickFile(kind: kind);
  }

  Future<AudioTranscriptionResult> transcribeAudio(
    AudioTranscriptionRequest request,
  ) {
    return _platform.transcribeAudio(request: request);
  }

  Future<ModelResponse> respond(
    Prompt prompt, {
    ModelMode mode = ModelMode.automatic,
    CloudPolicy cloudPolicy = CloudPolicy.never,
    String? instructions,
    GenerationOptions options = const GenerationOptions(),
  }) async {
    final FoundationModelSession session = await createSession(
      options: SessionOptions(
        mode: mode,
        cloudPolicy: cloudPolicy,
        instructions: instructions,
      ),
    );
    try {
      return await session.respond(prompt, options: options);
    } finally {
      await session.dispose();
    }
  }

  Future<ModelResponse> generateStructured({
    required Prompt prompt,
    required StructuredSchema schema,
    ModelMode mode = ModelMode.automatic,
    CloudPolicy cloudPolicy = CloudPolicy.never,
    String? instructions,
    GenerationOptions options = const GenerationOptions(),
  }) async {
    final FoundationModelSession session = await createSession(
      options: SessionOptions(
        mode: mode,
        cloudPolicy: cloudPolicy,
        instructions: instructions,
      ),
    );
    try {
      return await session.generateStructured(
        prompt: prompt,
        schema: schema,
        options: options,
      );
    } finally {
      await session.dispose();
    }
  }
}

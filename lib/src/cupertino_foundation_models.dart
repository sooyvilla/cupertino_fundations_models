import 'availability.dart';
import 'availability_watch.dart';
import 'decoded_model_response.dart';
import 'errors.dart';
import 'file_selection.dart';
import 'generation.dart';
import 'platform/cupertino_foundation_models_platform.dart';
import 'platform/foundation_models_availability_platform.dart';
import 'platform/foundation_models_history_platform.dart';
import 'platform/method_channel_cupertino_foundation_models.dart';
import 'schema.dart';
import 'session.dart';
import 'session_history.dart';
import 'text_model_language.dart';
import 'tools.dart';
import 'transcription.dart';

/// Main entry point for Apple Foundation Models from Flutter.
///
/// Check native availability before offering generation. One-shot methods own
/// their temporary sessions; use [createSession] when prior turns or tools are
/// needed. The default cloud policy keeps requests local.
final class CupertinoFoundationModels {
  /// Creates a facade over the shared native transport.
  /// A custom internal platform is primarily useful for application tests.
  CupertinoFoundationModels({CupertinoFoundationModelsPlatform? platform})
    : _platform = platform ?? _defaultPlatform;

  static final CupertinoFoundationModelsPlatform _defaultPlatform =
      MethodChannelCupertinoFoundationModels();

  final CupertinoFoundationModelsPlatform _platform;

  /// Returns native feature flags and caveats, separately from current readiness.
  Future<FoundationModelsCapabilities> getCapabilities() {
    return _platform.getCapabilities();
  }

  /// Returns locales supported by both the on-device model and live speech.
  Future<List<FoundationModelsLanguage>> getSupportedLanguages() {
    return _platform.getSupportedLanguages();
  }

  /// Returns advertised languages of a local text variant, independently of Speech.
  /// This list is not a readiness check or the set of every accepted regional locale.
  Future<List<TextModelLanguage>> getTextModelLanguages({
    FoundationModelsUseCase useCase = FoundationModelsUseCase.general,
  }) {
    final platform = _platform;
    if (platform is! FoundationModelsAvailabilityPlatform) {
      throw const FoundationModelsException(code: FoundationModelsErrorCode.unsupportedCapability,
        message: 'This platform does not expose text-model languages.');
    }
    return (platform as FoundationModelsAvailabilityPlatform).getTextModelLanguages(useCase: useCase);
  }

  /// Observes initial and changed local readiness without inference or downloads.
  /// Observation is the default; [pollingInterval] explicitly selects polling
  /// between one second and five minutes. It does not query or select PCC.
  /// The cold single-subscription stream stops work on subscription pause and,
  /// by default, outside foreground. Resume rechecks readiness. Await cancellation.
  /// Background handling requires an initialized Flutter WidgetsBinding.
  Stream<ModelAvailability> watchAvailability({
    FoundationModelsUseCase useCase = FoundationModelsUseCase.general,
    String? localeIdentifier,
    Duration? pollingInterval,
    bool pauseWhenBackgrounded = true,
  }) {
    if (pollingInterval != null && (pollingInterval < const Duration(seconds: 1) ||
        pollingInterval > const Duration(minutes: 5))) {
      throw ArgumentError.value(pollingInterval, 'pollingInterval', 'Use one second through five minutes.');
    }
    final platform = _platform;
    if (platform is! FoundationModelsAvailabilityPlatform) {
      return Stream<ModelAvailability>.error(const FoundationModelsException(
        code: FoundationModelsErrorCode.unsupportedCapability,
        message: 'This platform does not expose local availability monitoring.'));
    }
    return AvailabilityWatch(source: () => (platform as FoundationModelsAvailabilityPlatform).watchAvailability(
      useCase: useCase, localeIdentifier: localeIdentifier, pollingInterval: pollingInterval),
      pauseWhenBackgrounded: pauseWhenBackgrounded).stream;
  }

  /// Explains readiness and language support for a requested or system locale.
  Future<FoundationModelsDiagnostics> getDiagnostics({
    String? localeIdentifier,
  }) {
    return _platform.getDiagnostics(localeIdentifier: localeIdentifier);
  }

  /// Checks the selected Apple route, privacy policy and optional locale.
  /// Availability can change before generation. Unregistered backends and other
  /// bridge failures can throw a typed native exception.
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

  /// Compatibility query for the package's PCC capability flag.
  /// This does not prove signing approval, current readiness or model quality.
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

  /// Creates a session with native history and tools owned by the caller.
  /// Always await disposal when the feature finishes. Each session is single-flight;
  /// different sessions can operate concurrently.
  Future<FoundationModelSession> createSession({
    SessionOptions options = const SessionOptions(),
  }) async {
    if (options.history != null) {
      options.toMap();
      if (_platform is! FoundationModelsHistoryPlatform) {
        throw const FoundationModelsException(code: FoundationModelsErrorCode.unsupportedCapability,
          message: 'This platform does not expose session history restoration.');
      }
    }
    return _platform.createSession(options: options);
  }

  /// Creates a new session from a compatible history without executing past tools.
  /// Pass matching tool implementations for future calls. PCC still needs explicit
  /// policy/host authorization; local remains the default privacy policy.
  Future<FoundationModelSession> restoreSession({
    required SessionHistory history,
    List<ModelTool> tools = const <ModelTool>[],
    CloudPolicy cloudPolicy = CloudPolicy.never,
    TranscriptErrorHandlingPolicy transcriptErrorHandlingPolicy = TranscriptErrorHandlingPolicy.systemDefault,
    Map<String, Object?> metadata = const <String, Object?>{},
  }) {
    return createSession(options: SessionOptions(mode: history.mode, useCase: history.useCase,
      localeIdentifier: history.localeIdentifier, tools: tools, cloudPolicy: cloudPolicy,
      transcriptErrorHandlingPolicy: transcriptErrorHandlingPolicy, metadata: metadata, history: history));
  }

  /// Counts a prompt with the on-device Foundation Models tokenizer.
  Future<int> countTokens(Prompt prompt) {
    return _platform.countTokens(prompt: prompt);
  }

  /// Opens the native picker and returns an app-local copy, or null on cancel.
  /// The application decides when to remove the temporary file.
  Future<PickedFoundationModelsFile?> pickFile({
    FoundationModelsFileKind kind = FoundationModelsFileKind.any,
  }) {
    return _platform.pickFile(kind: kind);
  }

  /// Transcribes an audio file under the request's separate Speech privacy mode.
  /// Required host usage descriptions and system permissions remain app-owned.
  Future<AudioTranscriptionResult> transcribeAudio(
    AudioTranscriptionRequest request,
  ) {
    return _platform.transcribeAudio(request: request);
  }

  /// Starts live microphone transcription through Apple's Speech framework.
  ///
  /// Events carry the best transcription snapshot recognized so far. The
  /// stream closes after the first event marked `isFinal`, and cancelling the
  /// subscription stops the microphone capture and finalizes recognition.
  Stream<LiveTranscriptionEvent> liveTranscription({
    LiveTranscriptionRequest request = const LiveTranscriptionRequest(),
  }) {
    return _platform.liveTranscription(request: request);
  }

  /// Generates text for an independent task and disposes its temporary session.
  /// Catch native failures and preserve user input. Tools and prior turns require
  /// an explicitly owned session instead.
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

  /// Generates guided output for a supported root and disposes its temporary session.
  /// Constraints are applied natively. Invalid Dart bounds throw an argument
  /// error; invalid native schemas or Swift regexes report a schema path.
  /// The application validates final data before using business facts.
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

  /// Generates final guided data and converts it to T without losing metadata.
  ///
  /// Uses [generateStructured] with the same model, privacy policy, constraints
  /// and options. Its temporary session is disposed before the synchronous
  /// decoder runs. Native failures pass through; decoder failures retain the
  /// original response in StructuredDecodingException. Decoding is app-owned
  /// conversion and does not authorize writes, tools or automatic retries.
  Future<DecodedModelResponse<T>> generateStructuredDecoded<T>({
    required Prompt prompt,
    required StructuredSchema schema,
    required T Function(Object? value) decoder,
    ModelMode mode = ModelMode.automatic,
    CloudPolicy cloudPolicy = CloudPolicy.never,
    String? instructions,
    GenerationOptions options = const GenerationOptions(),
  }) async {
    final response = await generateStructured(
      prompt: prompt,
      schema: schema,
      mode: mode,
      cloudPolicy: cloudPolicy,
      instructions: instructions,
      options: options,
    );
    return response.decodeStructured<T>(decoder: decoder);
  }
}

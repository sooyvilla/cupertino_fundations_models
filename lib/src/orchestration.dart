import 'dart:async';

import 'availability.dart';
import 'cupertino_foundation_models.dart';
import 'errors.dart';
import 'generation.dart';
import 'schema.dart';
import 'session.dart';
import 'tools.dart';
import 'transcription.dart';

/// Work category used by the high-level router.
enum FoundationModelsTask {
  general,
  rewrite,
  summarize,
  classify,
  extractText,
  analyzeImage,
  transcribeAudio,
  toolRouting,
  complexReasoning,
  custom,
}

/// Backend selected by the high-level router.
enum FoundationModelsRouteBackend {
  appleLocal,
  applePrivateCloud,
  appleAutomatic,
  external,
}

/// Provider family that produced an orchestrated response.
enum FoundationModelsProviderKind { apple, external }

/// One route that can be attempted by `FoundationModelsOrchestrator`.
final class FoundationModelsRoute {
  const FoundationModelsRoute.appleLocal()
    : backend = FoundationModelsRouteBackend.appleLocal,
      mode = ModelMode.local,
      cloudPolicy = CloudPolicy.never,
      providerName = null;

  const FoundationModelsRoute.applePrivateCloud()
    : backend = FoundationModelsRouteBackend.applePrivateCloud,
      mode = ModelMode.privateCloudCompute,
      cloudPolicy = CloudPolicy.whenExplicit,
      providerName = null;

  const FoundationModelsRoute.appleAutomatic({
    this.cloudPolicy = CloudPolicy.never,
  }) : backend = FoundationModelsRouteBackend.appleAutomatic,
       mode = ModelMode.automatic,
       providerName = null;

  const FoundationModelsRoute.external({this.providerName})
    : backend = FoundationModelsRouteBackend.external,
      mode = null,
      cloudPolicy = null;

  final FoundationModelsRouteBackend backend;
  final ModelMode? mode;
  final CloudPolicy? cloudPolicy;
  final String? providerName;

  bool get isApple => backend != FoundationModelsRouteBackend.external;

  String get label {
    return switch (backend) {
      FoundationModelsRouteBackend.appleLocal => 'appleLocal',
      FoundationModelsRouteBackend.applePrivateCloud => 'applePrivateCloud',
      FoundationModelsRouteBackend.appleAutomatic => 'appleAutomatic',
      FoundationModelsRouteBackend.external =>
        providerName == null ? 'external' : 'external:$providerName',
    };
  }
}

/// Default values applied to every orchestrated request unless overridden.
final class FoundationModelsDefaults {
  const FoundationModelsDefaults({
    this.localeIdentifier,
    this.instructions,
    this.options = const GenerationOptions(),
    this.tools = const <ModelTool>[],
    this.metadata = const <String, Object?>{},
    this.audioTranscriptionMode = AudioTranscriptionMode.onDevice,
  });

  final String? localeIdentifier;
  final String? instructions;
  final GenerationOptions options;
  final List<ModelTool> tools;
  final Map<String, Object?> metadata;
  final AudioTranscriptionMode audioTranscriptionMode;
}

/// Author of one chat turn shared across Apple and external routes.
enum FoundationModelsChatRole { system, user, assistant }

/// One turn of a hybrid conversation.
final class FoundationModelsChatMessage {
  /// Creates a chat message.
  const FoundationModelsChatMessage({
    required this.role,
    required this.text,
    this.providerName,
  });

  /// Author of this turn.
  final FoundationModelsChatRole role;

  /// Text content of this turn.
  final String text;

  /// Provider that produced this turn, for assistant messages.
  final String? providerName;

  /// Converts this message into a JSON-like payload for external providers.
  Map<String, Object?> toMap() {
    return <String, Object?>{
      'role': role.name,
      'text': text,
      'providerName': providerName,
    };
  }
}

/// Request shape passed to Apple and external providers.
final class FoundationModelsRequest {
  const FoundationModelsRequest({
    required this.prompt,
    this.task = FoundationModelsTask.general,
    this.instructions,
    this.options = const GenerationOptions(),
    this.tools = const <ModelTool>[],
    this.metadata = const <String, Object?>{},
    this.schema,
    this.localeIdentifier,
    this.history = const <FoundationModelsChatMessage>[],
  });

  final Prompt prompt;
  final FoundationModelsTask task;
  final String? instructions;
  final GenerationOptions options;
  final List<ModelTool> tools;
  final Map<String, Object?> metadata;
  final StructuredSchema? schema;
  final String? localeIdentifier;

  /// Previous conversation turns, oldest first.
  ///
  /// Apple routes keep this history inside the native session transcript.
  /// External providers receive it here so a stateless HTTP provider such as
  /// Gemini or an OpenAI-style API can rebuild the same conversation.
  final List<FoundationModelsChatMessage> history;
}

/// Minimal adapter contract for Gemini, OpenAI, a server model, or any app AI.
abstract class FoundationModelsExternalProvider {
  const FoundationModelsExternalProvider();

  String get name;

  FutureOr<bool> isAvailable() => true;

  bool supports(FoundationModelsRequest request) => true;

  Future<FoundationModelsProviderResponse> respond(
    FoundationModelsRequest request,
  );

  /// Streams the response as cumulative text snapshots.
  ///
  /// Each emitted string replaces the previous one, matching the semantics of
  /// Apple `TextDeltaEvent`. Override this when the provider supports server
  /// streaming; the default emits a single snapshot from [respond].
  Stream<String> respondStream(FoundationModelsRequest request) async* {
    final FoundationModelsProviderResponse response = await respond(request);
    yield response.text;
  }
}

/// Optional adapter contract for external speech-to-text providers.
abstract class FoundationModelsExternalTranscriptionProvider {
  const FoundationModelsExternalTranscriptionProvider();

  String get name;

  FutureOr<bool> isAvailable() => true;

  Future<FoundationModelsExternalTranscriptionResult> transcribeAudio(
    AudioTranscriptionRequest request,
  );
}

/// Response returned by an external text provider adapter.
final class FoundationModelsProviderResponse {
  const FoundationModelsProviderResponse({
    required this.text,
    this.structuredValue,
    this.metadata = const <String, Object?>{},
  });

  final String text;
  final Map<String, Object?>? structuredValue;
  final Map<String, Object?> metadata;
}

/// Response returned by an external transcription provider adapter.
final class FoundationModelsExternalTranscriptionResult {
  const FoundationModelsExternalTranscriptionResult({
    required this.text,
    this.isFinal = true,
    this.segments = const <AudioTranscriptionSegment>[],
    this.metadata = const <String, Object?>{},
  });

  final String text;
  final bool isFinal;
  final List<AudioTranscriptionSegment> segments;
  final Map<String, Object?> metadata;
}

/// Runtime snapshot that can also be injected into a bigger model prompt.
final class FoundationModelsRuntimeContext {
  const FoundationModelsRuntimeContext({
    required this.localeIdentifier,
    this.capabilities,
    this.diagnostics,
    this.localAvailability,
    this.privateCloudAvailability,
    this.externalProviderName,
    this.externalAvailable = false,
  });

  final String? localeIdentifier;
  final FoundationModelsCapabilities? capabilities;
  final FoundationModelsDiagnostics? diagnostics;
  final ModelAvailability? localAvailability;
  final ModelAvailability? privateCloudAvailability;
  final String? externalProviderName;
  final bool externalAvailable;

  bool get canUseAppleLocal => localAvailability?.isAvailable ?? false;

  bool get canUseApplePrivateCloud =>
      privateCloudAvailability?.isAvailable ?? false;

  bool get canUseExternal => externalAvailable && externalProviderName != null;

  String toPromptContext() {
    final StringBuffer buffer = StringBuffer()
      ..writeln('Available AI routes for this app:');

    if (canUseAppleLocal) {
      buffer.writeln(
        '- appleLocal: Apple Foundation Models on device. Prefer it for '
        'short private tasks, rewriting, summaries, extraction, simple '
        'classification, and image analysis when supported.',
      );
    } else {
      buffer.writeln(
        '- appleLocal: unavailable (${localAvailability?.status.name ?? 'unknown'}).',
      );
    }

    if (canUseApplePrivateCloud) {
      buffer.writeln(
        '- applePrivateCloud: Apple Private Cloud Compute is available when '
        'the app explicitly allows cloud use.',
      );
    } else if (privateCloudAvailability != null) {
      buffer.writeln(
        '- applePrivateCloud: unavailable '
        '(${privateCloudAvailability?.status.name ?? 'unknown'}).',
      );
    }

    if (canUseExternal) {
      buffer.writeln(
        '- external:$externalProviderName: app-provided model provider. '
        'Use it for tasks that need larger context, stronger reasoning, '
        'or provider-specific tools.',
      );
    }

    return buffer.toString().trimRight();
  }
}

/// Result of one attempted route.
final class FoundationModelsRouteAttempt {
  const FoundationModelsRouteAttempt({
    required this.route,
    required this.succeeded,
    this.wasAvailable,
    this.message,
    this.errorCode,
  });

  final FoundationModelsRoute route;
  final bool succeeded;
  final bool? wasAvailable;
  final String? message;
  final FoundationModelsErrorCode? errorCode;

  Map<String, Object?> toMap() {
    return <String, Object?>{
      'route': route.label,
      'succeeded': succeeded,
      'wasAvailable': wasAvailable,
      'message': message,
      'errorCode': errorCode?.name,
    };
  }
}

/// Response returned by `FoundationModelsOrchestrator`.
final class OrchestratedModelResponse {
  const OrchestratedModelResponse({
    required this.text,
    required this.provider,
    required this.providerName,
    required this.route,
    required this.attempts,
    this.usedMode,
    this.structuredValue,
    this.metadata = const <String, Object?>{},
  });

  final String text;
  final FoundationModelsProviderKind provider;
  final String providerName;
  final FoundationModelsRoute route;
  final ModelMode? usedMode;
  final Map<String, Object?>? structuredValue;
  final Map<String, Object?> metadata;
  final List<FoundationModelsRouteAttempt> attempts;
}

/// Transcription result returned by `FoundationModelsOrchestrator`.
final class OrchestratedTranscriptionResult {
  const OrchestratedTranscriptionResult({
    required this.text,
    required this.isFinal,
    required this.provider,
    required this.providerName,
    required this.segments,
    this.usedAudioMode,
    this.metadata = const <String, Object?>{},
  });

  final String text;
  final bool isFinal;
  final FoundationModelsProviderKind provider;
  final String providerName;
  final AudioTranscriptionMode? usedAudioMode;
  final List<AudioTranscriptionSegment> segments;
  final Map<String, Object?> metadata;
}

/// Streamed event emitted by [FoundationModelsChatSession.sendStream].
sealed class OrchestratedChatEvent {
  const OrchestratedChatEvent();
}

/// Cumulative text snapshot emitted while a chat response streams.
final class OrchestratedChatTextEvent extends OrchestratedChatEvent {
  /// Creates a streamed chat text snapshot.
  const OrchestratedChatTextEvent({required this.text, required this.route});

  /// Latest full text snapshot; it replaces the previous snapshot.
  final String text;

  /// Route currently producing the response.
  final FoundationModelsRoute route;
}

/// Final event emitted when a streamed chat turn completes.
final class OrchestratedChatCompletionEvent extends OrchestratedChatEvent {
  /// Creates a chat completion event.
  const OrchestratedChatCompletionEvent({required this.response});

  /// Final orchestrated response for the turn.
  final OrchestratedModelResponse response;
}

/// Resolves the ordered routes for one request.
abstract class FoundationModelsRouter {
  const FoundationModelsRouter();

  FutureOr<List<FoundationModelsRoute>> resolve(
    FoundationModelsRequest request,
    FoundationModelsRuntimeContext context,
  );

  bool get fallbackOnError => true;
}

/// Built-in router for local-only, Apple-first, external-first, and hybrid apps.
final class FoundationModelsRoutingPolicy extends FoundationModelsRouter {
  const FoundationModelsRoutingPolicy({
    required this.routes,
    this.complexTaskRoutes,
    this.complexTasks = const <FoundationModelsTask>{
      FoundationModelsTask.toolRouting,
      FoundationModelsTask.complexReasoning,
    },
    this.fallbackOnError = true,
  });

  factory FoundationModelsRoutingPolicy.localOnly() {
    return const FoundationModelsRoutingPolicy(
      routes: <FoundationModelsRoute>[FoundationModelsRoute.appleLocal()],
    );
  }

  factory FoundationModelsRoutingPolicy.appleFirst({
    bool allowPrivateCloud = false,
    bool allowExternalFallback = true,
  }) {
    return FoundationModelsRoutingPolicy(
      routes: <FoundationModelsRoute>[
        const FoundationModelsRoute.appleLocal(),
        if (allowPrivateCloud) const FoundationModelsRoute.applePrivateCloud(),
        if (allowExternalFallback) const FoundationModelsRoute.external(),
      ],
    );
  }

  /// Prefers Apple Private Cloud Compute and falls back to the local model.
  ///
  /// Requires iOS 27 or later at runtime; on older systems the private cloud
  /// route reports unavailable and the fallbacks (if any) are attempted.
  factory FoundationModelsRoutingPolicy.privateCloudFirst({
    bool allowLocalFallback = true,
    bool allowExternalFallback = false,
  }) {
    return FoundationModelsRoutingPolicy(
      routes: <FoundationModelsRoute>[
        const FoundationModelsRoute.applePrivateCloud(),
        if (allowLocalFallback) const FoundationModelsRoute.appleLocal(),
        if (allowExternalFallback) const FoundationModelsRoute.external(),
      ],
    );
  }

  factory FoundationModelsRoutingPolicy.externalFirst({
    bool allowAppleFallback = true,
    bool allowPrivateCloudFallback = false,
  }) {
    return FoundationModelsRoutingPolicy(
      routes: <FoundationModelsRoute>[
        const FoundationModelsRoute.external(),
        if (allowAppleFallback) const FoundationModelsRoute.appleLocal(),
        if (allowPrivateCloudFallback)
          const FoundationModelsRoute.applePrivateCloud(),
      ],
    );
  }

  factory FoundationModelsRoutingPolicy.hybrid({
    bool allowPrivateCloud = false,
    bool allowExternalFallback = true,
  }) {
    return FoundationModelsRoutingPolicy(
      routes: <FoundationModelsRoute>[
        const FoundationModelsRoute.appleLocal(),
        if (allowPrivateCloud) const FoundationModelsRoute.applePrivateCloud(),
        if (allowExternalFallback) const FoundationModelsRoute.external(),
      ],
      complexTaskRoutes: <FoundationModelsRoute>[
        if (allowExternalFallback) const FoundationModelsRoute.external(),
        const FoundationModelsRoute.appleLocal(),
        if (allowPrivateCloud) const FoundationModelsRoute.applePrivateCloud(),
      ],
    );
  }

  final List<FoundationModelsRoute> routes;
  final List<FoundationModelsRoute>? complexTaskRoutes;
  final Set<FoundationModelsTask> complexTasks;

  @override
  final bool fallbackOnError;

  @override
  List<FoundationModelsRoute> resolve(
    FoundationModelsRequest request,
    FoundationModelsRuntimeContext context,
  ) {
    if (complexTasks.contains(request.task) && complexTaskRoutes != null) {
      return complexTaskRoutes!;
    }
    return routes;
  }
}

/// High-level facade for apps that combine Apple models with another provider.
final class FoundationModelsOrchestrator {
  FoundationModelsOrchestrator({
    CupertinoFoundationModels? apple,
    FoundationModelsExternalProvider? externalProvider,
    FoundationModelsExternalTranscriptionProvider?
    externalTranscriptionProvider,
    FoundationModelsRouter? router,
    FoundationModelsDefaults defaults = const FoundationModelsDefaults(),
  }) : _apple = apple ?? CupertinoFoundationModels(),
       _externalProvider = externalProvider,
       _externalTranscriptionProvider = externalTranscriptionProvider,
       _router = router ?? FoundationModelsRoutingPolicy.hybrid(),
       _defaults = defaults;

  final CupertinoFoundationModels _apple;
  final FoundationModelsExternalProvider? _externalProvider;
  final FoundationModelsExternalTranscriptionProvider?
  _externalTranscriptionProvider;
  final FoundationModelsRouter _router;
  final FoundationModelsDefaults _defaults;
  FoundationModelsRuntimeContext? _cachedContext;

  Future<FoundationModelsRuntimeContext> getRuntimeContext({
    String? localeIdentifier,
    bool refresh = false,
  }) async {
    final String? effectiveLocale =
        localeIdentifier ?? _defaults.localeIdentifier;
    final FoundationModelsRuntimeContext? cached = _cachedContext;
    if (!refresh &&
        cached != null &&
        cached.localeIdentifier == effectiveLocale) {
      return cached;
    }

    FoundationModelsCapabilities? capabilities;
    FoundationModelsDiagnostics? diagnostics;
    ModelAvailability? localAvailability;
    ModelAvailability? privateCloudAvailability;
    bool externalAvailable = false;

    try {
      capabilities = await _apple.getCapabilities();
    } on Object {
      capabilities = null;
    }

    try {
      diagnostics = await _apple.getDiagnostics(
        localeIdentifier: effectiveLocale,
      );
    } on Object {
      diagnostics = null;
    }

    try {
      localAvailability = await _apple.checkAvailability(
        mode: ModelMode.local,
        localeIdentifier: effectiveLocale,
      );
    } on Object {
      localAvailability = diagnostics?.localAvailability;
    }

    try {
      privateCloudAvailability = await _apple.checkAvailability(
        mode: ModelMode.privateCloudCompute,
        cloudPolicy: CloudPolicy.whenExplicit,
        localeIdentifier: effectiveLocale,
      );
    } on Object {
      privateCloudAvailability = diagnostics?.privateCloudAvailability;
    }

    final FoundationModelsExternalProvider? externalProvider =
        _externalProvider;
    if (externalProvider != null) {
      try {
        externalAvailable = await Future<bool>.value(
          externalProvider.isAvailable(),
        );
      } on Object {
        externalAvailable = false;
      }
    }

    final FoundationModelsRuntimeContext context =
        FoundationModelsRuntimeContext(
          localeIdentifier: effectiveLocale,
          capabilities: capabilities,
          diagnostics: diagnostics,
          localAvailability: localAvailability,
          privateCloudAvailability: privateCloudAvailability,
          externalProviderName: externalProvider?.name,
          externalAvailable: externalAvailable,
        );
    _cachedContext = context;
    return context;
  }

  Future<String> buildRuntimePromptContext({
    String? localeIdentifier,
    bool refresh = false,
  }) async {
    final FoundationModelsRuntimeContext context = await getRuntimeContext(
      localeIdentifier: localeIdentifier,
      refresh: refresh,
    );
    return context.toPromptContext();
  }

  Future<OrchestratedModelResponse> respondText(
    String text, {
    FoundationModelsTask task = FoundationModelsTask.general,
    String? instructions,
    GenerationOptions? options,
    List<ModelTool>? tools,
    Map<String, Object?> metadata = const <String, Object?>{},
    String? localeIdentifier,
  }) {
    return respond(
      Prompt.text(text),
      task: task,
      instructions: instructions,
      options: options,
      tools: tools,
      metadata: metadata,
      localeIdentifier: localeIdentifier,
    );
  }

  Future<OrchestratedModelResponse> respond(
    Prompt prompt, {
    FoundationModelsTask task = FoundationModelsTask.general,
    String? instructions,
    GenerationOptions? options,
    List<ModelTool>? tools,
    Map<String, Object?> metadata = const <String, Object?>{},
    String? localeIdentifier,
  }) {
    final FoundationModelsRequest request = _request(
      prompt: prompt,
      task: task,
      instructions: instructions,
      options: options,
      tools: tools,
      metadata: metadata,
      localeIdentifier: localeIdentifier,
    );
    return _run(request);
  }

  Future<OrchestratedModelResponse> generateStructured({
    required Prompt prompt,
    required StructuredSchema schema,
    FoundationModelsTask task = FoundationModelsTask.extractText,
    String? instructions,
    GenerationOptions? options,
    List<ModelTool>? tools,
    Map<String, Object?> metadata = const <String, Object?>{},
    String? localeIdentifier,
  }) {
    final FoundationModelsRequest request = _request(
      prompt: prompt,
      task: task,
      instructions: instructions,
      options: options,
      tools: tools,
      metadata: metadata,
      schema: schema,
      localeIdentifier: localeIdentifier,
    );
    return _run(request);
  }

  Future<OrchestratedTranscriptionResult> transcribeAudio(
    AudioTranscriptionRequest request, {
    bool allowExternalFallback = true,
  }) async {
    try {
      final AudioTranscriptionRequest appleRequest = _audioRequest(request);
      final AudioTranscriptionResult result = await _apple.transcribeAudio(
        appleRequest,
      );
      return OrchestratedTranscriptionResult(
        text: result.text,
        isFinal: result.isFinal,
        provider: FoundationModelsProviderKind.apple,
        providerName: 'appleSpeech',
        usedAudioMode: result.usedMode,
        segments: result.segments,
        metadata: result.metadata,
      );
    } on Object catch (error) {
      if (!allowExternalFallback) {
        throw _asFoundationModelsException(error);
      }
    }

    final FoundationModelsExternalTranscriptionProvider? externalProvider =
        _externalTranscriptionProvider;
    if (externalProvider == null) {
      throw const FoundationModelsException(
        code: FoundationModelsErrorCode.speechRecognitionUnavailable,
        message:
            'Apple transcription failed and no external transcription provider is configured.',
      );
    }

    try {
      final bool available = await Future<bool>.value(
        externalProvider.isAvailable(),
      );
      if (!available) {
        throw FoundationModelsException(
          code: FoundationModelsErrorCode.speechRecognitionUnavailable,
          message:
              'External transcription provider ${externalProvider.name} is unavailable.',
        );
      }

      final FoundationModelsExternalTranscriptionResult result =
          await externalProvider.transcribeAudio(request);
      return OrchestratedTranscriptionResult(
        text: result.text,
        isFinal: result.isFinal,
        provider: FoundationModelsProviderKind.external,
        providerName: externalProvider.name,
        segments: result.segments,
        metadata: result.metadata,
      );
    } on Object catch (error) {
      throw _asFoundationModelsException(error);
    }
  }

  /// Starts a hybrid multi-turn chat.
  ///
  /// The returned session keeps one shared conversation history. Apple turns
  /// reuse a native `LanguageModelSession`; external turns receive the same
  /// history through [FoundationModelsRequest.history], so the conversation
  /// survives when routing falls back between local and remote providers.
  FoundationModelsChatSession startChat({
    String? instructions,
    String? localeIdentifier,
    GenerationOptions? options,
    FoundationModelsTask defaultTask = FoundationModelsTask.general,
  }) {
    return FoundationModelsChatSession._(
      orchestrator: this,
      instructions: instructions ?? _defaults.instructions,
      localeIdentifier: localeIdentifier ?? _defaults.localeIdentifier,
      options: options ?? _defaults.options,
      defaultTask: defaultTask,
    );
  }

  FoundationModelsRequest _request({
    required Prompt prompt,
    required FoundationModelsTask task,
    required String? instructions,
    required GenerationOptions? options,
    required List<ModelTool>? tools,
    required Map<String, Object?> metadata,
    required String? localeIdentifier,
    StructuredSchema? schema,
    List<FoundationModelsChatMessage> history =
        const <FoundationModelsChatMessage>[],
  }) {
    return FoundationModelsRequest(
      prompt: prompt,
      task: task,
      instructions: instructions ?? _defaults.instructions,
      options: options ?? _defaults.options,
      tools: tools ?? _defaults.tools,
      metadata: <String, Object?>{..._defaults.metadata, ...metadata},
      schema: schema,
      localeIdentifier: localeIdentifier ?? _defaults.localeIdentifier,
      history: history,
    );
  }

  Future<OrchestratedModelResponse> _run(
    FoundationModelsRequest request,
  ) async {
    final FoundationModelsRuntimeContext context = await getRuntimeContext(
      localeIdentifier: request.localeIdentifier,
    );
    final List<FoundationModelsRoute> routes =
        await Future<List<FoundationModelsRoute>>.value(
          _router.resolve(request, context),
        );
    final List<FoundationModelsRouteAttempt> attempts =
        <FoundationModelsRouteAttempt>[];

    for (final FoundationModelsRoute route in routes) {
      try {
        if (!_isRouteAvailable(route, context)) {
          attempts.add(
            FoundationModelsRouteAttempt(
              route: route,
              succeeded: false,
              wasAvailable: false,
              message: _unavailableMessage(route, context),
            ),
          );
          continue;
        }

        final OrchestratedModelResponse response = route.isApple
            ? await _runApple(request, route, attempts)
            : await _runExternal(request, route, attempts);
        return response;
      } on Object catch (error) {
        final FoundationModelsException exception =
            _asFoundationModelsException(error);
        attempts.add(
          FoundationModelsRouteAttempt(
            route: route,
            succeeded: false,
            wasAvailable: true,
            message: exception.message,
            errorCode: exception.code,
          ),
        );
        if (!_router.fallbackOnError) {
          throw exception;
        }
      }
    }

    throw FoundationModelsException(
      code: FoundationModelsErrorCode.modelUnavailable,
      message: 'No configured model route could handle this request.',
      recoverySuggestion:
          'Check Apple model availability, cloud policy, or configure an external provider.',
      details: <String, Object?>{
        'attempts': attempts
            .map((FoundationModelsRouteAttempt value) => value.toMap())
            .toList(growable: false),
      },
    );
  }

  Future<OrchestratedModelResponse> _runApple(
    FoundationModelsRequest request,
    FoundationModelsRoute route,
    List<FoundationModelsRouteAttempt> attempts,
  ) async {
    final ModelMode mode = route.mode ?? ModelMode.local;
    final CloudPolicy cloudPolicy = route.cloudPolicy ?? CloudPolicy.never;
    final FoundationModelSession session = await _apple.createSession(
      options: SessionOptions(
        mode: mode,
        cloudPolicy: cloudPolicy,
        instructions: request.instructions,
        tools: request.tools,
        metadata: <String, Object?>{
          ...request.metadata,
          'orchestrationRoute': route.label,
        },
      ),
    );

    try {
      final GenerationOptions routeOptions = _optionsForRoute(
        request.options,
        route,
      );
      final ModelResponse response = request.schema == null
          ? await session.respond(request.prompt, options: routeOptions)
          : await session.generateStructured(
              prompt: request.prompt,
              schema: request.schema!,
              options: routeOptions,
            );
      return OrchestratedModelResponse(
        text: response.text,
        provider: FoundationModelsProviderKind.apple,
        providerName: 'apple',
        route: route,
        usedMode: response.usedMode,
        structuredValue: response.structuredValue,
        metadata: response.metadata,
        attempts: <FoundationModelsRouteAttempt>[
          ...attempts,
          FoundationModelsRouteAttempt(
            route: route,
            succeeded: true,
            wasAvailable: true,
          ),
        ],
      );
    } finally {
      await session.dispose();
    }
  }

  Future<OrchestratedModelResponse> _runExternal(
    FoundationModelsRequest request,
    FoundationModelsRoute route,
    List<FoundationModelsRouteAttempt> attempts,
  ) async {
    final FoundationModelsExternalProvider? externalProvider =
        _externalProvider;
    if (externalProvider == null) {
      throw const FoundationModelsException(
        code: FoundationModelsErrorCode.modelUnavailable,
        message: 'No external model provider is configured.',
      );
    }

    if (!externalProvider.supports(request)) {
      throw FoundationModelsException(
        code: FoundationModelsErrorCode.modelUnavailable,
        message:
            'External provider ${externalProvider.name} does not support this request.',
      );
    }

    final FoundationModelsProviderResponse response = await externalProvider
        .respond(request);
    return OrchestratedModelResponse(
      text: response.text,
      provider: FoundationModelsProviderKind.external,
      providerName: externalProvider.name,
      route: route,
      structuredValue: response.structuredValue,
      metadata: response.metadata,
      attempts: <FoundationModelsRouteAttempt>[
        ...attempts,
        FoundationModelsRouteAttempt(
          route: route,
          succeeded: true,
          wasAvailable: true,
        ),
      ],
    );
  }

  bool _isRouteAvailable(
    FoundationModelsRoute route,
    FoundationModelsRuntimeContext context,
  ) {
    return switch (route.backend) {
      FoundationModelsRouteBackend.appleLocal => context.canUseAppleLocal,
      FoundationModelsRouteBackend.applePrivateCloud =>
        context.canUseApplePrivateCloud,
      FoundationModelsRouteBackend.appleAutomatic =>
        context.canUseAppleLocal ||
            (route.cloudPolicy != CloudPolicy.never &&
                context.canUseApplePrivateCloud),
      FoundationModelsRouteBackend.external =>
        context.canUseExternal &&
            (route.providerName == null ||
                route.providerName == context.externalProviderName),
    };
  }

  String _unavailableMessage(
    FoundationModelsRoute route,
    FoundationModelsRuntimeContext context,
  ) {
    return switch (route.backend) {
      FoundationModelsRouteBackend.appleLocal =>
        context.localAvailability?.recoverySuggestion ??
            context.localAvailability?.reason ??
            context.localAvailability?.status.name ??
            'Apple local model is unavailable.',
      FoundationModelsRouteBackend.applePrivateCloud =>
        context.privateCloudAvailability?.recoverySuggestion ??
            context.privateCloudAvailability?.reason ??
            context.privateCloudAvailability?.status.name ??
            'Apple Private Cloud Compute is unavailable.',
      FoundationModelsRouteBackend.appleAutomatic =>
        'No Apple route is available for automatic mode.',
      FoundationModelsRouteBackend.external =>
        'External provider is not configured or unavailable.',
    };
  }

  AudioTranscriptionRequest _audioRequest(AudioTranscriptionRequest request) {
    if (request.mode != AudioTranscriptionMode.automatic) {
      return request;
    }
    return AudioTranscriptionRequest(
      filePath: request.filePath,
      localeIdentifier: request.localeIdentifier,
      mode: _defaults.audioTranscriptionMode,
      taskHint: request.taskHint,
      addsPunctuation: request.addsPunctuation,
      timeout: request.timeout,
    );
  }

  GenerationOptions _optionsForRoute(
    GenerationOptions options,
    FoundationModelsRoute route,
  ) {
    final CloudPolicy? cloudPolicy = route.cloudPolicy;
    if (cloudPolicy == null || cloudPolicy == options.cloudPolicy) {
      return options;
    }

    return GenerationOptions(
      samplingMode: options.samplingMode,
      temperature: options.temperature,
      maximumResponseTokens: options.maximumResponseTokens,
      toolCallingPolicy: options.toolCallingPolicy,
      reasoningLevel: options.reasoningLevel,
      cloudPolicy: cloudPolicy,
      includeSchemaInPrompt: options.includeSchemaInPrompt,
      timeout: options.timeout,
    );
  }

  FoundationModelsException _asFoundationModelsException(Object error) {
    if (error is FoundationModelsException) {
      return error;
    }
    return FoundationModelsException(
      code: FoundationModelsErrorCode.nativeFailure,
      message: error.toString(),
    );
  }
}

/// Multi-turn hybrid chat that keeps one conversation across routes.
///
/// Created with [FoundationModelsOrchestrator.startChat]. Apple turns reuse a
/// persistent native session so the on-device transcript carries the context.
/// When a turn is served by an external provider, or the Apple session becomes
/// stale, the shared history is replayed so every route sees the same
/// conversation.
final class FoundationModelsChatSession {
  FoundationModelsChatSession._({
    required FoundationModelsOrchestrator orchestrator,
    required this.instructions,
    required this.localeIdentifier,
    required GenerationOptions options,
    required FoundationModelsTask defaultTask,
  }) : _orchestrator = orchestrator,
       _options = options,
       _defaultTask = defaultTask;

  final FoundationModelsOrchestrator _orchestrator;

  /// Session instructions shared by every route.
  final String? instructions;

  /// Locale identifier used for availability checks and Apple sessions.
  final String? localeIdentifier;

  final GenerationOptions _options;
  final FoundationModelsTask _defaultTask;
  final List<FoundationModelsChatMessage> _history =
      <FoundationModelsChatMessage>[];

  FoundationModelSession? _appleSession;
  String? _appleRouteLabel;
  int _appleHistorySynced = 0;
  bool _needsBackfill = false;
  bool _disposed = false;

  /// Conversation turns so far, oldest first.
  List<FoundationModelsChatMessage> get history =>
      List<FoundationModelsChatMessage>.unmodifiable(_history);

  /// Sends one user message and returns the orchestrated response.
  Future<OrchestratedModelResponse> send(
    String text, {
    FoundationModelsTask? task,
    List<PromptAttachment> attachments = const <PromptAttachment>[],
    GenerationOptions? options,
  }) async {
    _checkNotDisposed();
    final FoundationModelsRequest request = _chatRequest(
      text: text,
      task: task,
      attachments: attachments,
      options: options,
    );
    final FoundationModelsRuntimeContext context = await _orchestrator
        .getRuntimeContext(localeIdentifier: request.localeIdentifier);
    final List<FoundationModelsRoute> routes =
        await Future<List<FoundationModelsRoute>>.value(
          _orchestrator._router.resolve(request, context),
        );
    final List<FoundationModelsRouteAttempt> attempts =
        <FoundationModelsRouteAttempt>[];

    for (final FoundationModelsRoute route in routes) {
      if (!_orchestrator._isRouteAvailable(route, context)) {
        attempts.add(
          FoundationModelsRouteAttempt(
            route: route,
            succeeded: false,
            wasAvailable: false,
            message: _orchestrator._unavailableMessage(route, context),
          ),
        );
        continue;
      }

      try {
        final OrchestratedModelResponse response = route.isApple
            ? await _sendApple(request, route, attempts)
            : await _orchestrator._runExternal(request, route, attempts);
        _commitTurn(text, response);
        return response;
      } on Object catch (error) {
        final FoundationModelsException exception = _orchestrator
            ._asFoundationModelsException(error);
        attempts.add(
          FoundationModelsRouteAttempt(
            route: route,
            succeeded: false,
            wasAvailable: true,
            message: exception.message,
            errorCode: exception.code,
          ),
        );
        if (route.isApple) {
          await _disposeAppleSession();
        }
        if (!_orchestrator._router.fallbackOnError) {
          throw exception;
        }
      }
    }

    throw _noRouteException(attempts);
  }

  /// Sends one user message and streams cumulative text snapshots.
  ///
  /// When a route fails mid-stream and fallback is allowed, the next route
  /// starts again from an empty snapshot; replace the rendered text with each
  /// [OrchestratedChatTextEvent].
  Stream<OrchestratedChatEvent> sendStream(
    String text, {
    FoundationModelsTask? task,
    List<PromptAttachment> attachments = const <PromptAttachment>[],
    GenerationOptions? options,
  }) async* {
    _checkNotDisposed();
    final FoundationModelsRequest request = _chatRequest(
      text: text,
      task: task,
      attachments: attachments,
      options: options,
    );
    final FoundationModelsRuntimeContext context = await _orchestrator
        .getRuntimeContext(localeIdentifier: request.localeIdentifier);
    final List<FoundationModelsRoute> routes =
        await Future<List<FoundationModelsRoute>>.value(
          _orchestrator._router.resolve(request, context),
        );
    final List<FoundationModelsRouteAttempt> attempts =
        <FoundationModelsRouteAttempt>[];

    for (final FoundationModelsRoute route in routes) {
      if (!_orchestrator._isRouteAvailable(route, context)) {
        attempts.add(
          FoundationModelsRouteAttempt(
            route: route,
            succeeded: false,
            wasAvailable: false,
            message: _orchestrator._unavailableMessage(route, context),
          ),
        );
        continue;
      }

      OrchestratedModelResponse? completed;
      FoundationModelsException? failure;

      try {
        if (route.isApple) {
          final FoundationModelSession session = await _ensureAppleSession(
            route,
            request,
          );
          final Prompt prompt = _effectivePrompt(request);
          final GenerationOptions routeOptions = _orchestrator._optionsForRoute(
            request.options,
            route,
          );
          await for (final SessionEvent event in session.stream(
            prompt,
            options: routeOptions,
          )) {
            switch (event) {
              case TextDeltaEvent():
                yield OrchestratedChatTextEvent(text: event.text, route: route);
              case CompletionEvent():
                completed = OrchestratedModelResponse(
                  text: event.response.text,
                  provider: FoundationModelsProviderKind.apple,
                  providerName: 'apple',
                  route: route,
                  usedMode: event.response.usedMode,
                  structuredValue: event.response.structuredValue,
                  metadata: event.response.metadata,
                  attempts: <FoundationModelsRouteAttempt>[
                    ...attempts,
                    FoundationModelsRouteAttempt(
                      route: route,
                      succeeded: true,
                      wasAvailable: true,
                    ),
                  ],
                );
              case FailureEvent():
                failure = FoundationModelsException(
                  code: FoundationModelsErrorCode.nativeFailure,
                  message: event.message,
                );
              case ToolCallEvent():
              case UnknownSessionEvent():
                break;
            }
          }
        } else {
          final FoundationModelsExternalProvider? provider =
              _orchestrator._externalProvider;
          if (provider == null || !provider.supports(request)) {
            throw const FoundationModelsException(
              code: FoundationModelsErrorCode.modelUnavailable,
              message:
                  'No external provider is configured for this chat request.',
            );
          }
          String snapshot = '';
          await for (final String textSnapshot in provider.respondStream(
            request,
          )) {
            snapshot = textSnapshot;
            yield OrchestratedChatTextEvent(text: snapshot, route: route);
          }
          completed = OrchestratedModelResponse(
            text: snapshot,
            provider: FoundationModelsProviderKind.external,
            providerName: provider.name,
            route: route,
            attempts: <FoundationModelsRouteAttempt>[
              ...attempts,
              FoundationModelsRouteAttempt(
                route: route,
                succeeded: true,
                wasAvailable: true,
              ),
            ],
          );
        }
      } on Object catch (error) {
        failure = _orchestrator._asFoundationModelsException(error);
      }

      if (completed != null && failure == null) {
        _commitTurn(text, completed);
        yield OrchestratedChatCompletionEvent(response: completed);
        return;
      }

      final FoundationModelsException exception =
          failure ??
          const FoundationModelsException(
            code: FoundationModelsErrorCode.nativeFailure,
            message: 'The stream ended without a completion event.',
          );
      attempts.add(
        FoundationModelsRouteAttempt(
          route: route,
          succeeded: false,
          wasAvailable: true,
          message: exception.message,
          errorCode: exception.code,
        ),
      );
      if (route.isApple) {
        await _disposeAppleSession();
      }
      if (!_orchestrator._router.fallbackOnError) {
        throw exception;
      }
    }

    throw _noRouteException(attempts);
  }

  /// Clears the conversation and disposes the native Apple session.
  Future<void> reset() async {
    _checkNotDisposed();
    _history.clear();
    await _disposeAppleSession();
  }

  /// Releases the native Apple session held by this chat.
  Future<void> dispose() async {
    if (_disposed) {
      return;
    }
    _disposed = true;
    await _disposeAppleSession();
  }

  FoundationModelsRequest _chatRequest({
    required String text,
    required FoundationModelsTask? task,
    required List<PromptAttachment> attachments,
    required GenerationOptions? options,
  }) {
    return _orchestrator._request(
      prompt: Prompt(text: text, attachments: attachments),
      task: task ?? _defaultTask,
      instructions: instructions,
      options: options ?? _options,
      tools: null,
      metadata: const <String, Object?>{},
      localeIdentifier: localeIdentifier,
      history: history,
    );
  }

  Future<OrchestratedModelResponse> _sendApple(
    FoundationModelsRequest request,
    FoundationModelsRoute route,
    List<FoundationModelsRouteAttempt> attempts,
  ) async {
    final FoundationModelSession session = await _ensureAppleSession(
      route,
      request,
    );
    final Prompt prompt = _effectivePrompt(request);
    final GenerationOptions routeOptions = _orchestrator._optionsForRoute(
      request.options,
      route,
    );
    final ModelResponse response = await session.respond(
      prompt,
      options: routeOptions,
    );
    return OrchestratedModelResponse(
      text: response.text,
      provider: FoundationModelsProviderKind.apple,
      providerName: 'apple',
      route: route,
      usedMode: response.usedMode,
      structuredValue: response.structuredValue,
      metadata: response.metadata,
      attempts: <FoundationModelsRouteAttempt>[
        ...attempts,
        FoundationModelsRouteAttempt(
          route: route,
          succeeded: true,
          wasAvailable: true,
        ),
      ],
    );
  }

  Future<FoundationModelSession> _ensureAppleSession(
    FoundationModelsRoute route,
    FoundationModelsRequest request,
  ) async {
    final FoundationModelSession? existing = _appleSession;
    if (existing != null &&
        _appleRouteLabel == route.label &&
        _appleHistorySynced == _history.length) {
      _needsBackfill = false;
      return existing;
    }

    await _disposeAppleSession();
    final FoundationModelSession session = await _orchestrator._apple
        .createSession(
          options: SessionOptions(
            mode: route.mode ?? ModelMode.local,
            cloudPolicy: route.cloudPolicy ?? CloudPolicy.never,
            instructions: instructions,
            tools: request.tools,
            metadata: <String, Object?>{
              ...request.metadata,
              'orchestrationRoute': route.label,
              'orchestrationChat': true,
            },
          ),
        );
    _appleSession = session;
    _appleRouteLabel = route.label;
    _appleHistorySynced = _history.length;
    _needsBackfill = _history.isNotEmpty;
    return session;
  }

  Prompt _effectivePrompt(FoundationModelsRequest request) {
    if (!_needsBackfill || _history.isEmpty) {
      return request.prompt;
    }

    final StringBuffer buffer = StringBuffer()
      ..writeln('Previous conversation, oldest first:');
    for (final FoundationModelsChatMessage message in _history) {
      buffer.writeln('${message.role.name}: ${message.text}');
    }
    buffer
      ..writeln()
      ..writeln('Continue that conversation. Reply to this user message:')
      ..write(request.prompt.text);

    return Prompt(
      text: buffer.toString(),
      attachments: request.prompt.attachments,
      metadata: request.prompt.metadata,
    );
  }

  void _commitTurn(String userText, OrchestratedModelResponse response) {
    _history
      ..add(
        FoundationModelsChatMessage(
          role: FoundationModelsChatRole.user,
          text: userText,
        ),
      )
      ..add(
        FoundationModelsChatMessage(
          role: FoundationModelsChatRole.assistant,
          text: response.text,
          providerName: response.providerName,
        ),
      );
    if (response.provider == FoundationModelsProviderKind.apple) {
      _appleHistorySynced = _history.length;
    }
    _needsBackfill = false;
  }

  Future<void> _disposeAppleSession() async {
    final FoundationModelSession? session = _appleSession;
    _appleSession = null;
    _appleRouteLabel = null;
    _appleHistorySynced = 0;
    if (session == null) {
      return;
    }
    try {
      await session.dispose();
    } on Object {
      // Best effort: a failed native dispose must not break the chat.
    }
  }

  FoundationModelsException _noRouteException(
    List<FoundationModelsRouteAttempt> attempts,
  ) {
    return FoundationModelsException(
      code: FoundationModelsErrorCode.modelUnavailable,
      message: 'No configured model route could handle this chat message.',
      recoverySuggestion:
          'Check Apple model availability, cloud policy, or configure an external provider.',
      details: <String, Object?>{
        'attempts': attempts
            .map((FoundationModelsRouteAttempt value) => value.toMap())
            .toList(growable: false),
      },
    );
  }

  void _checkNotDisposed() {
    if (_disposed) {
      throw StateError('This chat session was disposed.');
    }
  }
}

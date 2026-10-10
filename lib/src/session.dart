import 'dart:async';

import 'availability.dart';
import 'decoded_model_response.dart';
import 'errors.dart';
import 'generation.dart';
import 'generation_diagnostic_event.dart';
import 'generation_stream.dart';
import 'generation_termination.dart';
import 'generation_trace.dart';
import 'history_payload.dart';
import 'platform/cupertino_foundation_models_platform.dart';
import 'platform/foundation_models_history_platform.dart';
import 'schema.dart';
import 'session_history.dart';
import 'token_budget.dart';
import 'tools.dart';

/// Specialized on-device model variant requested for a session.
enum FoundationModelsUseCase {
  /// The general-purpose Apple on-device model.
  general,

  /// The content-tagging model variant for categorizing and tagging text.
  contentTagging,
}

/// Controls whether Foundation Models keeps transcript entries after an error.
enum TranscriptErrorHandlingPolicy {
  /// Uses the framework's default policy.
  systemDefault,

  /// Reverts transcript mutations made by the failed request.
  revertTranscript,

  /// Preserves transcript mutations made before the failure.
  preserveTranscript,
}

/// Options used when creating a native model session.
final class SessionOptions {
  /// Creates native route, instructions and tool registration choices.
  const SessionOptions({
    this.mode = ModelMode.automatic,
    this.cloudPolicy = CloudPolicy.never,
    this.instructions,
    this.localeIdentifier,
    this.tools = const <ModelTool>[],
    this.useCase = FoundationModelsUseCase.general,
    this.transcriptErrorHandlingPolicy =
        TranscriptErrorHandlingPolicy.systemDefault,
    this.metadata = const <String, Object?>{},
    this.history,
  });

  /// Model route selected when this session is created.
  final ModelMode mode;
  /// Privacy policy governing the initial route selection.
  final CloudPolicy cloudPolicy;
  /// Trusted instructions that apply to each turn of this session.
  final String? instructions;

  /// Optional locale preflight. Set the response language in [instructions].
  final String? localeIdentifier;
  /// Application tools registered with unique non-empty names for this session.
  final List<ModelTool> tools;

  /// On-device model variant. `contentTagging` applies to local sessions only.
  final FoundationModelsUseCase useCase;
  /// Native failed-request history policy, requiring a compatible OS 27 runtime.
  final TranscriptErrorHandlingPolicy transcriptErrorHandlingPolicy;

  /// Caller-owned session metadata supplied to the native bridge.
  final Map<String, Object?> metadata;

  /// Optional compatible native history; restoration is explicit and never replayed.
  final SessionHistory? history;

  /// Serializes session choices and validates tool registration metadata.
  Map<String, Object?> toMap() {
    final List<ToolDefinition> definitions = tools
        .map(ToolDefinition.fromTool)
        .toList(growable: false);
    final snapshot = history;
    if (snapshot != null) {
      if (mode != snapshot.mode || useCase != snapshot.useCase || instructions != null ||
          localeIdentifier != snapshot.localeIdentifier ||
          (snapshot.mode == ModelMode.privateCloudCompute && cloudPolicy == CloudPolicy.never)) {
        throw ArgumentError('Restore the saved route/variant/locale without overriding instructions, and explicitly permit PCC if needed.');
      }
      final registrations = definitions.map((value) => value.toMap()).toList();
      if (!HistoryPayload.equal(registrations, snapshot.tools)) {
        throw ArgumentError('Restoration requires the same ordered tool registrations and current callbacks.');
      }
    }

    return <String, Object?>{
      'mode': mode.name,
      'cloudPolicy': cloudPolicy.name,
      'instructions': instructions,
      'localeIdentifier': localeIdentifier,
      'tools': definitions
          .map((ToolDefinition value) => value.toMap())
          .toList(growable: false),
      'useCase': useCase.name,
      'transcriptErrorHandlingPolicy': transcriptErrorHandlingPolicy.name,
      'metadata': metadata,
      if (snapshot != null) 'history': snapshot.toMap(),
    };
  }
}

/// A live native model session.
///
/// Create sessions through the facade, keep one owner and await [dispose].
/// Each session handles one request at a time, including token measurements and
/// prewarming. History is exported only on request; persistence belongs to the app.
final class FoundationModelSession {
  /// Connects the internal platform to a native session and its registered tools.
  /// Applications normally use the facade's createSession method instead.
  FoundationModelSession({
    required String id,
    required ModelMode mode,
    required CupertinoFoundationModelsPlatform platform,
    required List<ModelTool> tools,
    Map<String, Object?> runtimeMetadata = const <String, Object?>{},
  }) : _id = id,
       _mode = mode,
       _platform = platform,
       _runtimeMetadata = Map<String, Object?>.unmodifiable(runtimeMetadata),
       _tools = Map<String, ModelTool>.unmodifiable(<String, ModelTool>{
         for (final ModelTool tool in tools) tool.name: tool,
       });

  final String _id;
  final ModelMode _mode;
  final CupertinoFoundationModelsPlatform _platform;
  final Map<String, ModelTool> _tools;
  final Map<String, Object?> _runtimeMetadata;
  int _requestSequence = 0;
  bool _requestActive = false;
  bool _disposed = false;
  Future<void>? _cancellation;
  Future<void>? _disposal;
  bool _cancellationFailed = false;

  /// Native session identifier used to route requests and tool callbacks.
  String get id => _id;

  /// Route selected at session creation; request options cannot switch it.
  ModelMode get mode => _mode;

  /// Exports a compatible native transcript while this session is idle.
  /// No files are written or tools executed. Await completion before another request.
  Future<SessionHistory> exportHistory() async {
    _beginRequest();
    try {
      final platform = _platform;
      if (platform is! FoundationModelsHistoryPlatform) {
        throw const FoundationModelsException(code: FoundationModelsErrorCode.unsupportedCapability,
          message: 'This platform does not expose session history.');
      }
      final history = await (platform as FoundationModelsHistoryPlatform).exportSessionHistory(sessionId: _id);
      _checkNotDisposed();
      return history;
    }
    finally { _requestActive = false; }
  }

  /// Generates text using the current session history and registered tools.
  /// Concurrent requests fail rather than queue or overwrite each other.
  Future<ModelResponse> respond(
    Prompt prompt, {
    GenerationOptions options = const GenerationOptions(),
  }) async {
    return _runRequest(options, () {
      return _platform.respond(
        sessionId: _id,
        prompt: prompt,
        options: options,
      );
    });
  }

  /// Streams cumulative text or, with [schema], guided JSON snapshots.
  /// Subscription admits the request. Await cancellation to stop native work.
  /// An unexpected close is an error. Invalid Dart constraints fail before
  /// request admission or cancellation of another native request.
  /// Opt into native structured projections through GenerationOptions when a
  /// schema is supplied; projections remain nonterminal display state.
  Stream<SessionEvent> stream(
    Prompt prompt, {
    StructuredSchema? schema,
    GenerationOptions options = const GenerationOptions(),
  }) {
    return GenerationStream(
      options: options,
      trace: _trace(options),
      begin: () {
        if (options.includeStructuredSnapshots && schema == null) {
          throw ArgumentError('Structured snapshots require a guided stream schema.');
        }
        schema?.toMap();
        _beginRequest();
      },
      end: () => _requestActive = false,
      cancelNative: _cancelNativeRequest,
      cancellationFailed: () => _cancellationFailed = true,
      source: () => _platform.stream(
        sessionId: _id,
        prompt: prompt,
        schema: schema,
        options: options,
      ),
    ).stream;
  }

  /// Streams schema-guided JSON with the same lifecycle as [stream].
  /// Partial snapshots are display state; completion holds final decoded data.
  Stream<SessionEvent> streamStructured({
    required Prompt prompt,
    required StructuredSchema schema,
    GenerationOptions options = const GenerationOptions(),
  }) {
    return stream(prompt, schema: schema, options: options);
  }

  /// Generates final guided data using a supported root schema and native history.
  /// Invalid Dart constraints fail before request admission. Native failures
  /// remain typed and can identify a failing schema path.
  Future<ModelResponse> generateStructured({
    required Prompt prompt,
    required StructuredSchema schema,
    GenerationOptions options = const GenerationOptions(),
  }) async {
    schema.toMap();
    return _runRequest(options, () {
      return _platform.generateStructured(
        sessionId: _id,
        prompt: prompt,
        schema: schema,
        options: options,
      );
    });
  }

  /// Generates and converts a final guided value while retaining its response.
  ///
  /// Uses [generateStructured] and keeps this session owned by the caller.
  /// The synchronous decoder runs once after native request cleanup. Native
  /// diagnostics describe generation; an app decoder failure is separate and
  /// does not poison the session. Read the ModelResponse.decodeStructured
  /// contract for missing/incomplete values and typed conversion failures.
  Future<DecodedModelResponse<T>> generateStructuredDecoded<T>({
    required Prompt prompt,
    required StructuredSchema schema,
    required T Function(Object? value) decoder,
    GenerationOptions options = const GenerationOptions(),
  }) async {
    final response = await generateStructured(
      prompt: prompt,
      schema: schema,
      options: options,
    );
    return response.decodeStructured<T>(decoder: decoder);
  }

  /// Measures separate request components using the session's native local model.
  /// Optional [schema] constraints are included. Counts overlap and must not be
  /// summed as an exact request size. Local counting needs OS 26.4 and a compatible
  /// SDK; PCC counting is unavailable.
  Future<TokenBudget> measureTokenBudget({
    required Prompt prompt,
    StructuredSchema? schema,
    GenerationOptions options = const GenerationOptions(),
  }) async {
    options.toMap();
    schema?.toMap();
    _beginRequest();
    try {
      return await _platform.measureTokenBudget(
        sessionId: _id,
        prompt: prompt,
        schema: schema,
        options: options,
      );
    } finally {
      _requestActive = false;
    }
  }

  /// Hints that the native model should prepare resources for a forthcoming prompt.
  /// Occupies the session until the call finishes and does not prove readiness.
  Future<void> prewarm({Prompt? promptPrefix}) async {
    _beginRequest();
    try {
      await _platform.prewarm(sessionId: _id, promptPrefix: promptPrefix);
    } finally {
      _requestActive = false;
    }
  }

  /// Counts the current local session transcript with Apple's tokenizer.
  Future<int> countTokens() async {
    _beginRequest();
    try {
      return await _platform.countSessionTokens(sessionId: _id);
    } finally {
      _requestActive = false;
    }
  }

  /// Cancels active native work and awaits cleanup before session reuse.
  /// Cannot undo Dart tool effects. Failed cleanup requires disposing this session.
  Future<void> cancelActiveRequest() {
    _checkNotDisposed();
    return _cancelNativeRequest();
  }

  /// Cancels work, releases the native session and prevents further use.
  /// Concurrent callers await the same disposal operation.
  Future<void> dispose() => _disposal ??= _dispose();

  Future<void> _dispose() async {
    _disposed = true;
    try {
      if (_requestActive || _cancellation != null) {
        await _cancelNativeRequest();
      }
    } finally {
      await _platform.disposeSession(sessionId: _id);
    }
  }

  /// Resolves a native invocation against this session's registered tools.
  /// The bridge owns routing. Do not execute tools again just because a streamed
  /// tool event is displayed in an application interface.
  Future<ToolResult> resolveToolCall(ToolCall call) async {
    if (_disposed) {
      return const ToolResult.failure('The session has been disposed.');
    }
    final ModelTool? tool = _tools[call.name];
    if (tool == null) {
      return ToolResult.failure('Tool ${call.name} is not registered.');
    }

    try {
      final Object? resolved = await Future<Object?>.value(
        tool.call(call.arguments),
      ).timeout(tool.timeout);
      return ToolResult.success(resolved);
    } on TimeoutException {
      return ToolResult.failure(
        'Tool ${call.name} timed out after ${tool.timeout.inMilliseconds}ms.',
      );
    } on Object catch (error) {
      return ToolResult.failure(error.toString());
    }
  }

  GenerationTrace _trace(GenerationOptions options) {
    _requestSequence += 1;
    return GenerationTrace(
      requestId: '${_id}_$_requestSequence',
      sessionId: _id,
      mode: _mode,
      configuration: options.diagnostics,
      runtimeMetadata: <String, Object?>{
        ..._runtimeMetadata,
        'packageVersion': '1.9.0',
      },
    );
  }

  Future<ModelResponse> _runRequest(
    GenerationOptions options,
    Future<ModelResponse> Function() operation,
  ) async {
    if (options.includeStructuredSnapshots) {
      throw ArgumentError('Structured snapshots are available only for guided streams.');
    }
    options.toMap();
    _beginRequest();
    final trace = _trace(options);
    trace.emit(GenerationDiagnosticStage.started);
    final timeout = options.totalTimeout ?? options.timeout;
    try {
      final response = await operation().timeout(
        timeout,
        onTimeout: () async {
          await _cancelNativeRequest();
          throw _timeoutException(timeout);
        },
      );
      trace.emit(
        GenerationDiagnosticStage.completed,
        output: response.text,
        usage: response.usage,
        termination: response.termination,
      );
      return response;
    } on Object catch (error) {
      final failure = error is FoundationModelsException ? error : null;
      trace.emit(
        failure?.code == FoundationModelsErrorCode.cancelled
            ? GenerationDiagnosticStage.cancelled
            : GenerationDiagnosticStage.failed,
        errorCode: failure?.code ?? FoundationModelsErrorCode.unknown,
        termination:
            failure?.termination ??
            const GenerationTermination(status: GenerationStatus.failed),
      );
      rethrow;
    } finally {
      _requestActive = false;
    }
  }

  void _beginRequest() {
    _checkNotDisposed();
    if (_cancellationFailed) {
      throw const FoundationModelsException(
        code: FoundationModelsErrorCode.invalidRequest,
        message: 'Native cancellation could not be confirmed for this session.',
        recoverySuggestion: 'Dispose this session and create a new one.',
      );
    }
    if (_requestActive || _cancellation != null) {
      throw const FoundationModelsException(
        code: FoundationModelsErrorCode.concurrentRequests,
        message: 'This session already has an active request.',
        recoverySuggestion:
            'Wait for the active request or cancel it before starting another.',
      );
    }
    _requestActive = true;
  }

  Future<void> _cancelNativeRequest() {
    return _cancellation ??= _performCancellation();
  }

  Future<void> _performCancellation() async {
    try {
      await _platform.cancelActiveRequest(sessionId: _id);
    } on Object {
      _cancellationFailed = true;
      rethrow;
    } finally {
      _cancellation = null;
    }
  }

  void _checkNotDisposed() {
    if (_disposed) {
      throw const FoundationModelsException(
        code: FoundationModelsErrorCode.invalidRequest,
        message: 'This Foundation Models session has already been disposed.',
        recoverySuggestion: 'Create a new session before sending a request.',
      );
    }
  }

  FoundationModelsException _timeoutException(Duration timeout) {
    return FoundationModelsException(
      code: FoundationModelsErrorCode.generationTimeout,
      message: 'The model did not respond within ${timeout.inMilliseconds}ms.',
      recoverySuggestion: 'Shorten the prompt or adjust the request deadline.',
      details: const <String, Object?>{'timeoutPhase': 'total'},
    );
  }
}

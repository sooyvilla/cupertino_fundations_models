import 'dart:async';

import 'availability.dart';
import 'errors.dart';
import 'generation.dart';
import 'generation_diagnostic_event.dart';
import 'generation_stream.dart';
import 'generation_termination.dart';
import 'generation_trace.dart';
import 'platform/cupertino_foundation_models_platform.dart';
import 'schema.dart';
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
  });

  final ModelMode mode;
  final CloudPolicy cloudPolicy;
  final String? instructions;

  /// Optional locale preflight. Set the response language in [instructions].
  final String? localeIdentifier;
  final List<ModelTool> tools;

  /// On-device model variant. `contentTagging` applies to local sessions only.
  final FoundationModelsUseCase useCase;
  final TranscriptErrorHandlingPolicy transcriptErrorHandlingPolicy;

  final Map<String, Object?> metadata;

  Map<String, Object?> toMap() {
    final List<ToolDefinition> definitions = tools
        .map(ToolDefinition.fromTool)
        .toList(growable: false);

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
    };
  }
}

/// A live native model session.
final class FoundationModelSession {
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

  String get id => _id;

  ModelMode get mode => _mode;

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

  Stream<SessionEvent> stream(
    Prompt prompt, {
    StructuredSchema? schema,
    GenerationOptions options = const GenerationOptions(),
  }) {
    return GenerationStream(
      options: options,
      trace: _trace(options),
      begin: _beginRequest,
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

  Stream<SessionEvent> streamStructured({
    required Prompt prompt,
    required StructuredSchema schema,
    GenerationOptions options = const GenerationOptions(),
  }) {
    return stream(prompt, schema: schema, options: options);
  }

  Future<ModelResponse> generateStructured({
    required Prompt prompt,
    required StructuredSchema schema,
    GenerationOptions options = const GenerationOptions(),
  }) async {
    return _runRequest(options, () {
      return _platform.generateStructured(
        sessionId: _id,
        prompt: prompt,
        schema: schema,
        options: options,
      );
    });
  }

  Future<TokenBudget> measureTokenBudget({
    required Prompt prompt,
    StructuredSchema? schema,
    GenerationOptions options = const GenerationOptions(),
  }) async {
    options.toMap();
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

  Future<void> cancelActiveRequest() {
    _checkNotDisposed();
    return _cancelNativeRequest();
  }

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
        'packageVersion': '0.4.3',
      },
    );
  }

  Future<ModelResponse> _runRequest(
    GenerationOptions options,
    Future<ModelResponse> Function() operation,
  ) async {
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
        termination: failure?.termination ??
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
      recoverySuggestion:
          'Shorten the prompt or adjust the request deadline.',
      details: const <String, Object?>{'timeoutPhase': 'total'},
    );
  }
}

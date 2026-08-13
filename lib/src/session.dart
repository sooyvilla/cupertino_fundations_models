import 'dart:async';

import 'availability.dart';
import 'errors.dart';
import 'generation.dart';
import 'platform/cupertino_foundation_models_platform.dart';
import 'schema.dart';
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
    this.tools = const <ModelTool>[],
    this.useCase = FoundationModelsUseCase.general,
    this.transcriptErrorHandlingPolicy =
        TranscriptErrorHandlingPolicy.systemDefault,
    this.metadata = const <String, Object?>{},
  });

  final ModelMode mode;
  final CloudPolicy cloudPolicy;
  final String? instructions;
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
  }) : _id = id,
       _mode = mode,
       _platform = platform,
       _tools = Map<String, ModelTool>.unmodifiable(<String, ModelTool>{
         for (final ModelTool tool in tools) tool.name: tool,
       });

  final String _id;
  final ModelMode _mode;
  final CupertinoFoundationModelsPlatform _platform;
  final Map<String, ModelTool> _tools;
  bool _requestActive = false;
  bool _disposed = false;

  String get id => _id;

  ModelMode get mode => _mode;

  Future<ModelResponse> respond(
    Prompt prompt, {
    GenerationOptions options = const GenerationOptions(),
  }) async {
    return _runRequest<ModelResponse>(options.timeout, () {
      return _platform.respond(
        sessionId: _id,
        prompt: prompt,
        options: options,
      );
    });
  }

  Stream<SessionEvent> stream(
    Prompt prompt, {
    GenerationOptions options = const GenerationOptions(),
  }) async* {
    _beginRequest();
    try {
      final Stream<SessionEvent> events = _platform
          .stream(sessionId: _id, prompt: prompt, options: options)
          .timeout(
            options.timeout,
            onTimeout: (EventSink<SessionEvent> sink) {
              unawaited(_platform.cancelActiveRequest(sessionId: _id));
              sink.addError(_timeoutException(options.timeout));
              sink.close();
            },
          );
      yield* events;
    } finally {
      _requestActive = false;
    }
  }

  Future<ModelResponse> generateStructured({
    required Prompt prompt,
    required StructuredSchema schema,
    GenerationOptions options = const GenerationOptions(),
  }) async {
    return _runRequest<ModelResponse>(options.timeout, () {
      return _platform.generateStructured(
        sessionId: _id,
        prompt: prompt,
        schema: schema,
        options: options,
      );
    });
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
    return _platform.cancelActiveRequest(sessionId: _id);
  }

  Future<void> dispose() async {
    if (_disposed) {
      return;
    }
    _disposed = true;
    if (_requestActive) {
      await _platform.cancelActiveRequest(sessionId: _id);
    }
    await _platform.disposeSession(sessionId: _id);
  }

  Future<ToolResult> resolveToolCall(ToolCall call) async {
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

  Future<T> _runRequest<T>(
    Duration timeout,
    Future<T> Function() operation,
  ) async {
    _beginRequest();
    try {
      return await operation().timeout(
        timeout,
        onTimeout: () async {
          await _platform.cancelActiveRequest(sessionId: _id);
          throw _timeoutException(timeout);
        },
      );
    } finally {
      _requestActive = false;
    }
  }

  void _beginRequest() {
    _checkNotDisposed();
    if (_requestActive) {
      throw const FoundationModelsException(
        code: FoundationModelsErrorCode.concurrentRequests,
        message: 'This session already has an active request.',
        recoverySuggestion:
            'Wait for the active request or cancel it before starting another.',
      );
    }
    _requestActive = true;
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
          'Retry once, shorten the prompt, or increase GenerationOptions.timeout.',
    );
  }
}

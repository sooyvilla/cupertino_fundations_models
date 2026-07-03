import 'dart:async';

import 'availability.dart';
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

/// Options used when creating a native model session.
final class SessionOptions {
  const SessionOptions({
    this.mode = ModelMode.automatic,
    this.cloudPolicy = CloudPolicy.never,
    this.instructions,
    this.tools = const <ModelTool>[],
    this.useCase = FoundationModelsUseCase.general,
    this.metadata = const <String, Object?>{},
  });

  final ModelMode mode;
  final CloudPolicy cloudPolicy;
  final String? instructions;
  final List<ModelTool> tools;

  /// On-device model variant. `contentTagging` applies to local sessions only.
  final FoundationModelsUseCase useCase;

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

  String get id => _id;

  ModelMode get mode => _mode;

  Future<ModelResponse> respond(
    Prompt prompt, {
    GenerationOptions options = const GenerationOptions(),
  }) {
    return _platform.respond(sessionId: _id, prompt: prompt, options: options);
  }

  Stream<SessionEvent> stream(
    Prompt prompt, {
    GenerationOptions options = const GenerationOptions(),
  }) {
    return _platform.stream(sessionId: _id, prompt: prompt, options: options);
  }

  Future<ModelResponse> generateStructured({
    required Prompt prompt,
    required StructuredSchema schema,
    GenerationOptions options = const GenerationOptions(),
  }) {
    return _platform.generateStructured(
      sessionId: _id,
      prompt: prompt,
      schema: schema,
      options: options,
    );
  }

  Future<void> prewarm({Prompt? promptPrefix}) {
    return _platform.prewarm(sessionId: _id, promptPrefix: promptPrefix);
  }

  Future<void> cancelActiveRequest() {
    return _platform.cancelActiveRequest(sessionId: _id);
  }

  Future<void> dispose() {
    return _platform.disposeSession(sessionId: _id);
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
}

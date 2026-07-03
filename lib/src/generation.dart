import 'availability.dart';
import 'schema.dart';

/// Sampling behavior requested from the native model.
enum SamplingMode { greedy, randomTopK, randomProbabilityThreshold }

/// Tool calling preference for a model request.
enum ToolCallingPolicy { automatic, required, disallowed }

/// Reasoning preference for iOS 27 Private Cloud Compute requests.
enum ReasoningLevel { automatic, low, medium, high }

/// A prompt sent to a model.
final class Prompt {
  const Prompt({
    required this.text,
    this.attachments = const <PromptAttachment>[],
    this.metadata = const <String, Object?>{},
  });

  const Prompt.text(String text) : this(text: text);

  final String text;
  final List<PromptAttachment> attachments;
  final Map<String, Object?> metadata;

  Map<String, Object?> toMap() {
    return <String, Object?>{
      'text': text,
      'attachments': attachments
          .map((PromptAttachment value) => value.toMap())
          .toList(growable: false),
      'metadata': metadata,
    };
  }
}

/// Image or file input attached to a prompt.
final class PromptAttachment {
  const PromptAttachment.file({
    required String path,
    String? label,
    String? mimeType,
  }) : this._(path: path, bytes: null, label: label, mimeType: mimeType);

  const PromptAttachment.bytes({
    required List<int> bytes,
    String? label,
    String? mimeType,
  }) : this._(path: null, bytes: bytes, label: label, mimeType: mimeType);

  const PromptAttachment._({
    required this.path,
    required this.bytes,
    required this.label,
    required this.mimeType,
  });

  final String? path;
  final List<int>? bytes;
  final String? label;
  final String? mimeType;

  Map<String, Object?> toMap() {
    return <String, Object?>{
      'path': path,
      'bytes': bytes,
      'label': label,
      'mimeType': mimeType,
    };
  }
}

/// Generation options shared by local and Private Cloud Compute requests.
final class GenerationOptions {
  const GenerationOptions({
    this.samplingMode = SamplingMode.greedy,
    this.temperature,
    this.maximumResponseTokens,
    this.toolCallingPolicy = ToolCallingPolicy.automatic,
    this.reasoningLevel = ReasoningLevel.automatic,
    this.cloudPolicy = CloudPolicy.never,
    this.includeSchemaInPrompt,
    this.timeout = const Duration(seconds: 60),
  });

  final SamplingMode samplingMode;
  final double? temperature;
  final int? maximumResponseTokens;
  final ToolCallingPolicy toolCallingPolicy;
  final ReasoningLevel reasoningLevel;
  final CloudPolicy cloudPolicy;
  final bool? includeSchemaInPrompt;
  final Duration timeout;

  Map<String, Object?> toMap() {
    return <String, Object?>{
      'samplingMode': samplingMode.name,
      'temperature': temperature,
      'maximumResponseTokens': maximumResponseTokens,
      'toolCallingPolicy': toolCallingPolicy.name,
      'reasoningLevel': reasoningLevel.name,
      'cloudPolicy': cloudPolicy.name,
      'includeSchemaInPrompt': includeSchemaInPrompt,
      'timeoutMilliseconds': timeout.inMilliseconds,
    };
  }
}

/// A complete model response.
final class ModelResponse {
  const ModelResponse({
    required this.text,
    required this.usedMode,
    required this.metadata,
    this.structuredValue,
  });

  factory ModelResponse.fromMap(Map<Object?, Object?> map) {
    final Map<Object?, Object?> rawMetadata =
        (map['metadata'] as Map<Object?, Object?>?) ?? <Object?, Object?>{};
    final Map<Object?, Object?>? rawStructured =
        map['structuredValue'] as Map<Object?, Object?>?;

    return ModelResponse(
      text: (map['text'] as String?) ?? '',
      usedMode: _modeFromName(
        (map['usedMode'] as String?) ?? ModelMode.local.name,
      ),
      metadata: rawMetadata.cast<String, Object?>(),
      structuredValue: rawStructured?.cast<String, Object?>(),
    );
  }

  final String text;
  final ModelMode usedMode;
  final Map<String, Object?> metadata;
  final Map<String, Object?>? structuredValue;
}

/// Options used when requesting structured output.
final class StructuredGenerationRequest {
  const StructuredGenerationRequest({
    required this.prompt,
    required this.schema,
    this.options = const GenerationOptions(),
  });

  final Prompt prompt;
  final StructuredSchema schema;
  final GenerationOptions options;

  Map<String, Object?> toMap() {
    return <String, Object?>{
      'prompt': prompt.toMap(),
      'schema': schema.toMap(),
      'options': options.toMap(),
    };
  }
}

/// A streamed event emitted by a model request.
sealed class SessionEvent {
  const SessionEvent();

  factory SessionEvent.fromMap(Map<Object?, Object?> map) {
    final String type = (map['type'] as String?) ?? 'unknown';
    switch (type) {
      case 'textDelta':
        return TextDeltaEvent(
          requestId: (map['requestId'] as String?) ?? '',
          text: (map['text'] as String?) ?? '',
        );
      case 'toolCall':
        return ToolCallEvent(
          requestId: (map['requestId'] as String?) ?? '',
          toolCallId: (map['toolCallId'] as String?) ?? '',
          name: (map['name'] as String?) ?? '',
          arguments:
              (map['arguments'] as Map<Object?, Object?>?)
                  ?.cast<String, Object?>() ??
              <String, Object?>{},
        );
      case 'completed':
        return CompletionEvent(
          requestId: (map['requestId'] as String?) ?? '',
          response: ModelResponse.fromMap(
            (map['response'] as Map<Object?, Object?>?) ?? <Object?, Object?>{},
          ),
        );
      case 'failed':
        return FailureEvent(
          requestId: (map['requestId'] as String?) ?? '',
          code: (map['code'] as String?) ?? 'unknown',
          message: (map['message'] as String?) ?? 'Request failed.',
        );
      default:
        return UnknownSessionEvent(payload: map.cast<String, Object?>());
    }
  }
}

final class TextDeltaEvent extends SessionEvent {
  /// Creates a streamed text delta event.
  const TextDeltaEvent({required this.requestId, required this.text});

  /// Identifier of the request that produced this event.
  final String requestId;

  /// Incremental text emitted by the model.
  final String text;
}

/// Event emitted when the model requests a tool call.
final class ToolCallEvent extends SessionEvent {
  /// Creates a streamed tool-call event.
  const ToolCallEvent({
    required this.requestId,
    required this.toolCallId,
    required this.name,
    required this.arguments,
  });

  /// Identifier of the request that produced this event.
  final String requestId;

  /// Native identifier for this tool invocation.
  final String toolCallId;

  /// Name of the registered tool the model wants to call.
  final String name;

  /// Arguments provided by the model for the tool call.
  final Map<String, Object?> arguments;
}

/// Event emitted when a streamed request completes successfully.
final class CompletionEvent extends SessionEvent {
  /// Creates a completion event.
  const CompletionEvent({required this.requestId, required this.response});

  /// Identifier of the request that completed.
  final String requestId;

  /// Final model response for the request.
  final ModelResponse response;
}

/// Event emitted when a streamed request fails.
final class FailureEvent extends SessionEvent {
  /// Creates a failure event.
  const FailureEvent({
    required this.requestId,
    required this.code,
    required this.message,
  });

  /// Identifier of the request that failed.
  final String requestId;

  /// Stable error code returned by the native implementation.
  final String code;

  /// Human-readable error message.
  final String message;
}

/// Event used when the native side sends an unknown event payload.
final class UnknownSessionEvent extends SessionEvent {
  /// Creates an unknown event wrapper.
  const UnknownSessionEvent({required this.payload});

  /// Raw event payload received from the native implementation.
  final Map<String, Object?> payload;
}

ModelMode _modeFromName(String name) {
  for (final ModelMode value in ModelMode.values) {
    if (value.name == name) {
      return value;
    }
  }
  return ModelMode.local;
}

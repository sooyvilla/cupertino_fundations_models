import 'availability.dart';
import 'decoded_model_response.dart';
import 'errors.dart';
import 'generation_diagnostics.dart';
import 'generation_termination.dart';
import 'schema.dart';
import 'structured_decoding_exception.dart';
import 'structured_snapshot.dart';

/// Sampling behavior requested from the native model.
enum SamplingMode {
  /// Selects the most likely next token without stochastic sampling.
  greedy,
  /// Samples among the configured top K candidates.
  randomTopK,
  /// Samples within the configured cumulative probability threshold.
  randomProbabilityThreshold,
}

/// Tool calling mode for a model request on iOS or macOS 27 or later.
enum ToolCallingMode {
  /// Lets a compatible model decide whether to call registered tools.
  allowed,
  /// Requires tool use, with a bounded call budget and at least one tool.
  required,
  /// Prevents tool use for this request.
  disallowed,
}

/// Reasoning preference for iOS or macOS 27 Private Cloud Compute requests.
final class ReasoningLevel {
  /// Requests a native custom reasoning label; the value must be non-empty.
  const ReasoningLevel.custom(String value)
    : this._('custom', customValue: value);

  const ReasoningLevel._(this.name, {this.customValue});

  /// Lets the compatible model choose its reasoning level.
  static const ReasoningLevel automatic = ReasoningLevel._('automatic');
  /// Requests the native light reasoning level.
  static const ReasoningLevel light = ReasoningLevel._('light');
  /// Requests the native moderate reasoning level.
  static const ReasoningLevel moderate = ReasoningLevel._('moderate');
  /// Requests the native deep reasoning level.
  static const ReasoningLevel deep = ReasoningLevel._('deep');

  /// Native selection name used by the bridge.
  final String name;
  /// Custom label when [name] is custom, otherwise null.
  final String? customValue;
}

/// A prompt sent to a model.
final class Prompt {
  /// Creates text input with optional attachments and caller-owned metadata.
  const Prompt({
    required this.text,
    this.attachments = const <PromptAttachment>[],
    this.metadata = const <String, Object?>{},
  });

  /// Creates a text-only prompt without changing model instructions.
  const Prompt.text(String text) : this(text: text);

  /// User-supplied content; native instructions have a separate higher priority.
  final String text;
  /// Files or encoded content for the bridge's supported extraction paths.
  final List<PromptAttachment> attachments;
  /// Caller-supplied transport metadata; it does not grant permissions or consent.
  final Map<String, Object?> metadata;

  /// Serializes text, attachments and metadata for the native request.
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

/// A file or encoded input processed by the bridge's local extraction path.
///
/// Text and text PDFs become prompt text. Images use Vision extraction where
/// supported; this object does not enable native multimodal image reasoning.
final class PromptAttachment {
  /// References a host file by absolute path; the bridge reads it natively.
  const PromptAttachment.file({
    required String path,
    String? label,
    String? mimeType,
  }) : this._(path: path, bytes: null, label: label, mimeType: mimeType);

  /// Supplies encoded input bytes and optional hints about their content.
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

  /// Host file path for a file attachment, otherwise null.
  final String? path;
  /// Encoded data for a byte attachment, otherwise null.
  final List<int>? bytes;
  /// Optional name used to identify extracted content in the prompt.
  final String? label;
  /// Optional MIME hint used when identifying the input format.
  final String? mimeType;

  /// Serializes the attachment descriptor without reading its file.
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
  /// Creates request options; runtime validation also applies to const values.
  ///
  /// Unspecified native options inherit the model's defaults. Deadlines do not
  /// promise immediate cleanup, and a token limit does not prove completeness.
  const GenerationOptions({
    this.samplingMode = SamplingMode.greedy,
    this.samplingTopK = 40,
    this.samplingProbabilityThreshold = 0.95,
    this.samplingSeed,
    this.temperature,
    this.maximumResponseTokens,
    this.maximumToolCalls = 16,
    this.toolCallingMode = ToolCallingMode.allowed,
    this.reasoningLevel = ReasoningLevel.automatic,
    this.cloudPolicy,
    this.includeSchemaInPrompt,
    this.includeStructuredSnapshots = false,
    this.timeout = const Duration(seconds: 60),
    this.firstResponseTimeout,
    this.idleTimeout,
    this.totalTimeout,
    this.diagnostics,
  });

  /// Strategy used to select tokens from a compatible native model.
  final SamplingMode samplingMode;
  /// Positive candidate count used by top-K sampling.
  final int samplingTopK;
  /// Finite probability threshold between zero and one for stochastic sampling.
  final double samplingProbabilityThreshold;
  /// Optional non-negative seed for stochastic modes; greedy sampling ignores it.
  final int? samplingSeed;
  /// Optional finite temperature between zero and one supported by this API.
  final double? temperature;
  /// Requested positive response-token limit, subject to native model behavior.
  final int? maximumResponseTokens;

  /// Maximum number of native tool invocations allowed for one request.
  ///
  /// This provides the required exit condition when `toolCallingMode` is
  /// `required` and also bounds accidental tool-call loops.
  final int maximumToolCalls;
  /// Tool-use preference; non-default modes require OS 27 and model support.
  final ToolCallingMode toolCallingMode;
  /// PCC reasoning preference; non-default levels require a compatible OS 27 model.
  final ReasoningLevel reasoningLevel;

  /// Optional per-request restriction; null inherits the session policy.
  ///
  /// `never` rejects a request on an existing PCC session. This cannot switch
  /// models or grant cloud access that the session did not authorize.
  final CloudPolicy? cloudPolicy;
  /// Optional native preference for including the schema in the model prompt.
  ///
  /// Availability and behavior depend on the native API path. Null inherits
  /// the package's native default; this does not disable guided constraints.
  final bool? includeSchemaInPrompt;

  /// Adds native structured projections to guided TextSnapshotEvents.
  /// Opt-in and stream-only; text-only/one-shot requests reject this option.
  final bool includeStructuredSnapshots;
  /// One-shot response deadline and fallback stream inactivity interval.
  ///
  /// Cancellation cleanup can continue after the deadline expires.
  final Duration timeout;
  /// Optional stream deadline for the first text snapshot or final response.
  /// Tool events do not satisfy this deadline.
  final Duration? firstResponseTimeout;
  /// Optional stream inactivity deadline after response activity begins.
  final Duration? idleTimeout;
  /// Optional total deadline; overrides the one-shot deadline and bounds streams.
  final Duration? totalTimeout;
  /// Optional metadata callback and separately controlled output capture.
  final GenerationDiagnostics? diagnostics;

  /// Validates options and serializes the settings used by the native bridge.
  ///
  /// Throws [ArgumentError] for invalid ranges, deadlines or diagnostic limits,
  /// including when assertions are disabled. Stream-specific deadlines and
  /// diagnostic callbacks remain in Dart rather than crossing the channel.
  Map<String, Object?> toMap() {
    for (final entry in <String, Duration?>{
      'firstResponseTimeout': firstResponseTimeout,
      'idleTimeout': idleTimeout,
      'totalTimeout': totalTimeout,
    }.entries) {
      if (entry.value != null && entry.value! <= Duration.zero) {
        throw ArgumentError.value(entry.value, entry.key, 'Must be positive.');
      }
    }
    if (diagnostics != null && diagnostics!.maximumOutputCharacters < 1) {
      throw ArgumentError.value(
        diagnostics!.maximumOutputCharacters,
        'maximumOutputCharacters',
        'Must be positive.',
      );
    }
    if (timeout <= Duration.zero) {
      throw ArgumentError.value(
        timeout,
        'timeout',
        'Must be greater than zero.',
      );
    }
    if (samplingTopK <= 0 ||
        !samplingProbabilityThreshold.isFinite ||
        samplingProbabilityThreshold < 0 ||
        samplingProbabilityThreshold > 1 ||
        (samplingSeed != null && samplingSeed! < 0) ||
        (maximumResponseTokens != null && maximumResponseTokens! <= 0) ||
        maximumToolCalls < 1 ||
        maximumToolCalls > 128) {
      throw ArgumentError(
        'Generation option values are outside their supported ranges.',
      );
    }
    if (reasoningLevel.name == 'custom' &&
        (reasoningLevel.customValue?.trim().isEmpty ?? true)) {
      throw ArgumentError.value(reasoningLevel.customValue, 'reasoningLevel');
    }
    if (temperature case final value?
        when !value.isFinite || value < 0 || value > 1) {
      throw ArgumentError.value(
        value,
        'temperature',
        'Must be a finite value between zero and one.',
      );
    }
    return <String, Object?>{
      'samplingMode': samplingMode.name,
      'samplingTopK': samplingTopK,
      'samplingProbabilityThreshold': samplingProbabilityThreshold,
      'samplingSeed': samplingSeed,
      'temperature': temperature,
      'maximumResponseTokens': maximumResponseTokens,
      'maximumToolCalls': maximumToolCalls,
      'toolCallingMode': toolCallingMode.name,
      'reasoningLevel': reasoningLevel.name,
      'customReasoningLevel': reasoningLevel.customValue,
      'cloudPolicy': cloudPolicy?.name,
      'includeSchemaInPrompt': includeSchemaInPrompt,
      if (includeStructuredSnapshots) 'includeStructuredSnapshots': true,
      'timeoutMilliseconds': timeout.inMilliseconds,
    };
  }
}

/// A complete model response.
final class ModelResponse {
  /// Creates a final response with unknown native stop reason by default.
  const ModelResponse({
    required this.text,
    required this.usedMode,
    required this.metadata,
    this.structuredValue,
    bool? hasStructuredValue,
    this.usage,
    this.termination = const GenerationTermination(
      status: GenerationStatus.completed,
    ),
  }) : _hasStructuredValue = hasStructuredValue;

  /// Decodes a native response, normalizing structured maps and nested lists.
  factory ModelResponse.fromMap(Map<Object?, Object?> map) {
    final Map<Object?, Object?> rawMetadata =
        (map['metadata'] as Map<Object?, Object?>?) ?? <Object?, Object?>{};
    final Map<Object?, Object?>? rawUsage =
        map['usage'] as Map<Object?, Object?>?;

    return ModelResponse(
      text: (map['text'] as String?) ?? '',
      usedMode: _modeFromName(
        (map['usedMode'] as String?) ?? ModelMode.local.name,
      ),
      metadata: rawMetadata.cast<String, Object?>(),
      structuredValue: _normalizeChannelValue(map['structuredValue']),
      hasStructuredValue: _structuredPresence(map),
      usage: rawUsage == null ? null : ModelUsage.fromMap(rawUsage),
      termination: GenerationTermination.fromMap(
        map['termination'] as Map<Object?, Object?>? ??
            const <Object?, Object?>{},
      ),
    );
  }

  /// Complete response text, or the complete JSON string for guided output.
  final String text;
  /// Model route actually used by the native session.
  final ModelMode usedMode;
  /// Native response metadata, including runtime and implementation caveats.
  final Map<String, Object?> metadata;
  /// Decoded final guided output, including explicit null when presence is true.
  ///
  /// This is not a validation of application facts or business rules.
  /// Use [hasStructuredValue] to distinguish absent data from an explicit null.
  final Object? structuredValue;
  final bool? _hasStructuredValue;

  /// Whether final guided data exists, independently of an explicit null value.
  /// Non-null legacy values imply presence; null requires an explicit true flag.
  /// Contradictory manual presence/value states fail when this getter is read.
  bool get hasStructuredValue {
    if (_hasStructuredValue == false && structuredValue != null) _presenceFailure();
    return _hasStructuredValue ?? structuredValue != null;
  }
  /// Native counters when available; absent counters remain unknown.
  final ModelUsage? usage;
  /// Request outcome and available completeness or stop information.
  final GenerationTermination termination;

  /// Converts the final guided value once using the caller's synchronous decoder.
  ///
  /// Retains this response in the returned [DecodedModelResponse]. The decoder
  /// accepts object, list or scalar values; false, zero and empty values remain
  /// valid. A nullable T may be returned intentionally. No JSON text is reparsed,
  /// no fields are repaired and no generation is retried.
  /// Explicit null input reaches the decoder only when presence is true; missing
  /// data remains a failure. Nullable decoder output is a separate app choice.
  ///
  /// A non-completed response fails with invalidRequest. Missing structured data
  /// or an explicitly incomplete structure fails with parsingFailure before the
  /// decoder is invoked. Unknown completeness is preserved and not inferred.
  /// Decoder throws become [StructuredDecodingException] with the original
  /// cause, stack and response. Native generation diagnostics remain unchanged.
  DecodedModelResponse<T> decodeStructured<T>({
    required T Function(Object? value) decoder,
  }) {
    if (termination.status != GenerationStatus.completed) {
      throw FoundationModelsException(
        code: FoundationModelsErrorCode.invalidRequest,
        message: 'Only completed model responses can be decoded.',
        details: <String, Object?>{
          'decodingStage': 'response',
          'responseStatus': termination.status.name,
        },
      );
    }
    final value = structuredValue;
    if (!hasStructuredValue || termination.structuredContentComplete == false) {
      throw const FoundationModelsException(
        code: FoundationModelsErrorCode.parsingFailure,
        message: 'A final complete structured value is required for decoding.',
        details: <String, Object?>{'decodingStage': 'structuredValue'},
      );
    }
    try {
      return DecodedModelResponse<T>(value: decoder(value), response: this);
    } on Object catch (cause, stackTrace) {
      Error.throwWithStackTrace(
        StructuredDecodingException(response: this, cause: cause, stackTrace: stackTrace),
        stackTrace,
      );
    }
  }
}

/// Token usage returned by Foundation Models on iOS or macOS 27 or later.
final class ModelUsage {
  /// Creates native usage counters without replacing unknown values with zero.
  const ModelUsage({
    required this.inputTokenCount,
    required this.cachedInputTokenCount,
    required this.outputTokenCount,
    required this.reasoningTokenCount,
    required this.totalTokenCount,
  });

  /// Decodes counters exposed by the runtime; every counter may be absent.
  factory ModelUsage.fromMap(Map<Object?, Object?> map) {
    return ModelUsage(
      inputTokenCount: map['inputTokenCount'] as int?,
      cachedInputTokenCount: map['cachedInputTokenCount'] as int?,
      outputTokenCount: map['outputTokenCount'] as int?,
      reasoningTokenCount: map['reasoningTokenCount'] as int?,
      totalTokenCount: map['totalTokenCount'] as int?,
    );
  }

  /// Reported input tokens, or null when unknown.
  final int? inputTokenCount;
  /// Reported cached input tokens; do not infer a cache hit when absent.
  final int? cachedInputTokenCount;
  /// Reported output tokens; this does not establish structure completeness.
  final int? outputTokenCount;
  /// Reported reasoning tokens for a compatible model, or null when unknown.
  final int? reasoningTokenCount;
  /// Native total count, or null; absent totals are not reconstructed from parts.
  final int? totalTokenCount;
}

/// Options used when requesting structured output.
final class StructuredGenerationRequest {
  /// Groups a prompt, supported root schema and request options for serialization.
  const StructuredGenerationRequest({
    required this.prompt,
    required this.schema,
    this.options = const GenerationOptions(),
  });

  /// Supplied content to extract or transform.
  final Prompt prompt;
  /// Supported native schema for the generated result.
  final StructuredSchema schema;
  /// Sampling, budgets, policy restrictions and deadlines for this request.
  final GenerationOptions options;

  /// Validates schema/options and serializes the grouped request.
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
  /// Creates the base of the package's typed stream events.
  const SessionEvent();

  /// Decodes native events, preserving unrecognized payloads as unknown events.
  ///
  /// The legacy textDelta label is interpreted as a cumulative snapshot.
  factory SessionEvent.fromMap(Map<Object?, Object?> map) {
    final String type = (map['type'] as String?) ?? 'unknown';
    switch (type) {
      case 'textDelta':
      case 'textSnapshot':
        final rawSnapshot = map['structuredSnapshot'];
        if (rawSnapshot != null && rawSnapshot is! Map<Object?, Object?>) {
          throw const FoundationModelsException(code: FoundationModelsErrorCode.parsingFailure,
            message: 'The native structured snapshot must be a map.',
            details: {'decodingStage': 'structuredSnapshot'});
        }
        return TextSnapshotEvent(
          requestId: (map['requestId'] as String?) ?? '',
          text: (map['text'] as String?) ?? '',
          structuredSnapshot: rawSnapshot == null ? null : StructuredSnapshot.fromMap(rawSnapshot as Map<Object?, Object?>),
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
          details:
              (map['details'] as Map<Object?, Object?>?)
                  ?.cast<String, Object?>() ??
              const <String, Object?>{},
        );
      default:
        return UnknownSessionEvent(payload: map.cast<String, Object?>());
    }
  }
}

/// Latest cumulative text or guided JSON snapshot, replacing the previous one.
///
/// Partial JSON is display state; use the completion response for final data.
final class TextSnapshotEvent extends SessionEvent {
  /// Creates a streamed cumulative text snapshot event.
  const TextSnapshotEvent({required this.requestId, required this.text, this.structuredSnapshot});

  /// Identifier of the request that produced this event.
  final String requestId;

  /// Latest cumulative text emitted by the model.
  final String text;

  /// Optional native structured projection when explicitly requested.
  /// Replace prior state; even a complete snapshot is not a terminal response.
  final StructuredSnapshot? structuredSnapshot;
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
    this.details = const <String, Object?>{},
  });

  /// Identifier of the request that failed.
  final String requestId;

  /// Stable error code returned by the native implementation.
  final String code;

  /// Human-readable error message.
  final String message;
  /// Native context, such as a failing schema path or timeout phase.
  final Map<String, Object?> details;

  /// Typed terminal outcome derived from this streamed failure.
  GenerationTermination get termination => FoundationModelsException(
    code: FoundationModelsErrorCode.values.firstWhere(
      (value) => value.name == code,
      orElse: () => FoundationModelsErrorCode.unknown,
    ),
    message: message,
    details: details,
  ).termination;
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

bool _structuredPresence(Map<Object?, Object?> map) {
  if (!map.containsKey('hasStructuredValue')) return map['structuredValue'] != null;
  final flag = map['hasStructuredValue'];
  if (flag is! bool || (flag && !map.containsKey('structuredValue')) ||
      (!flag && map['structuredValue'] != null)) {
    _presenceFailure();
  }
  return flag;
}

Never _presenceFailure() => throw const FoundationModelsException(code: FoundationModelsErrorCode.parsingFailure,
  message: 'The final structured-value presence signal is invalid.',
  details: {'decodingStage': 'responsePresence'});

Object? _normalizeChannelValue(Object? value) {
  if (value is Map<Object?, Object?>) {
    return <String, Object?>{
      for (final MapEntry<Object?, Object?> entry in value.entries)
        if (entry.key is String)
          entry.key! as String: _normalizeChannelValue(entry.value),
    };
  }
  if (value is List<Object?>) {
    return value.map(_normalizeChannelValue).toList(growable: false);
  }
  return value;
}

import 'history_payload.dart';

/// A completed historical tool invocation, recorded data rather than authorization.
final class SessionHistoryToolCall {
  SessionHistoryToolCall._(this.id, this.toolName, this.argumentsJson);

  /// Reads a call descriptor; restoration never executes it.
  factory SessionHistoryToolCall.fromMap(Map<String, Object?> map) => SessionHistoryToolCall._(
    HistoryPayload.string(map, 'id'), HistoryPayload.string(map, 'toolName'), HistoryPayload.string(map, 'argumentsJson'));

  /// Native tool-call identifier, paired with its recorded output.
  final String id;
  /// Registered tool name that handled this call.
  final String toolName;
  /// Complete recorded argument JSON, not permission to invoke the tool again.
  final String argumentsJson;

  /// Serializes inspectable call data without invoking a tool.
  Map<String, Object?> toMap() => {'id': id, 'toolName': toolName, 'argumentsJson': argumentsJson};
}

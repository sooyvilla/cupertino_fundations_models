import 'history_payload.dart';
import 'session_history_segment.dart';
import 'session_history_tool_call.dart';

/// An inspectable typed entry paired with an exact native transcript archive.
final class SessionHistoryEntry {
  SessionHistoryEntry._(this.id, this.kind, this.segments, this.toolCalls, this.toolNames, this.assetIDs);

  /// Parses known entry kinds; unsupported binary/future entries are rejected.
  factory SessionHistoryEntry.fromMap(Map<String, Object?> map) {
    final kind = HistoryPayload.string(map, 'kind');
    if (!const {'instructions', 'prompt', 'response', 'toolCalls', 'toolOutput', 'reasoning'}.contains(kind)) HistoryPayload.fail();
    return SessionHistoryEntry._(HistoryPayload.string(map, 'id'), kind,
      List<SessionHistorySegment>.unmodifiable(HistoryPayload.list(map['segments']).map((value) => SessionHistorySegment.fromMap(HistoryPayload.map(value)))),
      List<SessionHistoryToolCall>.unmodifiable(HistoryPayload.list(map['toolCalls']).map((value) => SessionHistoryToolCall.fromMap(HistoryPayload.map(value)))),
      HistoryPayload.strings(map['toolNames']), HistoryPayload.strings(map['assetIDs']));
  }

  /// Stable native entry identifier.
  final String id;
  /// Native entry category retained by this history profile.
  final String kind;
  /// Ordered supported text/structured segments.
  final List<SessionHistorySegment> segments;
  /// Recorded invocations in a toolCalls entry; not executable callbacks.
  final List<SessionHistoryToolCall> toolCalls;
  /// Tool-definition/output names associated with this entry.
  final List<String> toolNames;
  /// Native response asset/version identifiers, not durable file attachments.
  final List<String> assetIDs;

  /// Serializes the descriptor; nativeArchive remains restoration authority.
  Map<String, Object?> toMap() => {'id': id, 'kind': kind,
    'segments': segments.map((value) => value.toMap()).toList(), 'toolCalls': toolCalls.map((value) => value.toMap()).toList(),
    'toolNames': toolNames, 'assetIDs': assetIDs};
}

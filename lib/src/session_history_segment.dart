import 'history_payload.dart';

/// One inspectable text or complete structured segment in a native history archive.
final class SessionHistorySegment {
  SessionHistorySegment._(this.id, this.kind, this.text, this.schemaName, this.structuredJson);

  /// Parses the supported segment profile without reparsing guided content.
  factory SessionHistorySegment.fromMap(Map<String, Object?> map) {
    final kind = HistoryPayload.string(map, 'kind');
    if (kind != 'text' && kind != 'structure') HistoryPayload.fail();
    return SessionHistorySegment._(HistoryPayload.string(map, 'id'), kind,
      kind == 'text' ? HistoryPayload.string(map, 'text', empty: true) : null,
      kind == 'structure' ? HistoryPayload.string(map, 'schemaName', empty: true) : null,
      kind == 'structure' ? HistoryPayload.string(map, 'structuredJson') : null);
  }

  /// Stable native segment identifier retained through export/import.
  final String id;
  /// Supported native segment kind: text or structure.
  final String kind;
  /// Original text for a text segment.
  final String? text;
  /// Native schema label for structured content.
  final String? schemaName;
  /// Complete native guided JSON, including scalar/null content.
  final String? structuredJson;

  /// Serializes this descriptor, without rebuilding the native transcript.
  Map<String, Object?> toMap() => {'id': id, 'kind': kind,
    if (kind == 'text') 'text': text,
    if (kind == 'structure') ...{'schemaName': schemaName, 'structuredJson': structuredJson}};
}

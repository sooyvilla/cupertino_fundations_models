import 'dart:convert';

import 'availability.dart';
import 'history_payload.dart';
import 'session.dart';
import 'session_history_entry.dart';

/// A versioned, immutable native transcript snapshot for explicit app-owned storage.
///
/// The native archive preserves SDK options, formats and metadata beyond these
/// entry descriptors. It is sensitive data, not automatically persisted, logged
/// or uploaded. Restoration validates its host/SDK and tool compatibility.
final class SessionHistory {
  SessionHistory._(this.createdAt, this.mode, this.useCase, this.instructions, this.localeIdentifier,
    this.environment, this.tools, this.entries, this.nativeArchive);

  /// Parses an exported envelope, freezing mutable collections and enforcing bounds.
  factory SessionHistory.fromMap(Map<String, Object?> map) {
    if (map['formatVersion'] != 1 || map['nativeFormat'] != 'apple.transcript.codable') HistoryPayload.fail();
    final date = DateTime.tryParse(HistoryPayload.string(map, 'createdAt'));
    if (date == null || !date.isUtc) HistoryPayload.fail();
    final mode = ModelMode.values.where((value) => value.name == map['mode']).firstOrNull;
    final useCase = FoundationModelsUseCase.values.where((value) => value.name == map['useCase']).firstOrNull;
    if (mode == null || mode == ModelMode.automatic || useCase == null) HistoryPayload.fail();
    final environment = HistoryPayload.map(map['environment']);
    if (environment.values.any((value) => value is! String)) HistoryPayload.fail();
    for (final key in ['platform', 'osVersion', 'sdkIdentifier']) { HistoryPayload.string(environment, key); }
    final entries = HistoryPayload.list(map['entries']).map((value) => SessionHistoryEntry.fromMap(HistoryPayload.map(value))).toList();
    if (entries.length > 256 || entries.map((value) => value.id).toSet().length != entries.length) HistoryPayload.fail();
    final archive = HistoryPayload.string(map, 'nativeArchive');
    if (utf8.encode(archive).length > 1048576) HistoryPayload.fail();
    try { jsonDecode(archive); } on FormatException { HistoryPayload.fail(); }
    final tools = HistoryPayload.list(map['tools']).map((value) => HistoryPayload.freeze(HistoryPayload.map(value))! as Map<String, Object?>).toList();
    return SessionHistory._(date, mode, useCase, HistoryPayload.optionalString(map, 'instructions'),
      HistoryPayload.optionalString(map, 'localeIdentifier'), Map<String, Object?>.unmodifiable(environment),
      List<Map<String, Object?>>.unmodifiable(tools), List<SessionHistoryEntry>.unmodifiable(entries), archive);
  }

  /// Decodes app-retained JSON without performing any native or storage operation.
  factory SessionHistory.fromJson(String json) {
    try { return SessionHistory.fromMap(HistoryPayload.map(jsonDecode(json))); }
    on FormatException { HistoryPayload.fail(); }
  }

  /// UTC export timestamp, not a token-budget or expiration guarantee.
  final DateTime createdAt;
  /// Native route actually used by the source session.
  final ModelMode mode;
  /// Source local model variant; restoration preserves it.
  final FoundationModelsUseCase useCase;
  /// App instructions retained for budget metadata; native context is in the archive.
  final String? instructions;
  /// Source locale preflight identifier, when supplied.
  final String? localeIdentifier;
  /// Source platform, exact OS version and SDK identifier used for compatibility.
  final Map<String, Object?> environment;
  /// Source tool registrations, excluding executable implementations.
  final List<Map<String, Object?>> tools;
  /// Immutable inspectable entries; not a replacement reconstruction format.
  final List<SessionHistoryEntry> entries;
  /// Exact SDK-native Codable transcript JSON, owned and protected by the app.
  final String nativeArchive;

  /// Serializes the envelope without writing, truncating or transferring history.
  Map<String, Object?> toMap() => {'formatVersion': 1, 'nativeFormat': 'apple.transcript.codable',
    'createdAt': createdAt.toIso8601String(), 'mode': mode.name, 'useCase': useCase.name,
    'instructions': instructions, 'localeIdentifier': localeIdentifier, 'environment': environment,
    'tools': tools, 'entries': entries.map((value) => value.toMap()).toList(), 'nativeArchive': nativeArchive};

  /// Produces app-owned JSON; no persistence or external transmission occurs.
  String toJson() => jsonEncode(toMap());
}

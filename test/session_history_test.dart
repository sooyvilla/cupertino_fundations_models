import 'dart:async';

import 'package:cupertino_fundations_models/cupertino_fundations_models.dart';
import 'package:cupertino_fundations_models/src/platform/method_channel_cupertino_foundation_models.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

// ignore: avoid_relative_lib_imports
import '../example/lib/document_extraction.dart';
import 'src/test_helpers.dart';

Map<String, Object?> historyEntry(String id, String kind, {List<Object?> segments = const [], List<Object?> calls = const [], List<String> names = const [], List<String> assets = const []}) => {
  'id': id, 'kind': kind, 'segments': segments, 'toolCalls': calls, 'toolNames': names, 'assetIDs': assets,
};
Map<String, Object?> historyMap({List<Object?> entries = const [], List<Object?> tools = const [], String mode = 'local', String useCase = 'general'}) => {
  'formatVersion': 1, 'nativeFormat': 'apple.transcript.codable', 'createdAt': '2026-10-09T23:00:00Z',
  'mode': mode, 'useCase': useCase, 'instructions': null, 'localeIdentifier': null,
  'environment': {'platform': 'iOS', 'osVersion': 'test-os', 'sdkIdentifier': 'test-sdk'},
  'entries': entries, 'tools': tools, 'nativeArchive': '{}',
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final malformed = throwsA(isA<FoundationModelsException>().having((error) => error.code, 'code', FoundationModelsErrorCode.invalidRequest));

  test('typed entries preserve segments, calls, IDs and app-owned JSON without mutation', () {
    final segments = <Object?>[
      {'kind': 'text', 'id': 'text', 'text': ''},
      {'kind': 'structure', 'id': 'value', 'schemaName': 'Fact', 'structuredJson': 'null'},
    ];
    final calls = <Object?>[{'id': 'call', 'toolName': 'lookup', 'argumentsJson': '{}'}];
    final entries = <Object?>[
      historyEntry('instructions', 'instructions', segments: segments, names: ['lookup']),
      historyEntry('calls', 'toolCalls', calls: calls),
      historyEntry('call', 'toolOutput', names: ['lookup']),
      historyEntry('response', 'response', assets: ['asset-version']),
      historyEntry('reason', 'reasoning'),
    ];
    final map = historyMap(entries: entries, tools: [{'name': 'lookup', 'parameters': {'type': 'object'}}]);
    final history = SessionHistory.fromMap(map);
    final encoded = history.toJson();
    segments.clear(); calls.clear(); entries.clear(); map.clear();
    expect(history.entries.first.segments.first.text, '');
    expect(history.entries.first.segments.last.structuredJson, 'null');
    expect(history.entries[1].toolCalls.single.id, 'call');
    expect(history.entries[1].toolCalls.single.toolName, 'lookup');
    expect(history.entries[1].toolCalls.single.argumentsJson, '{}');
    expect(history.entries[3].assetIDs, ['asset-version']);
    expect(history.entries.clear, throwsUnsupportedError);
    expect(history.entries.first.segments.clear, throwsUnsupportedError);
    expect(history.entries.first.toolNames.clear, throwsUnsupportedError);
    expect(history.environment.clear, throwsUnsupportedError);
    expect(history.tools.single.clear, throwsUnsupportedError);
    expect(SessionHistory.fromJson(encoded).toMap(), history.toMap());
    expect(history.createdAt.isUtc, true);
    expect(history.toString(), isNot(contains('nativeArchive')));
  });

  test('optional metadata and variants remain explicit', () {
    final map = historyMap(useCase: 'contentTagging');
    map['instructions'] = 'Classify'; map['localeIdentifier'] = 'en_US';
    final history = SessionHistory.fromMap(map);
    expect(history.instructions, 'Classify'); expect(history.localeIdentifier, 'en_US');
    expect(history.useCase, FoundationModelsUseCase.contentTagging);
    expect(history.nativeArchive, '{}');
  });

  final corrupt = <Map<String, Object?>>[
    {...historyMap(), 'formatVersion': 2}, {...historyMap(), 'nativeFormat': 'text-only'},
    {...historyMap(), 'createdAt': 'invalid'}, {...historyMap(), 'createdAt': '2026-10-09T23:00:00'},
    {...historyMap(), 'mode': 'automatic'}, {...historyMap(), 'mode': 'unknown'},
    {...historyMap(), 'useCase': 'unknown'}, {...historyMap(), 'environment': 7},
    {...historyMap(), 'environment': {7: 'bad'}},
    {...historyMap(), 'environment': {'platform': 'iOS', 'osVersion': 'x', 'sdkIdentifier': 7}},
    {...historyMap(), 'environment': {'platform': '', 'osVersion': 'x', 'sdkIdentifier': 'sdk'}},
    {...historyMap(), 'entries': 7}, {...historyMap(), 'entries': [historyEntry('same', 'prompt'), historyEntry('same', 'prompt')]},
    {...historyMap(), 'entries': List.generate(257, (i) => historyEntry('e$i', 'prompt'))},
    {...historyMap(), 'entries': [historyEntry('', 'prompt')]}, {...historyMap(), 'entries': [historyEntry('e', 'data')]},
    {...historyMap(), 'entries': [historyEntry('e', 'prompt', names: ['ok'])..['toolNames'] = [7]]},
    {...historyMap(), 'nativeArchive': ''}, {...historyMap(), 'nativeArchive': '{'},
    {...historyMap(), 'nativeArchive': 'x' * 1048577}, {...historyMap(), 'instructions': 7},
    {...historyMap(), 'tools': [{'parameters': {7: 'bad'}}]},
    {...historyMap(), 'tools': [{'parameters': double.nan}]},
    {...historyMap(), 'tools': [{'parameters': DateTime(2026)}]},
  ];
  for (var index = 0; index < corrupt.length; index++) {
    test('malformed envelope $index fails before transport', () {
      expect(() => SessionHistory.fromMap(corrupt[index]), malformed);
    });
  }
  test('bad JSON, segment profiles and deep metadata fail without downconverting', () {
    expect(() => SessionHistory.fromJson('{'), malformed);
    expect(() => SessionHistory.fromJson('[]'), malformed);
    expect(() => SessionHistorySegment.fromMap({'kind': 'attachment', 'id': 'x'}), malformed);
    expect(() => SessionHistorySegment.fromMap({'kind': 'text', 'id': 'x', 'text': 7}), malformed);
    expect(() => SessionHistoryToolCall.fromMap({'id': 'x', 'toolName': '', 'argumentsJson': '{}'}), malformed);
    Object? deep = 0;
    for (var i = 0; i < 34; i++) { deep = [deep]; }
    expect(() => SessionHistory.fromMap(historyMap(tools: [{'metadata': deep}])), malformed);
    final valid = SessionHistory.fromMap(historyMap(tools: [{'metadata': [null, true, 0, 'x']} ]));
    expect((valid.tools.single['metadata']! as List<Object?>).clear, throwsUnsupportedError);
  });

  test('restore options preserve old defaults and require matching route, locale and tools', () {
    expect(const SessionOptions().toMap().containsKey('history'), false);
    final history = SessionHistory.fromMap(historyMap());
    expect(SessionOptions(history: history, mode: ModelMode.local).toMap()['history'], history.toMap());
    for (final options in [
      SessionOptions(history: history),
      SessionOptions(history: history, mode: ModelMode.local, instructions: 'Replace'),
      SessionOptions(history: history, mode: ModelMode.local, localeIdentifier: 'es_ES'),
      SessionOptions(history: history, mode: ModelMode.local, useCase: FoundationModelsUseCase.contentTagging),
    ]) { expect(options.toMap, throwsArgumentError); }
    final cloud = SessionHistory.fromMap(historyMap(mode: 'privateCloudCompute'));
    expect(SessionOptions(history: cloud, mode: ModelMode.privateCloudCompute).toMap, throwsArgumentError);
    expect(SessionOptions(history: cloud, mode: ModelMode.privateCloudCompute, cloudPolicy: CloudPolicy.whenExplicit).toMap()['mode'], 'privateCloudCompute');
  });

  group('history lifecycle and callback isolation', () {
    const channel = MethodChannel('test/session-history');
    final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    late List<MethodCall> calls;
    late Map<String, Object?> archive;
    late CupertinoFoundationModels models;
    setUp(() {
      calls = []; archive = historyMap();
      models = CupertinoFoundationModels(platform: MethodChannelCupertinoFoundationModels(methodChannel: channel));
      messenger.setMockMethodCallHandler(channel, (call) async {
        calls.add(call);
        if (call.method == 'createSession') return {'sessionId': 'history', 'mode': 'local'};
        if (call.method == 'exportSessionHistory') return archive;
        if (call.method == 'respond') return {'text': 'Continued', 'usedMode': 'local'};
        return null;
      });
    });
    tearDown(() => messenger.setMockMethodCallHandler(channel, null));

    test('export and restoration use a new session without replaying generation', () async {
      final original = await models.createSession();
      final snapshot = await original.exportHistory();
      expect(calls.last.method, 'exportSessionHistory');
      await original.dispose();
      final restored = await models.restoreSession(history: SessionHistory.fromJson(snapshot.toJson()));
      expect((calls.last.arguments as Map<Object?, Object?>)['history'], snapshot.toMap());
      expect(calls.where((call) => call.method == 'respond'), isEmpty);
      expect((await restored.respond(const Prompt.text('Next'))).text, 'Continued');
      await restored.dispose();
    });

    test('document history example exports only after final decoding and always disposes', () async {
      messenger.setMockMethodCallHandler(channel, (call) async {
        calls.add(call);
        if (call.method == 'createSession') return {'sessionId': 'document', 'mode': 'local'};
        if (call.method == 'generateStructured') { return {
          'text': '{}', 'usedMode': 'local', 'structuredValue': {'currency': 'EUR', 'rows': <Object?>[]},
        }; }
        if (call.method == 'exportSessionHistory') return archive;
        return null;
      });
      final extracted = await extractDocumentWithHistory(models: models, document: fictionalDocument);
      expect(extracted.result.value.currency, 'EUR');
      expect(extracted.history.toMap(), SessionHistory.fromMap(archive).toMap());
      expect(calls.map((call) => call.method), ['createSession', 'generateStructured', 'exportSessionHistory', 'disposeSession']);
      calls.clear(); archive['nativeArchive'] = '{';
      await expectLater(extractDocumentWithHistory(models: models, document: fictionalDocument, explicitNullDates: true), throwsA(isA<FoundationModelsException>()));
      expect(calls.last.method, 'disposeSession');
      expect((calls[1].arguments as Map<Object?, Object?>)['schema'], nullableDocumentSchema.toMap());
    });

    test('old platform implementations stay valid and report unsupported history', () async {
      final legacy = CupertinoFoundationModels(platform: FakePlatform());
      final session = await legacy.createSession();
      await expectLater(session.exportHistory(), throwsA(isA<FoundationModelsException>().having((error) => error.code, 'code', FoundationModelsErrorCode.unsupportedCapability)));
      await expectLater(legacy.restoreSession(history: SessionHistory.fromMap(historyMap())), throwsA(isA<FoundationModelsException>()));
      await session.dispose();
    });

    test('future tool implementations are required and historical callbacks are never called', () async {
      var executions = 0;
      final tool = TestTool(name: 'lookup', callback: (_) { executions++; return 'future'; }, parameters: {'type': 'object', 'properties': {}});
      archive = historyMap(tools: [ToolDefinition.fromTool(tool).toMap()], entries: [
        historyEntry('calls', 'toolCalls', calls: [{'id': 'call', 'toolName': 'lookup', 'argumentsJson': '{}'}]),
        historyEntry('call', 'toolOutput', names: ['lookup']),
      ]);
      final history = SessionHistory.fromMap(archive);
      await expectLater(models.restoreSession(history: history), throwsArgumentError);
      expect(calls, isEmpty);
      final restored = await models.restoreSession(history: history, tools: [tool]);
      expect(executions, 0);
      final changed = TestTool(name: 'lookup', callback: (_) => null, description: 'Changed', parameters: tool.parameters);
      await expectLater(models.restoreSession(history: history, tools: [changed]), throwsArgumentError);
      await restored.dispose();
    });

    test('export locks the session and blocks concurrent requests until it finishes', () async {
      final pending = Completer<Object?>();
      final started = Completer<void>();
      messenger.setMockMethodCallHandler(channel, (call) async {
        calls.add(call);
        if (call.method == 'createSession') return {'sessionId': 'history', 'mode': 'local'};
        if (call.method == 'exportSessionHistory') { started.complete(); return pending.future; }
        return null;
      });
      final session = await models.createSession();
      final exporting = session.exportHistory(); await started.future;
      await expectLater(session.respond(const Prompt.text('Busy')), throwsA(isA<FoundationModelsException>().having((error) => error.code, 'code', FoundationModelsErrorCode.concurrentRequests)));
      pending.complete(archive); await exporting;
      await session.dispose();
      await expectLater(session.exportHistory(), throwsA(isA<FoundationModelsException>().having((error) => error.code, 'code', FoundationModelsErrorCode.invalidRequest)));
    });

    test('failed export releases admission without cancelling or corrupting history', () async {
      messenger.setMockMethodCallHandler(channel, (call) async {
        calls.add(call);
        if (call.method == 'createSession') return {'sessionId': 'history', 'mode': 'local'};
        if (call.method == 'exportSessionHistory') throw PlatformException(code: 'unsupportedTranscriptContent');
        if (call.method == 'respond') return {'text': 'Still usable'};
        return null;
      });
      final session = await models.createSession();
      await expectLater(session.exportHistory(), throwsA(isA<FoundationModelsException>()));
      expect((await session.respond(const Prompt.text('Next'))).text, 'Still usable');
      expect(calls.where((call) => call.method == 'cancelActiveRequest'), isEmpty);
      await session.dispose();
    });
    test('disposing during an export prevents returning a stale successful snapshot', () async {
      final pending = Completer<Object?>(); final started = Completer<void>();
      messenger.setMockMethodCallHandler(channel, (call) async {
        calls.add(call);
        if (call.method == 'createSession') return {'sessionId': 'history', 'mode': 'local'};
        if (call.method == 'exportSessionHistory') { started.complete(); return pending.future; }
        return null;
      });
      final session = await models.createSession();
      final export = session.exportHistory();
      final assertion = expectLater(export, throwsA(isA<FoundationModelsException>().having((error) => error.code, 'code', FoundationModelsErrorCode.invalidRequest)));
      await started.future; await session.dispose(); pending.complete(archive); await assertion;
      expect(calls.where((call) => call.method == 'cancelActiveRequest'), hasLength(1));
    });
  });
}

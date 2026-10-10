import 'dart:async';

import 'package:cupertino_fundations_models/cupertino_fundations_models.dart';
import 'package:cupertino_fundations_models/src/platform/method_channel_cupertino_foundation_models.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, Object?> snapshotPayload({Object? value = const <String, Object?>{},
  bool hasValue = true, bool isComplete = false, List<String> present = const ['#'],
  List<String> complete = const []}) => {
  'hasValue': hasValue, 'value': value, 'isComplete': isComplete,
  'presentPaths': present, 'completePaths': complete,
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('manual root and nested orders are optional full permutations', () {
    const fields = {'name': SchemaProperty.string(), 'amount': SchemaProperty.string()};
    const legacy = StructuredSchema.object(name: 'Invoice', properties: fields);
    expect(legacy.toMap().containsKey('propertyOrder'), false);
    const ordered = StructuredSchema.object(name: 'Invoice', properties: {
      'rows': SchemaProperty.array(items: SchemaProperty.object(properties: fields, propertyOrder: ['name', 'amount'])),
      'currency': SchemaProperty.string(),
    }, propertyOrder: ['currency', 'rows']);
    final map = ordered.toMap();
    expect(map['propertyOrder'], ['currency', 'rows']);
    final rows = (map['properties']! as Map<String, Object?>)['rows']! as Map<String, Object?>;
    expect((rows['items']! as Map<String, Object?>)['propertyOrder'], ['name', 'amount']);
    expect(const StructuredSchema.object(name: 'Empty', properties: {}, propertyOrder: []).toMap()['propertyOrder'], isEmpty);
    for (final order in <List<String>>[[], ['name'], ['name', 'name'], ['name', 'unknown'], ['name', 'amount', 'extra']]) {
      expect(() => StructuredSchema.object(name: 'Bad', properties: fields, propertyOrder: order).toMap(), throwsArgumentError);
      expect(() => SchemaProperty.object(properties: fields, propertyOrder: order).toMap(), throwsArgumentError);
    }
    expect(const SchemaProperty(type: 'integer', propertyOrder: []).toMap, throwsArgumentError);
    expect(const SchemaProperty(type: 'object', propertyOrder: []).toMap()['propertyOrder'], isEmpty);
  });

  test('JSON orders target object definitions without adding nonstandard keywords', () {
    final names = <String>['name', 'email'];
    final orders = <String, List<String>>{'#/items': names};
    final schema = StructuredSchema.fromJsonSchema({
      'type': 'array', 'items': {'type': 'object', 'additionalProperties': false,
        'properties': {'email': {'type': 'string'}, 'name': {'type': 'string'}}},
    }, propertyOrders: orders);
    names.clear(); orders.clear();
    final item = schema.toMap()['items']! as Map<String, Object?>;
    expect(item['propertyOrder'], ['name', 'email']);
    expect((item['propertyOrder']! as List<String>).clear, throwsUnsupportedError);
    final root = StructuredSchema.fromJsonSchema({'type': 'object', 'additionalProperties': false,
      'properties': {'b': {'type': 'boolean'}, 'a': {'type': 'string'}}}, propertyOrders: {'#': ['a', 'b']});
    expect(root.propertyOrder, ['a', 'b']);
    final escaped = StructuredSchema.fromJsonSchema({'type': 'object', 'additionalProperties': false,
      'properties': {'a/b~c': {'type': 'object', 'additionalProperties': false}}},
      propertyOrders: {'#/properties/a~1b~0c': []});
    expect(escaped.properties['a/b~c']!.propertyOrder, isEmpty);
    for (final input in <Map<String, List<String>>>[{'#/missing': []}, {'#': []}, {'#/items': ['name']}, {'#/items': ['email', 'email']}]) {
      expect(() => StructuredSchema.fromJsonSchema({'type': 'array', 'items': {'type': 'object', 'additionalProperties': false,
        'properties': {'email': {'type': 'string'}, 'name': {'type': 'string'}}}}, propertyOrders: input),
        throwsA(isA<FoundationModelsException>().having((error) => error.code, 'code', FoundationModelsErrorCode.invalidRequest)));
    }
    expect(() => StructuredSchema.fromJsonSchema({'type': 'object', 'additionalProperties': false, 'propertyOrder': []}),
      throwsA(isA<FoundationModelsException>()));
  });

  test('structured state freezes values and distinguishes observed and completed fields', () {
    final rows = <Object?>[<String, Object?>{'amount': '-3,50'}, <String, Object?>{}];
    final value = <String, Object?>{'name': 'Morgan', 'rows': rows};
    final snapshot = StructuredSnapshot.fromMap(snapshotPayload(value: value,
      present: ['#', '#/name', '#/rows', '#/rows/0', '#/rows/0/amount', '#/rows/1', '#/rows/1/amount'],
      complete: ['#/name', '#/rows/0', '#/rows/0/amount']));
    rows.clear(); value.clear();
    expect(snapshot.hasValue, true); expect(snapshot.isComplete, false);
    final frozen = snapshot.value! as Map<String, Object?>;
    expect(frozen['name'], 'Morgan'); expect(frozen['rows'], hasLength(2));
    expect(frozen.clear, throwsUnsupportedError);
    expect((frozen['rows']! as List<Object?>).clear, throwsUnsupportedError);
    expect(snapshot.presentPaths.clear, throwsUnsupportedError);
    expect(snapshot.completePaths.clear, throwsUnsupportedError);
    expect(snapshot.presentPaths, contains('#/rows/1/amount'));
    expect(snapshot.completePaths, isNot(contains('#/rows/1/amount')));
  });

  for (final value in <Object?>[false, 0, 0.0, '', [], {}, null]) {
    test('completed snapshot preserves $value but is not a terminal event', () {
      final event = SessionEvent.fromMap({'type': 'textSnapshot', 'requestId': 'request', 'text': 'raw',
        'structuredSnapshot': snapshotPayload(value: value, isComplete: true, complete: ['#'])}) as TextSnapshotEvent;
      expect(event.structuredSnapshot!.value, value);
      expect(event.structuredSnapshot!.hasValue, true);
      expect(event.structuredSnapshot!.isComplete, true);
      expect(event, isNot(isA<CompletionEvent>()));
    });
  }
  test('an observed unfinished scalar has no invented value', () {
    final snapshot = StructuredSnapshot.fromMap(snapshotPayload(value: null, hasValue: false));
    expect(snapshot.hasValue, false); expect(snapshot.value, isNull);
    expect(snapshot.presentPaths, ['#']); expect(snapshot.completePaths, isEmpty);
    expect(const TextSnapshotEvent(requestId: 'old', text: 'text').structuredSnapshot, isNull);
    expect(const GenerationOptions().toMap().containsKey('includeStructuredSnapshots'), false);
  });

  final corrupt = <Map<String, Object?>>[
    {...snapshotPayload(), 'hasValue': null}, {...snapshotPayload(), 'isComplete': 'false'},
    {...snapshotPayload()}..remove('value'), {...snapshotPayload(), 'presentPaths': 7},
    {...snapshotPayload(), 'presentPaths': [7]}, {...snapshotPayload(), 'presentPaths': ['bad']},
    {...snapshotPayload(), 'presentPaths': ['#', '#']}, {...snapshotPayload(), 'presentPaths': []},
    {...snapshotPayload(), 'completePaths': ['#/missing']}, {...snapshotPayload(), 'completePaths': ['#']},
    {...snapshotPayload(isComplete: true)}, {...snapshotPayload(hasValue: false, value: 7)},
    {...snapshotPayload(hasValue: false, value: null, isComplete: true, complete: ['#'])},
    {...snapshotPayload(value: {7: 'bad'})}, {...snapshotPayload(value: double.nan)},
    {...snapshotPayload(value: DateTime(2026))},
    {...snapshotPayload(value: 'unfinished')},
    {...snapshotPayload(value: double.nan, isComplete: true, complete: ['#'])},
    {...snapshotPayload(value: DateTime(2026), isComplete: true, complete: ['#'])},
    {...snapshotPayload(), 'presentPaths': ['#', '#/foo~2bar']},
  ];
  for (var index = 0; index < corrupt.length; index++) {
    test('malformed snapshot $index returns a typed payload failure', () {
      expect(() => StructuredSnapshot.fromMap(corrupt[index]),
        throwsA(isA<FoundationModelsException>().having((error) => error.details['decodingStage'], 'stage', 'structuredSnapshot')));
    });
  }
  test('snapshot depth cannot recurse indefinitely and wrong event payload fails', () {
    Object? value = true;
    for (var i = 0; i < 17; i++) { value = [value]; }
    expect(() => StructuredSnapshot.fromMap(snapshotPayload(value: value)), throwsA(isA<FoundationModelsException>()));
    expect(() => SessionEvent.fromMap({'type': 'textSnapshot', 'structuredSnapshot': 7}), throwsA(isA<FoundationModelsException>()));
  });

  group('opt-in guided stream lifecycle', () {
    const channel = MethodChannel('test/structured-snapshots');
    const codec = StandardMethodCodec();
    final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    late CupertinoFoundationModels models;
    late List<MethodCall> calls;
    late Completer<Map<Object?, Object?>> started;
    setUp(() {
      calls = []; started = Completer<Map<Object?, Object?>>();
      models = CupertinoFoundationModels(platform: MethodChannelCupertinoFoundationModels(methodChannel: channel));
      messenger.setMockMethodCallHandler(channel, (call) async {
        calls.add(call);
        if (call.method == 'createSession') return {'sessionId': 'partial', 'mode': 'local'};
        if (call.method == 'startStream') started.complete(call.arguments as Map<Object?, Object?>);
        return null;
      });
    });
    tearDown(() => messenger.setMockMethodCallHandler(channel, null));
    const schema = StructuredSchema.object(name: 'Contact', properties: {'name': SchemaProperty.string(), 'email': SchemaProperty.string()}, propertyOrder: ['name', 'email']);
    const options = GenerationOptions(includeStructuredSnapshots: true);
    Future<void> emit(String request, Map<String, Object?> event) async {
      final reply = Completer<ByteData?>();
      await messenger.handlePlatformMessage(channel.name, codec.encodeMethodCall(MethodCall('streamEvent', {'requestId': request, 'event': event})), reply.complete);
      await reply.future;
    }

    test('snapshots replace state and only completion permits final decoding', () async {
      final session = await models.createSession();
      final events = <SessionEvent>[];
      final completion = Completer<void>();
      final subscription = session.streamStructured(prompt: const Prompt.text('supplied'), schema: schema, options: options)
        .listen(events.add, onDone: completion.complete);
      final request = await started.future;
      expect((request['options']! as Map<Object?, Object?>)['includeStructuredSnapshots'], true);
      expect(request['schema'], schema.toMap());
      final id = request['requestId']! as String;
      await emit(id, {'type': 'textSnapshot', 'text': 'partial', 'structuredSnapshot': snapshotPayload(value: {'name': 'Morgan'}, present: ['#', '#/name'], complete: ['#/name'])});
      await emit(id, {'type': 'textSnapshot', 'text': 'revised', 'structuredSnapshot': snapshotPayload(value: {'name': 'Riley'}, isComplete: true, present: ['#', '#/name'], complete: ['#', '#/name'])});
      expect(events.whereType<CompletionEvent>(), isEmpty);
      expect((events.first as TextSnapshotEvent).structuredSnapshot!.value, {'name': 'Morgan'});
      expect((events.last as TextSnapshotEvent).structuredSnapshot!.value, {'name': 'Riley'});
      await emit(id, {'type': 'completed', 'response': {'text': '{"name":"Riley"}', 'structuredValue': {'name': 'Riley'}, 'termination': {'status': 'completed', 'structuredContentComplete': true}}});
      await completion.future;
      final finalResponse = (events.last as CompletionEvent).response;
      expect(finalResponse.decodeStructured<String>(decoder: (value) => (value! as Map<String, Object?>)['name']! as String).value, 'Riley');
      expect(events.whereType<CompletionEvent>(), hasLength(1));
      await subscription.cancel(); await session.dispose();
    });

    test('malformed snapshot closes with an error and cancels native work once', () async {
      final session = await models.createSession();
      final pending = session.streamStructured(prompt: const Prompt.text('supplied'), schema: schema, options: options).toList();
      final assertion = expectLater(pending, throwsA(isA<FoundationModelsException>().having((error) => error.code, 'code', FoundationModelsErrorCode.parsingFailure)));
      final request = await started.future;
      await emit(request['requestId']! as String, {'type': 'textSnapshot', 'structuredSnapshot': 7});
      await assertion;
      expect(calls.where((call) => call.method == 'cancelActiveRequest'), hasLength(1));
      await session.dispose();
    });

    test('cancelling after partial state cancels the original native stream', () async {
      final session = await models.createSession();
      final seen = Completer<void>();
      final subscription = session.streamStructured(prompt: const Prompt.text('supplied'), schema: schema, options: options).listen((event) { if (!seen.isCompleted) seen.complete(); });
      final request = await started.future;
      await emit(request['requestId']! as String, {'type': 'textSnapshot', 'text': 'partial', 'structuredSnapshot': snapshotPayload()});
      await seen.future; await subscription.cancel();
      expect(calls.where((call) => call.method == 'cancelActiveRequest'), hasLength(1));
      await session.dispose();
    });

    test('failed cancellation after a bad snapshot prevents unsafe session reuse', () async {
      messenger.setMockMethodCallHandler(channel, (call) async {
        calls.add(call);
        if (call.method == 'createSession') return {'sessionId': 'partial', 'mode': 'local'};
        if (call.method == 'startStream') started.complete(call.arguments as Map<Object?, Object?>);
        if (call.method == 'cancelActiveRequest') throw PlatformException(code: 'nativeFailure', message: 'cleanup failed');
        return null;
      });
      final session = await models.createSession();
      final pending = session.streamStructured(prompt: const Prompt.text('supplied'), schema: schema, options: options).toList();
      final assertion = expectLater(pending, throwsA(isA<FoundationModelsException>()));
      final request = await started.future;
      await emit(request['requestId']! as String, {'type': 'textSnapshot', 'structuredSnapshot': 7});
      await assertion;
      await expectLater(session.respond(const Prompt.text('next')), throwsA(isA<FoundationModelsException>().having((error) => error.code, 'code', FoundationModelsErrorCode.invalidRequest)));
      await session.dispose();
    });

    test('snapshot option rejects text-only streams and one-shot calls before admission', () async {
      final session = await models.createSession();
      await expectLater(session.stream(const Prompt.text('supplied'), options: options).toList(), throwsArgumentError);
      await expectLater(session.respond(const Prompt.text('supplied'), options: options), throwsArgumentError);
      await expectLater(session.generateStructured(prompt: const Prompt.text('supplied'), schema: schema, options: options), throwsArgumentError);
      expect(calls.where((call) => call.method != 'createSession'), isEmpty);
      await session.dispose();
    });

    test('invalid order does not cancel an unrelated active stream', () async {
      final session = await models.createSession();
      final subscription = session.streamStructured(prompt: const Prompt.text('supplied'), schema: schema).listen((_) {});
      await started.future;
      await expectLater(session.streamStructured(prompt: const Prompt.text('bad'), schema: const StructuredSchema.object(name: 'Bad', properties: {}, propertyOrder: ['missing'])).toList(), throwsArgumentError);
      expect(calls.where((call) => call.method == 'cancelActiveRequest'), isEmpty);
      await subscription.cancel(); await session.dispose();
    });
  });
}

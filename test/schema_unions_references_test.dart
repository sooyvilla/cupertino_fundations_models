import 'dart:async';

import 'package:cupertino_fundations_models/cupertino_fundations_models.dart';
import 'package:cupertino_fundations_models/src/platform/method_channel_cupertino_foundation_models.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

// ignore: avoid_relative_lib_imports
import '../example/lib/document_extraction.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const nullableText = SchemaProperty.anyOf(alternatives: [SchemaProperty.string(), SchemaProperty.nullValue()]);

  test('null, nullable and anyOf roots retain optional presence independently', () {
    const object = StructuredSchema.object(name: 'Profile', properties: {
      'requiredNullable': nullableText, 'optionalNullable': nullableText,
      'optionalText': SchemaProperty.string(),
    }, requiredProperties: ['requiredNullable']);
    final map = object.toMap();
    expect(map['requiredProperties'], ['requiredNullable']);
    expect(((map['properties']! as Map<String, Object?>)['requiredNullable']! as Map<String, Object?>)['anyOf'], hasLength(2));
    expect(const StructuredSchema.nullValue(name: 'Missing').toMap()['type'], 'null');
    expect(const StructuredSchema.anyOf(name: 'Value', alternatives: [SchemaProperty.integer(), SchemaProperty.number()]).toMap()['anyOf'], hasLength(2));
    expect(const SchemaProperty.anyOf(alternatives: [SchemaProperty.boolean()]).toMap()['anyOf'], hasLength(1));
    expect(const SchemaProperty.reference('Address').toMap()['reference'], 'Address');
  });

  test('manual definitions are reusable in objects, arrays and root aliases', () {
    const address = SchemaProperty.object(properties: {'city': SchemaProperty.string()}, requiredProperties: ['city']);
    const defs = {'Address': address, 'Text': SchemaProperty.string(), 'Flag': SchemaProperty.boolean()};
    const object = StructuredSchema.object(name: 'Contacts', definitions: defs,
      properties: {'home': SchemaProperty.reference('Address'), 'work': SchemaProperty.reference('Address')});
    final wire = object.toMap();
    expect((wire['definitions']! as Map<String, Object?>).keys, ['Address', 'Text', 'Flag']);
    expect(((wire['properties']! as Map<String, Object?>)['work']! as Map<String, Object?>)['reference'], 'Address');
    for (final root in [
      const StructuredSchema.array(name: 'List', items: SchemaProperty.reference('Address'), definitions: defs),
      const StructuredSchema.reference(name: 'Home', reference: 'Address', definitions: defs),
      const StructuredSchema.string(name: 'Label', definitions: defs),
      const StructuredSchema.integer(name: 'Count', definitions: defs),
      const StructuredSchema.number(name: 'Ratio', definitions: defs),
      const StructuredSchema.boolean(name: 'Matches', definitions: defs),
      const StructuredSchema.nullValue(name: 'Empty', definitions: defs),
      const StructuredSchema.anyOf(name: 'Choice', alternatives: [SchemaProperty.reference('Text'), SchemaProperty.nullValue()], definitions: defs),
    ]) {
      expect(root.toMap()['definitions'], isNotNull);
    }
  });

  final invalidProperties = <SchemaProperty>[
    const SchemaProperty.anyOf(alternatives: []),
    SchemaProperty.anyOf(alternatives: List.filled(9, const SchemaProperty.string())),
    const SchemaProperty(type: 'anyOf'),
    const SchemaProperty(type: 'string', alternatives: []),
    const SchemaProperty(type: 'reference'),
    const SchemaProperty(type: 'string', referenceName: 'A'),
    const SchemaProperty.reference(' '),
    const SchemaProperty(type: 'null', properties: {}),
    const SchemaProperty(type: 'anyOf', alternatives: [SchemaProperty.string()], items: SchemaProperty.string()),
  ];
  for (var index = 0; index < invalidProperties.length; index++) {
    test('invalid extended property $index fails before serialization', () {
      expect(invalidProperties[index].toMap, throwsArgumentError);
    });
  }

  test('unknown, recursive, deep and oversized graphs are bounded without harming legacy trees', () {
    expect(const StructuredSchema.reference(name: 'Missing', reference: 'Absent').toMap, throwsArgumentError);
    expect(const StructuredSchema.reference(name: 'Loop', reference: 'A', definitions: {
      'A': SchemaProperty.reference('B'), 'B': SchemaProperty.reference('A'),
    }).toMap, throwsArgumentError);
    final children = <String, SchemaProperty>{};
    final cycle = SchemaProperty.object(properties: children);
    children['self'] = cycle;
    expect(cycle.toMap, throwsArgumentError);
    expect(() => const SchemaProperty.string().toMap(definitions: {' ': const SchemaProperty.string()}), throwsArgumentError);
    expect(() => const SchemaProperty.string().toMap(definitions: {for (var i = 0; i < 33; i++) 'D$i': const SchemaProperty.string()}), throwsArgumentError);
    SchemaProperty deep = const SchemaProperty.nullValue();
    for (var i = 0; i < 17; i++) { deep = SchemaProperty.array(items: deep); }
    expect(deep.toMap, throwsArgumentError);
    final branch = SchemaProperty.object(properties: {for (var i = 0; i < 128; i++) 'f$i': const SchemaProperty.string()});
    final wide = SchemaProperty.anyOf(alternatives: List.filled(4, branch));
    expect(wide.toMap, throwsArgumentError);
    final legacy = SchemaProperty.object(properties: {for (var i = 0; i < 5; i++) 'group$i': branch});
    expect(legacy.toMap()['properties'], hasLength(5));
  });

  test('JSON nullable references and root definitions snapshot all input collections', () {
    final choices = <Object?>[{'type': 'string'}, {'type': 'null'}];
    final definitions = <String, Object?>{'a/b~c': {'anyOf': choices}};
    final root = StructuredSchema.fromJsonSchema({r'$ref': r'#/$defs/a~1b~0c', r'$defs': definitions});
    choices.clear(); definitions.clear();
    expect(root.type, 'reference');
    expect(root.definitions['a/b~c']!.alternatives, hasLength(2));
    expect(root.definitions.clear, throwsUnsupportedError);
    expect(root.definitions['a/b~c']!.alternatives!.clear, throwsUnsupportedError);
    expect(StructuredSchema.fromJsonSchema({'type': 'null'}).type, 'null');
    expect(StructuredSchema.fromJsonSchema({'anyOf': [{'type': 'integer'}, {'type': 'number'}]}).type, 'anyOf');
    final ordered = StructuredSchema.fromJsonSchema({r'$ref': r'#/$defs/Address', r'$defs': {
      'Address': {'type': 'object', 'additionalProperties': false, 'properties': {'city': {'type': 'string'}}},
    }}, propertyOrders: {r'#/$defs/Address': ['city']});
    expect(ordered.definitions['Address']!.propertyOrder, ['city']);
  });

  final badJson = <(Map<String, Object?>, String)>[
    ({'anyOf': []}, '#/anyOf'), ({'anyOf': 7}, '#/anyOf'),
    ({'anyOf': List.filled(9, {'type': 'string'})}, '#/anyOf'),
    ({'anyOf': [true]}, '#/anyOf/0'),
    ({'anyOf': [{'type': 'string'}], 'minimum': 0}, '#/minimum'),
    ({'type': 'string', 'anyOf': [{'type': 'null'}]}, '#/type'),
    ({r'$ref': 7}, r'#/$ref'), ({r'$ref': 'https://example.test/schema'}, r'#/$ref'),
    ({r'$ref': '#'}, r'#/$ref'), ({r'$ref': r'#/$defs/'}, r'#/$ref'),
    ({r'$ref': r'#/$defs/Name/nested'}, r'#/$ref'), ({r'$ref': r'#/$defs/a~2b'}, r'#/$ref'),
    ({r'$ref': r'#/$defs/a%20b'}, r'#/$ref'), ({r'$ref': r'#/$defs/Missing'}, r'#/$ref'),
    ({r'$defs': 7, 'type': 'boolean'}, r'#/$defs'),
    ({r'$defs': {' ': {'type': 'string'}}, 'type': 'boolean'}, r'#/$defs/ '),
    ({r'$defs': {'A': {'type': 'future'}}, 'type': 'boolean'}, r'#/$defs/A/type'),
    ({r'$defs': {for (var i = 0; i < 33; i++) 'D$i': {'type': 'string'}}, 'type': 'boolean'}, r'#/$defs'),
    ({'type': 'array', 'items': {'type': 'boolean', r'$defs': <String, Object?>{}}}, r'#/items/$defs'),
    ({'type': 'object', 'additionalProperties': false, 'properties': {'definitions': {r'$ref': r'#/$defs/No'}}}, r'#/properties/definitions/$ref'),
  ];
  for (var index = 0; index < badJson.length; index++) {
    test('invalid JSON graph $index retains its input pointer', () {
      final (schema, path) = badJson[index];
      expect(() => StructuredSchema.fromJsonSchema(schema), throwsA(isA<FoundationModelsException>()
        .having((error) => error.code, 'code', FoundationModelsErrorCode.invalidRequest)
        .having((error) => error.details['schemaPath'], 'path', path)));
    });
  }
  test('cycles report definition paths without rewriting names as ref keywords', () {
    expect(() => StructuredSchema.fromJsonSchema({r'$ref': r'#/$defs/reference', r'$defs': {
      'reference': {r'$ref': r'#/$defs/reference'},
    }}), throwsA(isA<FoundationModelsException>().having((error) => error.details['schemaPath'], 'path', r'#/$defs/reference')));
  });

  test('explicit final null is present, while legacy missing data is not', () {
    const absent = ModelResponse(text: '', usedMode: ModelMode.local, metadata: {});
    const present = ModelResponse(text: 'null', usedMode: ModelMode.local, metadata: {}, hasStructuredValue: true);
    expect(absent.hasStructuredValue, false);
    expect(() => absent.decodeStructured<Object?>(decoder: (value) => value), throwsA(isA<FoundationModelsException>()));
    expect(present.hasStructuredValue, true);
    const conflicting = ModelResponse(text: '0', usedMode: ModelMode.local, metadata: {}, structuredValue: 0, hasStructuredValue: false);
    expect(() => conflicting.hasStructuredValue, throwsA(isA<FoundationModelsException>()));
    expect(present.decodeStructured<String?>(decoder: (value) => value as String?).value, isNull);
    expect(ModelResponse.fromMap({'text': 'null', 'structuredValue': null}).hasStructuredValue, false);
    expect(ModelResponse.fromMap({'structuredValue': false}).hasStructuredValue, true);
    expect(ModelResponse.fromMap({'hasStructuredValue': false}).hasStructuredValue, false);
    expect(ModelResponse.fromMap({'hasStructuredValue': true, 'structuredValue': null}).hasStructuredValue, true);
    for (final map in <Map<Object?, Object?>>[{'hasStructuredValue': 7}, {'hasStructuredValue': true}, {'hasStructuredValue': false, 'structuredValue': 0}]) {
      expect(() => ModelResponse.fromMap(map), throwsA(isA<FoundationModelsException>()));
    }
  });

  group('null through one-shot and guided completion transport', () {
    const channel = MethodChannel('test/nullable-generation');
    const codec = StandardMethodCodec();
    final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    late List<MethodCall> calls;
    late CupertinoFoundationModels models;
    Map<String, Object?> response() => {'text': 'null', 'hasStructuredValue': true, 'structuredValue': null,
      'metadata': {'request': 'nullable'}, 'termination': {'status': 'completed', 'structuredContentComplete': true}};
    setUp(() {
      calls = [];
      models = CupertinoFoundationModels(platform: MethodChannelCupertinoFoundationModels(methodChannel: channel));
      messenger.setMockMethodCallHandler(channel, (call) async {
        calls.add(call);
        if (call.method == 'createSession') return {'sessionId': 'nullable', 'mode': 'local'};
        if (call.method == 'generateStructured') return response();
        return null;
      });
    });
    tearDown(() => messenger.setMockMethodCallHandler(channel, null));
    const schema = StructuredSchema.anyOf(name: 'Name', alternatives: [SchemaProperty.string(), SchemaProperty.nullValue()]);
    test('nullable decoder sees explicit null and metadata with facade cleanup', () async {
      var invocations = 0;
      final result = await models.generateStructuredDecoded<String?>(prompt: const Prompt.text('No name supplied.'), schema: schema,
        decoder: (value) { invocations++; return value as String?; });
      expect(result.value, isNull); expect(invocations, 1);
      expect(result.response.hasStructuredValue, true); expect(result.response.metadata['request'], 'nullable');
      expect((calls[1].arguments as Map<Object?, Object?>)['schema'], schema.toMap());
      expect(calls.last.method, 'disposeSession');
    });
    test('guided null completion stays separate from an incomplete snapshot', () async {
      final started = Completer<Map<Object?, Object?>>();
      messenger.setMockMethodCallHandler(channel, (call) async {
        calls.add(call);
        if (call.method == 'createSession') return {'sessionId': 'nullable', 'mode': 'local'};
        if (call.method == 'startStream') started.complete(call.arguments as Map<Object?, Object?>);
        return null;
      });
      final session = await models.createSession();
      final pending = session.streamStructured(prompt: const Prompt.text('No name supplied.'), schema: schema).toList();
      final request = await started.future;
      final reply = Completer<ByteData?>();
      await messenger.handlePlatformMessage(channel.name, codec.encodeMethodCall(MethodCall('streamEvent', {
        'requestId': request['requestId'], 'event': {'type': 'completed', 'response': response()},
      })), reply.complete);
      await reply.future;
      final finalResponse = ((await pending).single as CompletionEvent).response;
      expect(finalResponse.decodeStructured<String?>(decoder: (value) => value as String?).value, isNull);
      await session.dispose();
    });
    test('undefined refs fail before native work and do not occupy the session', () async {
      final session = await models.createSession();
      await expectLater(session.generateStructured(prompt: const Prompt.text('supplied'), schema: const StructuredSchema.reference(name: 'Missing', reference: 'A')), throwsArgumentError);
      expect(calls.where((call) => call.method == 'generateStructured'), isEmpty);
      expect((await session.generateStructured(prompt: const Prompt.text('none'), schema: schema)).hasStructuredValue, true);
      await session.dispose();
    });
    test('document null-date mode is explicit and default omission remains unchanged', () async {
      final ordinary = documentSchema.definitions['DocumentRow']!;
      final nullable = nullableDocumentSchema.definitions['DocumentRow']!;
      expect(ordinary.requiredProperties, isNot(contains('dateText')));
      expect(nullable.requiredProperties, contains('dateText'));
      expect(nullable.properties!['dateText']!.alternatives!.last.type, 'null');
      messenger.setMockMethodCallHandler(channel, (call) async {
        calls.add(call);
        if (call.method == 'createSession') return {'sessionId': 'nullable', 'mode': 'local'};
        if (call.method == 'generateStructured') { return {'text': '{"currency":"EUR","rows":[]}', 'hasStructuredValue': true,
          'structuredValue': {'currency': 'EUR', 'rows': [{'sourceRow': 1, 'dateText': null, 'description': 'Material', 'amountText': '-3,50'}]}}; }
        return null;
      });
      final result = await extractDocumentDecoded(models: models, document: '1 Material -3,50', explicitNullDates: true);
      expect(result.value.rows.single.dateText, isNull);
      final raw = result.response.structuredValue! as Map<String, Object?>;
      expect(((raw['rows']! as List<Object?>).single! as Map<String, Object?>).containsKey('dateText'), true);
      expect((calls[1].arguments as Map<Object?, Object?>)['schema'], nullableDocumentSchema.toMap());
    });
  });
}

import 'dart:async';
import 'dart:convert';

import 'package:cupertino_fundations_models/cupertino_fundations_models.dart';
import 'package:cupertino_fundations_models/src/platform/method_channel_cupertino_foundation_models.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const contactsSchema = StructuredSchema.array(
  name: 'Contacts',
  description: 'Contacts explicitly supplied in the text.',
  minItems: 0,
  maxItems: 10,
  items: SchemaProperty.object(
    requiredProperties: ['name'],
    properties: {
      'name': SchemaProperty.string(),
      'email': SchemaProperty.string(),
      'address': SchemaProperty.object(
        requiredProperties: [],
        properties: {'city': SchemaProperty.string()},
      ),
    },
  ),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('contact list roots retain item shape, optional fields and bounds', () {
    final map = contactsSchema.toMap();
    expect(contactsSchema.type, 'array');
    expect(contactsSchema.properties, isEmpty);
    expect(contactsSchema.requiredProperties, isEmpty);
    expect(map['name'], 'Contacts');
    expect(map['description'], contactsSchema.description);
    expect(map['minItems'], 0);
    expect(map['maxItems'], 10);
    expect(map.containsKey('requiredProperties'), isFalse);
    final item = map['items']! as Map<String, Object?>;
    expect(item['requiredProperties'], ['name']);
    final fields = item['properties']! as Map<String, Object?>;
    expect((fields['address']! as Map<String, Object?>)['requiredProperties'], isEmpty);
  });

  test('object defaults preserve root optional and nested required behavior', () {
    const old = StructuredSchema.object(name: 'Legacy', properties: {
      'contact': SchemaProperty.object(properties: {'name': SchemaProperty.string()}),
    });
    final map = old.toMap();
    expect(old.type, 'object');
    expect(map['requiredProperties'], isEmpty);
    final nested = (map['properties']! as Map<String, Object?>)['contact']! as Map<String, Object?>;
    expect(nested.containsKey('requiredProperties'), isFalse);
    expect(const SchemaProperty.object(properties: {}).requiredProperties, isNull);
  });

  test('scalar roots reuse F01 constraints and keep the declared type', () {
    final schemas = <StructuredSchema>[
      const StructuredSchema.string(name: 'Category', description: 'Label', enumValues: ['work', 'other'], pattern: r'^[a-z]+$'),
      const StructuredSchema.integer(name: 'Rating', minimum: 1, maximum: 5),
      const StructuredSchema.number(name: 'Ratio', minimum: 0, maximum: 1),
      const StructuredSchema.boolean(name: 'Matches'),
      const StructuredSchema.array(name: 'Actions', items: SchemaProperty.string(), exactItems: 3),
    ];
    expect(schemas.map((value) => value.type), ['string', 'integer', 'number', 'boolean', 'array']);
    expect(schemas[0].toMap()['pattern'], r'^[a-z]+$');
    expect(schemas[0].toMap()['enumValues'], ['work', 'other']);
    expect(schemas[1].toMap()['maximum'], 5);
    expect(schemas[2].toMap()['minimum'], 0);
    expect(schemas[3].toMap()['type'], 'boolean');
    expect(schemas[4].toMap()['maxItems'], 3);
  });

  test('runtime root constructors support user-selected definitions', () {
    final label = ['Feedback'].single;
    for (final schema in [
      StructuredSchema.array(name: label, items: const SchemaProperty.string(), minItems: 0),
      StructuredSchema.string(name: label),
      StructuredSchema.integer(name: label),
      StructuredSchema.number(name: label),
      StructuredSchema.boolean(name: label),
    ]) {
      expect(schema.toMap()['name'], label);
    }
  });

  for (final entry in <String, SchemaProperty>{
    'duplicate nested names': const SchemaProperty.object(properties: {'name': SchemaProperty.string()}, requiredProperties: ['name', 'name']),
    'undeclared nested field': const SchemaProperty.object(properties: {'name': SchemaProperty.string()}, requiredProperties: ['email']),
    'missing object properties': const SchemaProperty(type: 'object', requiredProperties: ['name']),
    'required list on a scalar': const SchemaProperty(type: 'string', requiredProperties: []),
    'invalid deeper child': const SchemaProperty.array(items: SchemaProperty.object(properties: {}, requiredProperties: ['missing'])),
  }.entries) {
    test('rejects ${entry.key} without admitting native work', () {
      expect(entry.value.toMap, throwsArgumentError);
    });
  }

  test('additional roots reject invalid bounds through the shared contract', () {
    for (final schema in <StructuredSchema>[
      const StructuredSchema.array(name: 'Bad', items: SchemaProperty.string(), exactItems: -1),
      const StructuredSchema.integer(name: 'Bad', minimum: 5, maximum: 1),
      const StructuredSchema.number(name: 'Bad', maximum: double.nan),
    ]) {
      expect(schema.toMap, throwsArgumentError);
    }
  });

  group('root values across the application transport', () {
    const channel = MethodChannel('test/output-roots');
    const codec = StandardMethodCodec();
    final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    late CupertinoFoundationModels models;
    late List<MethodCall> calls;
    late Object result;

    setUp(() {
      calls = [];
      result = false;
      models = CupertinoFoundationModels(platform: MethodChannelCupertinoFoundationModels(methodChannel: channel));
      messenger.setMockMethodCallHandler(channel, (call) async {
        calls.add(call);
        if (call.method == 'createSession') return {'sessionId': 'roots', 'mode': 'local'};
        if (call.method == 'generateStructured') return {'text': jsonEncode(result), 'structuredValue': result, 'usedMode': 'local'};
        return null;
      });
    });
    tearDown(() => messenger.setMockMethodCallHandler(channel, null));

    final cases = <(String, StructuredSchema, Object)>[
      ('boolean false', const StructuredSchema.boolean(name: 'Match'), false),
      ('integer zero', const StructuredSchema.integer(name: 'Count'), 0),
      ('decimal zero', const StructuredSchema.number(name: 'Ratio'), 0.0),
      ('empty string', const StructuredSchema.string(name: 'Text'), ''),
      ('empty array', contactsSchema, <Object?>[]),
      ('contacts without optional fields', contactsSchema, <Object?>[{'name': 'Morgan'}]),
    ];
    for (final (label, schema, value) in cases) {
      test('one-shot preserves $label and releases its session', () async {
        result = value;
        final response = await models.generateStructured(prompt: const Prompt.text('supplied content'), schema: schema);
        expect(response.structuredValue, value);
        expect(response.text, jsonEncode(value));
        expect(response.structuredValue, isNotNull);
        expect(calls.map((call) => call.method), ['createSession', 'generateStructured', 'disposeSession']);
        expect((calls[1].arguments as Map<Object?, Object?>)['schema'], schema.toMap());
      });
    }

    for (final (label, schema, value) in cases) {
      test('guided streaming preserves final $label', () async {
        final started = Completer<Map<Object?, Object?>>();
        messenger.setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          if (call.method == 'createSession') return {'sessionId': 'roots', 'mode': 'local'};
          if (call.method == 'startStream') started.complete(call.arguments as Map<Object?, Object?>);
          return null;
        });
        final session = await models.createSession();
        final pending = session.streamStructured(prompt: const Prompt.text('supplied content'), schema: schema).toList();
        final request = await started.future;
        expect(request['schema'], schema.toMap());
        final reply = Completer<ByteData?>();
        await messenger.handlePlatformMessage(channel.name, codec.encodeMethodCall(MethodCall('streamEvent', {
          'requestId': request['requestId'],
          'event': {'type': 'completed', 'requestId': request['requestId'], 'response': {'text': jsonEncode(value), 'structuredValue': value}},
        })), reply.complete);
        await reply.future;
        final event = (await pending).single as CompletionEvent;
        expect(event.response.structuredValue, value);
        expect(event.response.structuredValue, isNotNull);
        await session.dispose();
      });
    }

    test('root arrays and nested required choices also reach token measurement', () async {
      final session = await models.createSession();
      await session.measureTokenBudget(prompt: const Prompt.text('supplied content'), schema: contactsSchema);
      expect((calls.last.arguments as Map<Object?, Object?>)['schema'], contactsSchema.toMap());
      await expectLater(session.generateStructured(prompt: const Prompt.text('supplied content'), schema: const StructuredSchema.array(
        name: 'BadContacts', items: SchemaProperty.object(properties: {}, requiredProperties: ['name']),
      )), throwsArgumentError);
      expect(calls.where((call) => call.method == 'generateStructured'), isEmpty);
      await session.dispose();
    });
  });
}

import 'dart:async';

import 'package:cupertino_fundations_models/cupertino_fundations_models.dart';
import 'package:cupertino_fundations_models/src/platform/method_channel_cupertino_foundation_models.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const feedbackSchema = StructuredSchema.object(
  name: 'SupportTriage',
  requiredProperties: ['severity', 'ticket', 'actions'],
  properties: {
    'severity': SchemaProperty.integer(minimum: 1, maximum: 5),
    'ticket': SchemaProperty.string(pattern: r'^SUP-[0-9]{4}$'),
    'confidence': SchemaProperty.number(minimum: 0, maximum: 1),
    'actions': SchemaProperty.array(
      items: SchemaProperty.string(),
      exactItems: 3,
    ),
  },
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('triage definitions express a rating, identifier and three actions', () {
    final fields = feedbackSchema.toMap()['properties']! as Map<String, Object?>;
    final rating = fields['severity']! as Map<String, Object?>;
    expect(rating['minimum'], 1);
    expect(rating['maximum'], 5);
    expect((fields['ticket']! as Map<String, Object?>)['pattern'], r'^SUP-[0-9]{4}$');
    final actions = fields['actions']! as Map<String, Object?>;
    expect(actions['minItems'], 3);
    expect(actions['maxItems'], 3);
    expect(actions.containsKey('exactItems'), isFalse);
    expect(feedbackSchema.toMap()['requiredProperties'], ['severity', 'ticket', 'actions']);
  });

  test('invoice line items retain constraints at every nesting level', () {
    const schema = StructuredSchema.object(
      name: 'Invoice',
      properties: {
        'lines': SchemaProperty.array(
          minItems: 1,
          maxItems: 20,
          items: SchemaProperty.object(
            properties: {
              'quantity': SchemaProperty.integer(minimum: 1),
              'price': SchemaProperty.number(minimum: 0, maximum: 10000.5),
            },
          ),
        ),
      },
    );
    final fields = schema.toMap()['properties']! as Map<String, Object?>;
    final lines = fields['lines']! as Map<String, Object?>;
    final item = lines['items']! as Map<String, Object?>;
    final itemFields = item['properties']! as Map<String, Object?>;
    expect(lines['minItems'], 1);
    expect(lines['maxItems'], 20);
    expect((itemFields['quantity']! as Map<String, Object?>)['minimum'], 1);
    expect((itemFields['price']! as Map<String, Object?>)['maximum'], 10000.5);
  });

  test('unbounded schemas keep their previous channel representation', () {
    expect(const SchemaProperty.string().toMap(), {
      'type': 'string', 'description': null, 'enumValues': null,
      'items': null, 'properties': null,
    });
    expect(const SchemaProperty.integer().toMap()['minimum'], isNull);
    expect(const SchemaProperty.number().toMap().containsKey('maximum'), isFalse);
    expect(const SchemaProperty.array(items: SchemaProperty.boolean()).toMap().containsKey('minItems'), isFalse);
    expect(const SchemaProperty(type: 'custom').toMap()['type'], 'custom');
  });

  test('one-sided and equal bounds allow zero, negatives and empty arrays', () {
    for (final property in [
      const SchemaProperty.integer(minimum: -5),
      const SchemaProperty.integer(maximum: 0),
      const SchemaProperty.integer(minimum: 0, maximum: 0),
      const SchemaProperty.number(minimum: -0.25),
      const SchemaProperty.number(maximum: 0.75),
      const SchemaProperty.number(minimum: 0.5, maximum: 0.5),
      const SchemaProperty.array(items: SchemaProperty.string(), minItems: 0),
      const SchemaProperty.array(items: SchemaProperty.string(), maxItems: 0),
      const SchemaProperty.array(items: SchemaProperty.string(), exactItems: 0),
      const SchemaProperty.string(enumValues: ['a', 'b'], pattern: r'^[ab]$'),
      const SchemaProperty(type: 'INTEGER', minimum: 1.0, maximum: 2),
    ]) {
      expect(property.toMap, returnsNormally);
    }
    final empty = const SchemaProperty.array(items: SchemaProperty.string(), exactItems: 0).toMap();
    expect(empty['minItems'], 0);
    expect(empty['maxItems'], 0);
  });

  final invalidProperties = <String, SchemaProperty>{
    'inverted integer rating': const SchemaProperty.integer(minimum: 5, maximum: 1),
    'inverted decimal confidence': const SchemaProperty.number(minimum: 1, maximum: 0),
    'non-finite minimum': const SchemaProperty.number(minimum: double.nan),
    'non-finite maximum': const SchemaProperty.number(maximum: double.infinity),
    'negative infinity': const SchemaProperty.number(minimum: double.negativeInfinity),
    'fractional integer minimum': const SchemaProperty(type: 'integer', minimum: 1.5),
    'fractional integer maximum': const SchemaProperty(type: 'integer', maximum: 1.5),
    'numeric bounds on a string': const SchemaProperty(type: 'string', minimum: 1),
    'maximum on a boolean': const SchemaProperty(type: 'boolean', maximum: 1),
    'pattern on an integer': const SchemaProperty(type: 'integer', pattern: '[0-9]'),
    'count on a string': const SchemaProperty(type: 'string', minItems: 1),
    'maximum count on an integer': const SchemaProperty(type: 'integer', maxItems: 1),
    'exact count on an object': const SchemaProperty(type: 'object', exactItems: 1),
    'negative minimum count': const SchemaProperty.array(items: SchemaProperty.string(), minItems: -1),
    'negative maximum count': const SchemaProperty.array(items: SchemaProperty.string(), maxItems: -1),
    'negative exact count': const SchemaProperty.array(items: SchemaProperty.string(), exactItems: -1),
    'inverted item range': const SchemaProperty.array(items: SchemaProperty.string(), minItems: 3, maxItems: 1),
    'exact with minimum': const SchemaProperty.array(items: SchemaProperty.string(), exactItems: 3, minItems: 3),
    'exact with maximum': const SchemaProperty.array(items: SchemaProperty.string(), exactItems: 3, maxItems: 3),
    'invalid nested quantity': const SchemaProperty.object(properties: {
      'quantity': SchemaProperty.integer(minimum: 2, maximum: 1),
    }),
  };
  for (final entry in invalidProperties.entries) {
    test('rejects ${entry.key} without relying on asserts', () {
      expect(entry.value.toMap, throwsArgumentError);
    });
  }

  test('Swift regex syntax is sent unchanged for native validation', () {
    expect(const SchemaProperty.string(pattern: '[').toMap()['pattern'], '[');
    expect(const SchemaProperty.string(pattern: '').toMap()['pattern'], '');
  });

  test('manual number guides reject integer bounds that native Double would round', () {
    // ignore: avoid_js_rounded_ints
    // ignore: avoid_js_rounded_ints
    for (final value in [9007199254740993, -9007199254740993, 9223372036854775807]) {
      expect(SchemaProperty.number(minimum: value).toMap, throwsArgumentError);
      expect(SchemaProperty.number(maximum: value).toMap, throwsArgumentError);
      expect(StructuredSchema.number(name: 'Bound', minimum: value).toMap, throwsArgumentError);
      expect(SchemaProperty.object(properties: {'value': SchemaProperty.number(maximum: value)}).toMap, throwsArgumentError);
    }
    for (final value in [9007199254740992, 9007199254740994, -9223372036854775808]) {
      expect(SchemaProperty.number(minimum: value).toMap()['minimum'], value);
      expect(StructuredSchema.number(name: 'Bound', maximum: value).toMap()['maximum'], value);
    }
    expect(const SchemaProperty.number(minimum: 9223372036854775808.0).toMap()['minimum'], 9223372036854775808.0);
    expect(const SchemaProperty.integer(maximum: 9223372036854775807).toMap()['maximum'], 9223372036854775807);
  });

  group('constrained application requests', () {
    const channel = MethodChannel('test/constraints');
    final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    late CupertinoFoundationModels models;
    late List<MethodCall> calls;

    setUp(() {
      calls = [];
      models = CupertinoFoundationModels(
        platform: MethodChannelCupertinoFoundationModels(methodChannel: channel),
      );
      messenger.setMockMethodCallHandler(channel, (call) async {
        calls.add(call);
        if (call.method == 'createSession') {
          return {'sessionId': 'triage', 'mode': 'local'};
        }
        if (call.method == 'generateStructured') {
          return {
            'text': '{"severity":3,"ticket":"SUP-1234","actions":["inspect","reproduce","repair"]}',
            'structuredValue': {'severity': 3, 'ticket': 'SUP-1234', 'actions': ['inspect', 'reproduce', 'repair']},
            'usedMode': 'local',
            'usage': {'outputTokenCount': 32},
          };
        }
        return null;
      });
    });
    tearDown(() => messenger.setMockMethodCallHandler(channel, null));

    test('one-shot triage forwards constraints, retains metadata and disposes', () async {
      final result = await models.generateStructured(
        prompt: const Prompt.text('SUP-1234: the login button does nothing.'),
        schema: feedbackSchema,
      );
      expect((result.structuredValue! as Map<String, Object?>)['severity'], 3);
      expect(result.usage!.outputTokenCount, 32);
      expect(result.usedMode, ModelMode.local);
      expect(calls.map((call) => call.method), ['createSession', 'generateStructured', 'disposeSession']);
      final request = calls[1].arguments as Map<Object?, Object?>;
      final schema = request['schema']! as Map<Object?, Object?>;
      final fields = schema['properties']! as Map<Object?, Object?>;
      expect((fields['severity']! as Map<Object?, Object?>)['maximum'], 5);
      expect((fields['ticket']! as Map<Object?, Object?>)['pattern'], r'^SUP-[0-9]{4}$');
      expect((fields['actions']! as Map<Object?, Object?>)['maxItems'], 3);
      expect((calls[0].arguments as Map<Object?, Object?>)['cloudPolicy'], 'never');
    });

    test('invalid constraints release one-shot sessions without inference', () async {
      await expectLater(models.generateStructured(
        prompt: const Prompt.text('triage'),
        schema: const StructuredSchema.object(name: 'Bad', properties: {
          'rating': SchemaProperty.integer(minimum: 5, maximum: 1),
        }),
      ), throwsArgumentError);
      expect(calls.map((call) => call.method), ['createSession', 'disposeSession']);
    });

    test('invalid stream constraints do not cancel or poison an idle session', () async {
      final session = await models.createSession();
      await expectLater(session.streamStructured(
        prompt: const Prompt.text('triage'),
        schema: const StructuredSchema.object(name: 'Bad', properties: {
          'actions': SchemaProperty.array(items: SchemaProperty.string(), exactItems: -1),
        }),
      ), emitsError(isA<ArgumentError>()));
      expect(calls.map((call) => call.method), ['createSession']);
      expect((await session.generateStructured(prompt: const Prompt.text('triage'), schema: feedbackSchema)).usedMode, ModelMode.local);
      await session.dispose();
    });

    test('guided streams forward constraints and expose data only at completion', () async {
      final started = Completer<Map<Object?, Object?>>();
      messenger.setMockMethodCallHandler(channel, (call) async {
        calls.add(call);
        if (call.method == 'createSession') return {'sessionId': 'triage', 'mode': 'local'};
        if (call.method == 'startStream') started.complete(call.arguments as Map<Object?, Object?>);
        return null;
      });
      final session = await models.createSession();
      final pending = session.streamStructured(
        prompt: const Prompt.text('SUP-1234: the login button does nothing.'),
        schema: feedbackSchema,
      ).toList();
      final request = await started.future;
      final fields = (request['schema']! as Map<Object?, Object?>)['properties']! as Map<Object?, Object?>;
      expect((fields['severity']! as Map<Object?, Object?>)['minimum'], 1);
      expect((fields['actions']! as Map<Object?, Object?>)['minItems'], 3);
      const codec = StandardMethodCodec();
      Future<void> emit(Map<String, Object?> event) async {
        final reply = Completer<ByteData?>();
        await messenger.handlePlatformMessage(channel.name, codec.encodeMethodCall(MethodCall('streamEvent', {
          'requestId': request['requestId'], 'event': event,
        })), reply.complete);
        await reply.future;
      }
      await emit({'type': 'textSnapshot', 'requestId': request['requestId'], 'text': '{"severity":'});
      await emit({'type': 'completed', 'requestId': request['requestId'], 'response': {
        'text': '{"severity":3,"actions":["inspect","reproduce","repair"]}',
        'structuredValue': {'severity': 3, 'actions': ['inspect', 'reproduce', 'repair']},
      }});
      final events = await pending;
      expect((events.first as TextSnapshotEvent).text, '{"severity":');
      expect((events.last as CompletionEvent).response.structuredValue, {
        'severity': 3, 'actions': ['inspect', 'reproduce', 'repair'],
      });
      await session.dispose();
    });

    test('token-budget requests carry the same constraints and reject bad definitions', () async {
      final session = await models.createSession();
      await expectLater(session.measureTokenBudget(
        prompt: const Prompt.text('triage'),
        schema: const StructuredSchema.object(name: 'Bad', properties: {
          'confidence': SchemaProperty.number(minimum: 1, maximum: 0),
        }),
      ), throwsArgumentError);
      expect(calls.map((call) => call.method), ['createSession']);
      await session.measureTokenBudget(prompt: const Prompt.text('triage'), schema: feedbackSchema);
      final fields = ((calls.last.arguments as Map<Object?, Object?>)['schema']! as Map<Object?, Object?>)['properties']! as Map<Object?, Object?>;
      expect((fields['confidence']! as Map<Object?, Object?>)['minimum'], 0);
      expect((fields['confidence']! as Map<Object?, Object?>)['maximum'], 1);
      await session.dispose();
    });

    test('native invalid regex errors retain a recoverable field path', () async {
      messenger.setMockMethodCallHandler(channel, (call) async {
        calls.add(call);
        if (call.method == 'createSession') return {'sessionId': 'triage', 'mode': 'local'};
        if (call.method == 'generateStructured') {
          throw PlatformException(code: 'invalidRequest', message: 'Invalid Swift pattern', details: {
            'schemaPath': '#/properties/ticket/pattern',
          });
        }
        return null;
      });
      await expectLater(models.generateStructured(
        prompt: const Prompt.text('triage'),
        schema: const StructuredSchema.object(name: 'BadPattern', properties: {
          'ticket': SchemaProperty.string(pattern: '['),
        }),
      ), throwsA(isA<FoundationModelsException>().having((error) => error.details['schemaPath'], 'field path', '#/properties/ticket/pattern')));
      expect(calls.last.method, 'disposeSession');
    });
  });
}

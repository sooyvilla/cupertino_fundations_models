import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:cupertino_fundations_models/cupertino_fundations_models.dart';
import 'package:cupertino_fundations_models/src/platform/method_channel_cupertino_foundation_models.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

// ignore: avoid_relative_lib_imports
import '../example/lib/document_extraction.dart';

Map<String, Object?> closedObject({Map<String, Object?>? properties, Object? required}) => {
  'type': 'object',
  'additionalProperties': false,
  'properties': ?properties,
  'required': ?required,
};

Object? compact(Object? value) {
  if (value is Map<String, Object?>) { return {
    for (final entry in value.entries) if (entry.value != null) entry.key: compact(entry.value),
  }; }
  if (value is List<Object?>) return value.map(compact).toList();
  return value;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  Matcher failsAt(String path) => throwsA(isA<FoundationModelsException>()
      .having((error) => error.code, 'code', FoundationModelsErrorCode.invalidRequest)
      .having((error) => error.details['schemaPath'], 'input path', path));

  test('existing contact schemas normalize to the shared native contract', () {
    final input = jsonDecode(File('test/fixtures/import_closed_contacts.json').readAsStringSync()) as Map<String, Object?>;
    final expected = jsonDecode(File('test/fixtures/import_closed_contacts.native.json').readAsStringSync());
    final schema = StructuredSchema.fromJsonSchema(input);
    expect(schema.name, 'Contacts');
    expect(schema.type, 'array');
    expect(compact(schema.toMap()), expected);
  });

  test('document example preserves bounded rows and optional dates after import', () {
    final wire = documentSchema.toMap();
    expect(wire['name'], 'DocumentRows');
    expect(wire['requiredProperties'], ['currency', 'rows']);
    final fields = wire['properties']! as Map<String, Object?>;
    expect((fields['currency']! as Map<String, Object?>)['pattern'], r'^(?:[A-Z]{3}|unknown)$');
    final rows = fields['rows']! as Map<String, Object?>;
    expect(rows['maxItems'], 50);
    final reference = rows['items']! as Map<String, Object?>;
    final item = (wire['definitions']! as Map<String, Object?>)[reference['reference']]! as Map<String, Object?>;
    expect(item['requiredProperties'], ['sourceRow', 'description', 'amountText']);
    expect(((item['properties']! as Map<String, Object?>)['sourceRow']! as Map<String, Object?>)['minimum'], 1);
  });

  test('omitted JSON required means none at every level, unlike manual legacy', () {
    final schema = StructuredSchema.fromJsonSchema(closedObject(properties: {
      'contact': closedObject(properties: {'name': {'type': 'string'}}),
    }));
    expect(schema.requiredProperties, isEmpty);
    expect(schema.properties['contact']!.requiredProperties, isEmpty);
    expect(const SchemaProperty.object(properties: {}).requiredProperties, isNull);
  });

  test('all root types reuse manual constraints and naming', () {
    final schemas = <Map<String, Object?>>[
      closedObject(),
      {'type': 'array', 'items': {'type': 'boolean'}, 'minItems': 0.0, 'maxItems': 3},
      {'type': 'string', 'title': 'Label', 'description': 'Category', 'enum': ['work', 'other']},
      {'type': 'integer', 'minimum': -2.0, 'maximum': 5},
      {'type': 'number', 'minimum': -0.25, 'maximum': 0.75},
      {'type': 'boolean', 'title': ''},
    ];
    for (final input in schemas) {
      final result = StructuredSchema.fromJsonSchema(input);
      expect(result.type, input['type']);
      expect(result.toMap()['type'], input['type']);
    }
    expect(StructuredSchema.fromJsonSchema(schemas[2]).name, 'Label');
    expect(StructuredSchema.fromJsonSchema(schemas[2], name: 'Override').name, 'Override');
    expect(StructuredSchema.fromJsonSchema(schemas[5]).name, 'Output');
    expect(() => StructuredSchema.fromJsonSchema(schemas[5], name: ' '), failsAt('#'));
    expect(StructuredSchema.fromJsonSchema({'type': 'integer', 'minimum': -9223372036854775808.0}).toMap()['minimum'], -9223372036854775808);
  });

  test('native Swift regex requires explicit opt-in and remains native-validated', () {
    const input = {'type': 'string', 'pattern': r'^SUP-[0-9]{4}$'};
    expect(() => StructuredSchema.fromJsonSchema(input), failsAt('#/pattern'));
    expect(StructuredSchema.fromJsonSchema(input, allowSwiftPatterns: true).toMap()['pattern'], input['pattern']);
    expect(StructuredSchema.fromJsonSchema({'type': 'string', 'pattern': '['}, allowSwiftPatterns: true).toMap()['pattern'], '[');
  });

  test('import snapshots caller data instead of retaining mutable schema collections', () {
    final values = <Object?>['a', 'b'];
    final fields = <String, Object?>{'label': {'type': 'string', 'enum': values}};
    final required = <Object?>['label'];
    final input = closedObject(properties: fields, required: required);
    final parsed = StructuredSchema.fromJsonSchema(input);
    fields.clear(); values.clear(); required.clear(); input.clear();
    expect(parsed.properties['label']!.enumValues, ['a', 'b']);
    expect(parsed.requiredProperties, ['label']);
    expect(parsed.properties.clear, throwsUnsupportedError);
    expect(parsed.requiredProperties.clear, throwsUnsupportedError);
    expect(parsed.properties['label']!.enumValues!.clear, throwsUnsupportedError);
  });

  test('boundary definitions retain inclusive and one-sided limits', () {
    final cases = <Map<String, Object?>>[
      {'type': 'integer'},
      {'type': 'number'},
      {'type': 'integer', 'minimum': -9223372036854775808, 'maximum': 9223372036854775807},
      {'type': 'integer', 'maximum': 0.0},
      {'type': 'number', 'maximum': 0.5},
      {'type': 'number', 'minimum': -0.25},
      {'type': 'number', 'minimum': 0.5, 'maximum': 0.5},
      {'type': 'number', 'maximum': 9007199254740992},
      {'type': 'array', 'items': {'type': 'string'}, 'minItems': 0, 'maxItems': 0},
    ];
    for (final input in cases) {
      final wire = StructuredSchema.fromJsonSchema(input).toMap();
      for (final key in ['minimum', 'maximum', 'minItems', 'maxItems']) {
        if (input.containsKey(key)) expect(wire[key], input[key]);
      }
    }
    var depth = <String, Object?>{'type': 'string'};
    for (var index = 0; index < 16; index++) {
      depth = {'type': 'array', 'items': depth};
    }
    expect(StructuredSchema.fromJsonSchema(depth).toMap()['type'], 'array');
    final wide = closedObject(properties: {for (var i = 0; i < 128; i++) 'field$i': {'type': 'boolean'}});
    expect(StructuredSchema.fromJsonSchema(wide).properties, hasLength(128));
  });

  final bad = <(String, Map<String, Object?>, String)>[
    ('missing type', {}, '#/type'),
    ('type union', {'type': ['string', 'null']}, '#/type'),
    ('constraint on null type', {'type': 'null', 'minimum': 1}, '#/minimum'),
    ('unknown type', {'type': 'future'}, '#/type'),
    ('wrong title', {'type': 'string', 'title': 7}, '#/title'),
    ('null description', {'type': 'string', 'description': null}, '#/description'),
    ('foreign dialect', {'type': 'string', r'$schema': 'http://json-schema.org/draft-07/schema#'}, r'#/$schema'),
    ('nested dialect', {'type': 'array', 'items': {'type': 'string', r'$schema': 'https://json-schema.org/draft/2020-12/schema'}}, r'#/items/$schema'),
    ('keyword on wrong type', {'type': 'boolean', 'minimum': 0}, '#/minimum'),
    ('open omitted object', {'type': 'object'}, '#/additionalProperties'),
    ('open true object', {'type': 'object', 'additionalProperties': true}, '#/additionalProperties'),
    ('additional property schema', {'type': 'object', 'additionalProperties': {'type': 'string'}}, '#/additionalProperties'),
    ('invalid properties collection', {'type': 'object', 'additionalProperties': false, 'properties': 7}, '#/properties'),
    ('non-string property keys', closedObject(properties: {'nested': {'type': 'object', 'additionalProperties': false, 'properties': {7: {'type': 'string'}}}}), '#/properties/nested/properties'),
    ('blank property', closedObject(properties: {' ': {'type': 'string'}}), '#/properties/ '),
    ('boolean property schema', closedObject(properties: {'name': true}), '#/properties/name'),
    ('nested open object', closedObject(properties: {'address': {'type': 'object'}}), '#/properties/address/additionalProperties'),
    ('missing items', {'type': 'array'}, '#/items'),
    ('tuple items', {'type': 'array', 'items': [{'type': 'string'}]}, '#/items'),
    ('invalid required list', closedObject(required: 7), '#/required'),
    ('non-string required', closedObject(required: [7]), '#/required/0'),
    ('duplicate required', closedObject(properties: {'name': {'type': 'string'}}, required: ['name', 'name']), '#/required/1'),
    ('undeclared required', closedObject(required: ['missing']), '#/required/0'),
    ('empty enum', {'type': 'string', 'enum': []}, '#/enum'),
    ('wrong enum list', {'type': 'string', 'enum': 'a'}, '#/enum'),
    ('mixed enum', {'type': 'string', 'enum': ['a', 7]}, '#/enum/1'),
    ('duplicate enum', {'type': 'string', 'enum': ['a', 'a']}, '#/enum/1'),
    ('wrong pattern', {'type': 'string', 'pattern': 7}, '#/pattern'),
    ('fractional integer bound', {'type': 'integer', 'minimum': 1.5}, '#/minimum'),
    ('integer overflow', {'type': 'integer', 'maximum': 9223372036854775808.0}, '#/maximum'),
    ('integer underflow', {'type': 'integer', 'minimum': -18446744073709551616.0}, '#/minimum'),
    ('inverted integer range', {'type': 'integer', 'minimum': 5, 'maximum': 1}, '#/minimum'),
    ('inverted numeric range', {'type': 'number', 'minimum': 1, 'maximum': 0}, '#/minimum'),
    ('boolean numeric bound', {'type': 'number', 'minimum': true}, '#/minimum'),
    ('string numeric bound', {'type': 'number', 'maximum': '1'}, '#/maximum'),
    ('NaN bound', {'type': 'number', 'minimum': double.nan}, '#/minimum'),
    ('infinite bound', {'type': 'number', 'maximum': double.infinity}, '#/maximum'),
    // ignore: avoid_js_rounded_ints
    ('rounded number integer bound', {'type': 'number', 'maximum': 9007199254740993}, '#/maximum'),
    ('rounded largest integer number bound', {'type': 'number', 'maximum': 9223372036854775807}, '#/maximum'),
    ('negative minItems', {'type': 'array', 'items': {'type': 'string'}, 'minItems': -1}, '#/minItems'),
    ('negative maxItems', {'type': 'array', 'items': {'type': 'string'}, 'maxItems': -1}, '#/maxItems'),
    ('fractional item count', {'type': 'array', 'items': {'type': 'string'}, 'maxItems': 0.5}, '#/maxItems'),
    ('inverted counts', {'type': 'array', 'items': {'type': 'string'}, 'minItems': 3, 'maxItems': 1}, '#/minItems'),
    ('escaped unknown keyword', {'type': 'string', 'a~/b': true}, '#/a~0~1b'),
    ('escaped nested path', closedObject(properties: {'a/b~c': {'type': 'string', 'format': 'email'}}), '#/properties/a~1b~0c/format'),
  ];
  for (final (label, input, path) in bad) {
    test('rejects $label at the input definition path', () {
      expect(() => StructuredSchema.fromJsonSchema(input), failsAt(path));
    });
  }

  for (final keyword in ['allOf', 'oneOf', 'format', 'default', 'examples', 'minLength', 'maxLength', 'const', 'multipleOf']) {
    test('does not silently ignore $keyword', () {
      expect(() => StructuredSchema.fromJsonSchema({'type': 'string', keyword: 1}), failsAt('#/$keyword'));
    });
  }

  test('cyclic maps and excessive objects stop at bounded definition paths', () {
    final wide = closedObject(properties: {for (var i = 0; i < 129; i++) 'field$i': {'type': 'string'}});
    expect(() => StructuredSchema.fromJsonSchema(wide), failsAt('#/properties'));
    final cyclic = <String, Object?>{'type': 'array'};
    cyclic['items'] = cyclic;
    expect(() => StructuredSchema.fromJsonSchema(cyclic), failsAt('#${List.filled(17, '/items').join()}'));
  });

  test('imported definitions flow through one-shot generation and token budgets', () async {
    const channel = MethodChannel('test/imported-schemas');
    final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    final calls = <MethodCall>[];
    final models = CupertinoFoundationModels(platform: MethodChannelCupertinoFoundationModels(methodChannel: channel));
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      if (call.method == 'createSession') return {'sessionId': 'imports', 'mode': 'local'};
      if (call.method == 'generateStructured') return {'text': 'false', 'structuredValue': false, 'usedMode': 'local'};
      return null;
    });
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
    final schema = StructuredSchema.fromJsonSchema({'type': 'boolean', 'title': 'ContainsContact'});
    final response = await models.generateStructured(prompt: const Prompt.text('No contacts.'), schema: schema);
    expect(response.structuredValue, false);
    expect((calls[1].arguments as Map<Object?, Object?>)['schema'], schema.toMap());
    final session = await models.createSession();
    await session.measureTokenBudget(prompt: const Prompt.text('No contacts.'), schema: schema);
    expect((calls.last.arguments as Map<Object?, Object?>)['schema'], schema.toMap());
    await session.dispose();
  });

  test('imported contact fixture reaches guided streaming without optional fields', () async {
    const channel = MethodChannel('test/imported-stream');
    const codec = StandardMethodCodec();
    final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    final started = Completer<Map<Object?, Object?>>();
    messenger.setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'createSession') return {'sessionId': 'imports', 'mode': 'local'};
      if (call.method == 'startStream') started.complete(call.arguments as Map<Object?, Object?>);
      return null;
    });
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
    final schema = StructuredSchema.fromJsonSchema(jsonDecode(File('test/fixtures/import_closed_contacts.json').readAsStringSync()) as Map<String, Object?>);
    final models = CupertinoFoundationModels(platform: MethodChannelCupertinoFoundationModels(methodChannel: channel));
    final session = await models.createSession();
    final pending = session.streamStructured(prompt: const Prompt.text('Morgan supplied a name only.'), schema: schema).toList();
    final request = await started.future;
    expect(request['schema'], schema.toMap());
    final reply = Completer<ByteData?>();
    const value = [{'name': 'Morgan'}];
    await messenger.handlePlatformMessage(channel.name, codec.encodeMethodCall(MethodCall('streamEvent', {
      'requestId': request['requestId'],
      'event': {'type': 'completed', 'response': {'text': jsonEncode(value), 'structuredValue': value}},
    })), reply.complete);
    await reply.future;
    expect(((await pending).single as CompletionEvent).response.structuredValue, value);
    await session.dispose();
  });

  test('invalid import returns a typed local failure without transport calls or mutation', () async {
    const channel = MethodChannel('test/rejected-import');
    final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    final calls = <MethodCall>[];
    messenger.setMockMethodCallHandler(channel, (call) async { calls.add(call); return null; });
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
    final input = closedObject(properties: {'amount': {'type': 'number', 'format': 'money'}});
    final before = jsonEncode(input);
    try {
      final schema = StructuredSchema.fromJsonSchema(input);
      final models = CupertinoFoundationModels(platform: MethodChannelCupertinoFoundationModels(methodChannel: channel));
      await models.generateStructured(prompt: const Prompt.text('Amount supplied.'), schema: schema);
      fail('Expected a definition failure.');
    } on FoundationModelsException catch (error) {
      expect(error.code, FoundationModelsErrorCode.invalidRequest);
      expect(error.details['schemaPath'], '#/properties/amount/format');
      expect(error.details['schemaSource'], 'jsonSchema');
      expect(error.recoverySuggestion, isNotEmpty);
    }
    expect(calls, isEmpty);
    expect(jsonEncode(input), before);
  });
}

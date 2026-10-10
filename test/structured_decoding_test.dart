import 'dart:async';
import 'dart:convert';

import 'package:cupertino_fundations_models/cupertino_fundations_models.dart';
import 'package:cupertino_fundations_models/src/platform/method_channel_cupertino_foundation_models.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

// ignore: avoid_relative_lib_imports
import '../example/lib/document_extraction.dart';

ModelResponse finalResponse(Object? value, {GenerationTermination? termination}) => ModelResponse(
  text: 'original JSON text retained',
  usedMode: ModelMode.privateCloudCompute,
  metadata: const {'nativeRequestId': 'request-42', 'runtime': 'test'},
  structuredValue: value,
  usage: const ModelUsage(inputTokenCount: 20, cachedInputTokenCount: null,
      outputTokenCount: 4, reasoningTokenCount: null, totalTokenCount: null),
  termination: termination ?? const GenerationTermination(status: GenerationStatus.completed, structuredContentComplete: true),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('contact conversion preserves the original response and metadata by identity', () {
    final response = finalResponse({'name': 'Morgan'});
    var invocations = 0;
    final result = response.decodeStructured<(String, String?)>(decoder: (value) {
      invocations++;
      final contact = value! as Map<String, Object?>;
      return (contact['name']! as String, contact['email'] as String?);
    });
    expect(result.value, ('Morgan', null));
    expect(invocations, 1);
    expect(result.response, same(response));
    expect(result.response.metadata, same(response.metadata));
    expect(result.response.usage, same(response.usage));
    expect(result.response.termination, same(response.termination));
    expect(result.response.text, response.text);
    expect(result.response.usedMode, ModelMode.privateCloudCompute);
    expect(result.response.usage!.totalTokenCount, isNull);
  });

  for (final value in <Object>[false, 0, 0.0, '', <Object?>[], <String, Object?>{}]) {
    test('decodes valid scalar or empty root $value without replacing it', () {
      final response = finalResponse(value);
      final result = response.decodeStructured<Object?>(decoder: (value) => value);
      expect(result.value, same(value));
      expect(result.response, same(response));
    });
  }

  test('nullable domain output is allowed and decoded JSON is not reparsed', () {
    final response = finalResponse(false);
    expect(response.decodeStructured<String?>(decoder: (value) => null).value, isNull);
    expect(response.decodeStructured<bool>(decoder: (value) => value! as bool).value, false);
    expect(response.text, 'original JSON text retained');
    const unknown = ModelResponse(text: '0', usedMode: ModelMode.local, metadata: {}, structuredValue: 0);
    final result = unknown.decodeStructured<int>(decoder: (value) => value! as int);
    expect(result.value, 0);
    expect(result.response.usage, isNull);
    expect(result.response.termination.structuredContentComplete, isNull);
    expect(result.response.termination.reason, GenerationStopReason.unknown);
  });

  for (final status in [GenerationStatus.failed, GenerationStatus.cancelled, GenerationStatus.timedOut]) {
    test('rejects non-completed response $status before decoder invocation', () {
      var calls = 0;
      final response = finalResponse(0, termination: GenerationTermination(status: status));
      expect(() => response.decodeStructured<int>(decoder: (_) { calls++; return 0; }),
          throwsA(isA<FoundationModelsException>()
              .having((error) => error.code, 'code', FoundationModelsErrorCode.invalidRequest)
              .having((error) => error.details['responseStatus'], 'status', status.name)));
      expect(calls, 0);
    });
  }

  for (final response in [
    finalResponse(null),
    finalResponse({'name': 'Morgan'}, termination: const GenerationTermination(status: GenerationStatus.completed, structuredContentComplete: false)),
    const ModelResponse(text: '{"name":"Morgan"}', usedMode: ModelMode.local, metadata: {}),
  ]) {
    test('missing or explicitly incomplete structure never reaches decoder', () {
      var calls = 0;
      expect(() => response.decodeStructured<Object?>(decoder: (value) { calls++; return value; }),
          throwsA(isA<FoundationModelsException>()
              .having((error) => error.code, 'code', FoundationModelsErrorCode.parsingFailure)
              .having((error) => error.details['decodingStage'], 'stage', 'structuredValue')));
      expect(calls, 0);
    });
  }

  test('decoder failure retains its original cause and stack without exposing output', () {
    final response = finalResponse({'account': 'private account'});
    const cause = FormatException('private decoder detail');
    final originalStack = StackTrace.fromString('decoder.dart:12:3');
    try {
      response.decodeStructured<int>(decoder: (_) => Error.throwWithStackTrace(cause, originalStack));
      fail('Expected a conversion failure.');
    } on StructuredDecodingException catch (error, thrownStack) {
      expect(error.response, same(response));
      expect(error.cause, same(cause));
      expect(error.stackTrace.toString(), originalStack.toString());
      expect(thrownStack.toString(), originalStack.toString());
      expect(error.toString(), 'StructuredDecodingException: the application decoder failed.');
      expect(error.toString(), isNot(contains('private')));
    }
  });

  test('type errors and package exceptions thrown by decoder stay conversion failures', () {
    final response = finalResponse(false);
    expect(() => response.decodeStructured<int>(decoder: (value) => value! as int),
        throwsA(isA<StructuredDecodingException>().having((error) => error.cause, 'cause', isA<TypeError>())));
    const cause = FoundationModelsException(code: FoundationModelsErrorCode.toolFailed, message: 'app decoder exception');
    expect(() => response.decodeStructured<int>(decoder: (_) => throw cause),
        throwsA(isA<StructuredDecodingException>().having((error) => error.cause, 'cause', same(cause))));
  });

  test('document decoder retains signed amount spelling and optional dates', () {
    final response = finalResponse({'currency': 'EUR', 'rows': [
      {'sourceRow': 1, 'description': 'Material', 'amountText': '-1.234,56'},
      {'sourceRow': 2, 'dateText': '02/09/2026', 'description': 'Abono', 'amountText': '+2.000,00'},
    ]});
    final result = response.decodeStructured<ExtractedDocument>(decoder: ExtractedDocument.fromStructuredValue);
    expect(result.value.currency, 'EUR');
    expect(result.value.rows.first.sourceRow, 1);
    expect(result.value.rows.first.amountText, '-1.234,56');
    expect(result.value.rows.first.dateText, isNull);
    expect(result.value.rows.last.dateText, '02/09/2026');
    expect(result.value.rows.last.amountText, '+2.000,00');
    expect(result.value.rows.clear, throwsUnsupportedError);
    expect(result.response, same(response));
    expect(ExtractedDocument.fromStructuredValue({'currency': 'unknown', 'rows': <Object?>[]}).rows, isEmpty);
  });

  for (final value in <Object?>[
    null, false, {'currency': 'EUR'}, {'currency': 7, 'rows': <Object?>[]},
    {'currency': 'EUR', 'rows': [{'sourceRow': 1, 'description': 'Missing amount'}]},
    {'currency': 'EUR', 'rows': [{'sourceRow': 1, 'description': 'Material', 'amountText': '-3,50', 'dateText': 7}]},
  ]) {
    test('document decoder rejects incompatible app data', () {
      expect(() => ExtractedDocument.fromStructuredValue(value), throwsFormatException);
    });
  }

  group('typed generation through the existing native transport', () {
    const channel = MethodChannel('test/decoded-output');
    final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    late CupertinoFoundationModels models;
    late List<MethodCall> calls;
    late Object value;

    Map<String, Object?> wireResponse() => {
      'text': jsonEncode(value), 'structuredValue': value, 'usedMode': 'local',
      'metadata': {'nativeRequestId': 'native-42'},
      'usage': {'inputTokenCount': 20, 'outputTokenCount': 3},
      'termination': {'status': 'completed', 'reason': 'unknown', 'structuredContentComplete': true},
    };

    setUp(() {
      calls = [];
      value = false;
      models = CupertinoFoundationModels(platform: MethodChannelCupertinoFoundationModels(methodChannel: channel));
      messenger.setMockMethodCallHandler(channel, (call) async {
        calls.add(call);
        if (call.method == 'createSession') return {'sessionId': 'decoded', 'mode': 'local'};
        if (call.method == 'generateStructured') return wireResponse();
        return null;
      });
    });
    tearDown(() => messenger.setMockMethodCallHandler(channel, null));

    const booleanSchema = StructuredSchema.boolean(name: 'HasContact');
    const supplied = Prompt.text('Morgan supplied a name.');

    test('facade forwards choices and disposes before running the app decoder', () async {
      final diagnostics = <GenerationDiagnosticEvent>[];
      final options = GenerationOptions(maximumResponseTokens: 32, diagnostics: GenerationDiagnostics(onEvent: diagnostics.add));
      final result = await models.generateStructuredDecoded<bool>(
        prompt: supplied, schema: booleanSchema, mode: ModelMode.local,
        instructions: 'Extract supplied facts.', options: options,
        decoder: (value) {
          expect(calls.last.method, 'disposeSession');
          return value! as bool;
        },
      );
      expect(result.value, false);
      expect(result.response.text, 'false');
      expect(result.response.metadata['nativeRequestId'], 'native-42');
      expect(result.response.usage!.inputTokenCount, 20);
      expect(result.response.usage!.cachedInputTokenCount, isNull);
      expect(result.response.termination.structuredContentComplete, true);
      expect(calls.map((call) => call.method), ['createSession', 'generateStructured', 'disposeSession']);
      final creation = calls.first.arguments as Map<Object?, Object?>;
      expect(creation['mode'], 'local'); expect(creation['cloudPolicy'], 'never');
      expect(creation['instructions'], 'Extract supplied facts.');
      final request = calls[1].arguments as Map<Object?, Object?>;
      expect(request['prompt'], supplied.toMap()); expect(request['schema'], booleanSchema.toMap());
      expect(request['options'], options.toMap());
      expect(diagnostics.map((event) => event.stage), [GenerationDiagnosticStage.started, GenerationDiagnosticStage.completed]);
    });

    test('default facade options keep the existing privacy policy', () async {
      await models.generateStructuredDecoded(prompt: supplied, schema: booleanSchema, decoder: (value) => value);
      final creation = calls.first.arguments as Map<Object?, Object?>;
      expect(creation['mode'], 'automatic'); expect(creation['cloudPolicy'], 'never');
    });

    test('an explicitly authorized PCC selection is forwarded without routing changes', () async {
      await models.generateStructuredDecoded<bool>(prompt: supplied, schema: booleanSchema,
        mode: ModelMode.privateCloudCompute, cloudPolicy: CloudPolicy.whenExplicit,
        decoder: (value) => value! as bool,
      );
      final creation = calls.first.arguments as Map<Object?, Object?>;
      expect(creation['mode'], 'privateCloudCompute'); expect(creation['cloudPolicy'], 'whenExplicit');
    });

    test('session cleanup failure prevents facade decoding', () async {
      var decodes = 0;
      messenger.setMockMethodCallHandler(channel, (call) async {
        calls.add(call);
        if (call.method == 'createSession') return {'sessionId': 'decoded', 'mode': 'local'};
        if (call.method == 'generateStructured') return wireResponse();
        if (call.method == 'disposeSession') throw PlatformException(code: 'nativeFailure', message: 'cleanup failed');
        return null;
      });
      await expectLater(models.generateStructuredDecoded<Object?>(prompt: supplied, schema: booleanSchema, decoder: (value) { decodes++; return value; }),
          throwsA(isA<FoundationModelsException>().having((error) => error.code, 'code', FoundationModelsErrorCode.nativeFailure)));
      expect(decodes, 0); expect(calls.last.method, 'disposeSession');
    });

    for (final complete in [false, null]) {
      test('missing or incomplete native payload is not passed to facade decoder: $complete', () async {
        var decodes = 0;
        messenger.setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          if (call.method == 'createSession') return {'sessionId': 'decoded', 'mode': 'local'};
          if (call.method == 'generateStructured') { return {
            'text': 'false', if (complete != null) 'structuredValue': false,
            'termination': {'status': 'completed', 'structuredContentComplete': complete},
          }; }
          return null;
        });
        await expectLater(models.generateStructuredDecoded<Object?>(prompt: supplied, schema: booleanSchema, decoder: (value) { decodes++; return value; }),
            throwsA(isA<FoundationModelsException>().having((error) => error.code, 'code', FoundationModelsErrorCode.parsingFailure)));
        expect(decodes, 0); expect(calls.last.method, 'disposeSession');
      });
    }

    test('facade decoder failure retains completed response after session release', () async {
      const cause = FormatException('expected a contact object');
      await expectLater(models.generateStructuredDecoded<int>(prompt: supplied, schema: booleanSchema, decoder: (_) => throw cause),
          throwsA(isA<StructuredDecodingException>()
              .having((error) => error.cause, 'cause', same(cause))
              .having((error) => error.response.structuredValue, 'value', false)
              .having((error) => error.response.usage!.outputTokenCount, 'usage', 3)));
      expect(calls.last.method, 'disposeSession');
      expect(calls.where((call) => call.method == 'generateStructured'), hasLength(1));
    });

    for (final code in ['invalidRequest', 'parsingFailure', 'cancelled']) {
      test('native $code bypasses decoder and releases facade session', () async {
        var decodes = 0;
        messenger.setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          if (call.method == 'createSession') return {'sessionId': 'decoded', 'mode': 'local'};
          if (call.method == 'generateStructured') throw PlatformException(code: code, details: {'schemaPath': '#/properties/name'});
          return null;
        });
        await expectLater(models.generateStructuredDecoded<Object?>(prompt: supplied, schema: booleanSchema, decoder: (value) { decodes++; return value; }),
            throwsA(isA<FoundationModelsException>()
                .having((error) => error.code.name, 'native code', code)
                .having((error) => error.details['schemaPath'], 'path', '#/properties/name')));
        expect(decodes, 0); expect(calls.last.method, 'disposeSession');
      });
    }

    test('invalid manual constraints do not invoke native generation or the decoder', () async {
      var decodes = 0;
      await expectLater(models.generateStructuredDecoded<Object?>(
        prompt: supplied, schema: const StructuredSchema.integer(name: 'Invalid', minimum: 5, maximum: 1),
        decoder: (value) { decodes++; return value; },
      ), throwsArgumentError);
      expect(decodes, 0); expect(calls.map((call) => call.method), ['createSession', 'disposeSession']);
    });

    test('imported contact arrays convert to a domain list with absent optional email', () async {
      value = [{'name': 'Morgan'}, {'name': 'Riley', 'email': 'riley@example.test'}];
      final schema = StructuredSchema.fromJsonSchema({
        'type': 'array', 'items': {'type': 'object', 'additionalProperties': false,
          'required': ['name'], 'properties': {'name': {'type': 'string'}, 'email': {'type': 'string'}}},
      });
      final result = await models.generateStructuredDecoded<List<(String, String?)>>(
        prompt: supplied, schema: schema,
        decoder: (value) => (value! as List<Object?>).map((entry) {
          final contact = entry! as Map<String, Object?>;
          return (contact['name']! as String, contact['email'] as String?);
        }).toList(),
      );
      expect(result.value, [('Morgan', null), ('Riley', 'riley@example.test')]);
      expect((calls[1].arguments as Map<Object?, Object?>)['schema'], schema.toMap());
    });

    test('the existing document example exposes a typed one-shot result and response', () async {
      value = {'currency': 'EUR', 'rows': [{'sourceRow': 1, 'description': 'Material', 'amountText': '-1.234,56'}]};
      final result = await extractDocumentDecoded(models: models, document: fictionalDocument);
      expect(result.value.rows.single.amountText, '-1.234,56');
      expect(result.response.metadata['nativeRequestId'], 'native-42');
      expect((calls[1].arguments as Map<Object?, Object?>)['schema'], documentSchema.toMap());
      expect(calls.last.method, 'disposeSession');
    });

    test('session remains reusable after decoder failure and diagnostics stay native', () async {
      final session = await models.createSession();
      final events = <GenerationDiagnosticEvent>[];
      final options = GenerationOptions(diagnostics: GenerationDiagnostics(onEvent: events.add));
      await expectLater(session.generateStructuredDecoded<int>(prompt: supplied, schema: booleanSchema, options: options, decoder: (_) => throw StateError('bad app conversion')),
          throwsA(isA<StructuredDecodingException>()));
      final next = await session.generateStructuredDecoded<bool>(prompt: supplied, schema: booleanSchema, options: options, decoder: (value) => value! as bool);
      expect(next.value, false);
      expect(events.map((event) => event.stage), [GenerationDiagnosticStage.started, GenerationDiagnosticStage.completed, GenerationDiagnosticStage.started, GenerationDiagnosticStage.completed]);
      expect(calls.where((call) => call.method == 'disposeSession'), isEmpty);
      await session.dispose();
      expect(calls.where((call) => call.method == 'disposeSession'), hasLength(1));
    });

    test('decoded session requests retain single-flight admission', () async {
      final pendingResponse = Completer<Object?>();
      final started = Completer<void>();
      messenger.setMockMethodCallHandler(channel, (call) async {
        calls.add(call);
        if (call.method == 'createSession') return {'sessionId': 'decoded', 'mode': 'local'};
        if (call.method == 'generateStructured') { started.complete(); return pendingResponse.future; }
        return null;
      });
      final session = await models.createSession();
      final pending = session.generateStructuredDecoded<bool>(prompt: supplied, schema: booleanSchema, decoder: (value) => value! as bool);
      await started.future;
      var decodes = 0;
      await expectLater(session.generateStructuredDecoded<bool>(prompt: supplied, schema: booleanSchema, decoder: (_) { decodes++; return true; }),
          throwsA(isA<FoundationModelsException>().having((error) => error.code, 'code', FoundationModelsErrorCode.concurrentRequests)));
      pendingResponse.complete(wireResponse());
      expect((await pending).value, false); expect(decodes, 0);
      expect(calls.where((call) => call.method == 'generateStructured'), hasLength(1));
      await session.dispose();
    });

    test('timeout cancels native work and does not invoke a decoder or retry', () async {
      final pendingResponse = Completer<Object?>();
      messenger.setMockMethodCallHandler(channel, (call) async {
        calls.add(call);
        if (call.method == 'createSession') return {'sessionId': 'decoded', 'mode': 'local'};
        if (call.method == 'generateStructured') return pendingResponse.future;
        if (call.method == 'cancelActiveRequest') pendingResponse.completeError(PlatformException(code: 'cancelled'));
        return null;
      });
      var decodes = 0;
      await expectLater(models.generateStructuredDecoded<bool>(
        prompt: supplied, schema: booleanSchema,
        options: const GenerationOptions(timeout: Duration(milliseconds: 20)),
        decoder: (_) { decodes++; return true; },
      ), throwsA(isA<FoundationModelsException>().having((error) => error.code, 'code', FoundationModelsErrorCode.generationTimeout)));
      expect(decodes, 0);
      expect(calls.map((call) => call.method), ['createSession', 'generateStructured', 'cancelActiveRequest', 'disposeSession']);
    });

    test('completion responses can be decoded without touching partial snapshots', () async {
      const codec = StandardMethodCodec();
      final started = Completer<Map<Object?, Object?>>();
      messenger.setMockMethodCallHandler(channel, (call) async {
        calls.add(call);
        if (call.method == 'createSession') return {'sessionId': 'decoded', 'mode': 'local'};
        if (call.method == 'startStream') started.complete(call.arguments as Map<Object?, Object?>);
        return null;
      });
      final session = await models.createSession();
      var decodes = 0;
      final snapshots = <String>[];
      final pending = session.streamStructured(prompt: supplied, schema: booleanSchema).map((event) {
        if (event is TextSnapshotEvent) snapshots.add(event.text);
        if (event is CompletionEvent) return event.response.decodeStructured<bool>(decoder: (value) { decodes++; return value! as bool; });
        return null;
      }).toList();
      final request = await started.future;
      Future<void> emit(Map<String, Object?> event) async {
        final reply = Completer<ByteData?>();
        await messenger.handlePlatformMessage(channel.name, codec.encodeMethodCall(MethodCall('streamEvent', {'requestId': request['requestId'], 'event': event})), reply.complete);
        await reply.future;
      }
      await emit({'type': 'textSnapshot', 'text': 'fa'});
      expect(decodes, 0);
      await emit({'type': 'completed', 'response': wireResponse()});
      final results = await pending;
      expect(results.last!.value, false); expect(decodes, 1);
      expect(snapshots, ['fa']);
      expect(calls.where((call) => call.method == 'generateStructured'), isEmpty);
      await session.dispose();
    });
  });
}

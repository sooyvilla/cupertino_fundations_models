import 'dart:async';

import 'package:cupertino_fundations_models/cupertino_fundations_models.dart';
import 'package:cupertino_fundations_models/src/platform/method_channel_cupertino_foundation_models.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../test_helpers.dart';

void main() {
  group('method channel platform', () {
    late MethodChannel methodChannel;
    late EventChannel eventChannel;
    late MethodChannelCupertinoFoundationModels platform;
    final log = <MethodCall>[];

    setUp(() {
      log.clear();
      methodChannel = const MethodChannel('test/cupertino/methods');
      eventChannel = const EventChannel('test/cupertino/events');
      platform = MethodChannelCupertinoFoundationModels(
        methodChannel: methodChannel,
        eventChannel: eventChannel,
      );
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(methodChannel, (MethodCall call) async {
            log.add(call);
            switch (call.method) {
              case 'getCapabilities':
                return capabilitiesMap();
              case 'getDiagnostics':
                return diagnosticsMap(call.arguments as Map<Object?, Object?>);
              case 'checkAvailability':
                return availabilityMap();
              case 'createSession':
                return <String, Object?>{
                  'sessionId': 'native_1',
                  'mode': 'future',
                };
              case 'pickFile':
                return (call.arguments as Map<Object?, Object?>)['kind'] ==
                        'any'
                    ? null
                    : <String, Object?>{
                        'path': '/tmp/a',
                        'name': 'a',
                        'kind': 'image',
                      };
              case 'transcribeAudio':
                return <String, Object?>{
                  'text': 'audio',
                  'isFinal': true,
                  'usedMode': 'server',
                };
              case 'respond':
                return <String, Object?>{'text': 'native'};
              case 'generateStructured':
                return <String, Object?>{
                  'text': 'structured',
                  'structuredValue': <String, Object?>{'ok': true},
                };
              case 'prewarm':
              case 'cancelActiveRequest':
              case 'disposeSession':
                return null;
            }
            return null;
          });
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(methodChannel, null);
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMessageHandler('test/cupertino/events', null);
    });

    test('invokes every method and maps responses', () async {
      expect((await platform.getCapabilities()).platform, 'ios');
      expect(
        (await platform.getDiagnostics(
          localeIdentifier: 'es_ES',
        )).targetLocaleIdentifier,
        'es_ES',
      );
      expect(
        (await platform.checkAvailability(
          mode: ModelMode.local,
          cloudPolicy: CloudPolicy.never,
          localeIdentifier: null,
        )).isAvailable,
        isTrue,
      );

      final session = await platform.createSession(
        options: const SessionOptions(mode: ModelMode.local),
      );
      expect(session.id, 'native_1');
      expect(session.mode, ModelMode.local);

      expect(
        await platform.pickFile(kind: FoundationModelsFileKind.any),
        isNull,
      );
      expect(
        (await platform.pickFile(kind: FoundationModelsFileKind.image))?.kind,
        FoundationModelsFileKind.image,
      );
      expect(
        (await platform.transcribeAudio(
          request: const AudioTranscriptionRequest(filePath: '/tmp/a'),
        )).text,
        'audio',
      );
      expect(
        (await platform.respond(
          sessionId: 's',
          prompt: const Prompt.text('p'),
          options: const GenerationOptions(),
        )).text,
        'native',
      );
      expect(
        (await platform.generateStructured(
          sessionId: 's',
          prompt: const Prompt.text('p'),
          schema: testSchema(),
          options: const GenerationOptions(),
        )).structuredValue,
        <String, Object?>{'ok': true},
      );
      await platform.prewarm(
        sessionId: 's',
        promptPrefix: const Prompt.text('prefix'),
      );
      await platform.prewarm(sessionId: 's', promptPrefix: null);
      await platform.cancelActiveRequest(sessionId: 's');
      await platform.disposeSession(sessionId: 's');

      expect(
        log.map((MethodCall call) => call.method),
        containsAll(<String>[
          'getCapabilities',
          'getDiagnostics',
          'checkAvailability',
          'createSession',
          'pickFile',
          'transcribeAudio',
          'respond',
          'generateStructured',
          'prewarm',
          'cancelActiveRequest',
          'disposeSession',
        ]),
      );
    });

    test('converts platform exceptions', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(methodChannel, (MethodCall call) async {
            throw PlatformException(
              code: FoundationModelsErrorCode.invalidRequest.name,
              message: 'bad',
              details: <Object?, Object?>{'recoverySuggestion': 'fix it'},
            );
          });

      await expectLater(
        platform.getCapabilities(),
        throwsA(
          isA<FoundationModelsException>().having(
            (e) => e.code,
            'code',
            FoundationModelsErrorCode.invalidRequest,
          ),
        ),
      );
    });

    test('stream maps events and platform errors', () async {
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      const codec = StandardMethodCodec();
      messenger.setMockMessageHandler('test/cupertino/events', (
        ByteData? message,
      ) async {
        final methodCall = codec.decodeMethodCall(message);
        if (methodCall.method == 'cancel') {
          return codec.encodeSuccessEnvelope(null);
        }
        expect(methodCall.method, 'listen');
        final arguments = methodCall.arguments as Map<Object?, Object?>;
        expect(arguments['sessionId'], 's');
        expect(arguments['requestId'], startsWith('request_'));
        unawaited(
          Future<void>(() async {
            await messenger.handlePlatformMessage(
              'test/cupertino/events',
              codec.encodeSuccessEnvelope(<String, Object?>{
                'type': 'textDelta',
                'requestId': arguments['requestId'],
                'text': 'hi',
              }),
              (_) {},
            );
            await messenger.handlePlatformMessage(
              'test/cupertino/events',
              codec.encodeErrorEnvelope(
                code: FoundationModelsErrorCode.nativeFailure.name,
                message: 'failed',
                details: <String, Object?>{'recoverySuggestion': 'retry'},
              ),
              (_) {},
            );
          }),
        );
        return codec.encodeSuccessEnvelope(null);
      });

      final stream = platform.stream(
        sessionId: 's',
        prompt: const Prompt.text('hello'),
        options: const GenerationOptions(),
      );

      await expectLater(
        stream,
        emitsInOrder(<Object>[
          isA<TextSnapshotEvent>().having((event) => event.text, 'text', 'hi'),
          emitsError(
            isA<FoundationModelsException>().having(
              (error) => error.code,
              'code',
              FoundationModelsErrorCode.nativeFailure,
            ),
          ),
        ]),
      );
    });

    test('stream forwards non-platform errors', () async {
      final throwingPlatform = MethodChannelCupertinoFoundationModels(
        methodChannel: methodChannel,
        eventChannel: const ThrowingEventChannel('test/cupertino/throwing'),
      );

      await expectLater(
        throwingPlatform.stream(
          sessionId: 's',
          prompt: const Prompt.text('hello'),
          options: const GenerationOptions(),
        ),
        emitsError(isNot(isA<FoundationModelsException>())),
      );
    });

    test('uses empty maps for invalid method responses', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(methodChannel, (MethodCall call) async {
            return 'not a map';
          });

      expect((await platform.getCapabilities()).platform, 'unknown');
    });
  });
}

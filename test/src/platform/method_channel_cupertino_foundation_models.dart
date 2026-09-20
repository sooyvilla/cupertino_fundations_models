import 'dart:async';

import 'package:cupertino_fundations_models/cupertino_fundations_models.dart';
import 'package:cupertino_fundations_models/src/platform/method_channel_cupertino_foundation_models.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../test_helpers.dart';

void main() {
  group('method channel platform', () {
    late MethodChannel methodChannel;
    late MethodChannelCupertinoFoundationModels platform;
    final log = <MethodCall>[];

    setUp(() {
      log.clear();
      methodChannel = const MethodChannel('test/cupertino/methods');
      platform = MethodChannelCupertinoFoundationModels(
        methodChannel: methodChannel,
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
              case 'startStream':
              case 'cancelStream':
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
      messenger.setMockMethodCallHandler(methodChannel, (
        MethodCall call,
      ) async {
        if (call.method == 'cancelStream') {
          return null;
        }
        expect(call.method, 'startStream');
        final arguments = call.arguments as Map<Object?, Object?>;
        final String requestId = arguments['requestId']! as String;
        expect(arguments['sessionId'], 's');
        expect(requestId, startsWith('request_'));
        unawaited(
          Future<void>(() async {
            await _sendNativeMethodCall(
              messenger,
              methodChannel.name,
              codec,
              MethodCall('streamEvent', <String, Object?>{
                'requestId': requestId,
                'event': <String, Object?>{
                  'type': 'textSnapshot',
                  'requestId': requestId,
                  'text': 'hi',
                },
              }),
            );
            await _sendNativeMethodCall(
              messenger,
              methodChannel.name,
              codec,
              MethodCall('streamEvent', <String, Object?>{
                'requestId': requestId,
                'error': <String, Object?>{
                  'code': FoundationModelsErrorCode.nativeFailure.name,
                  'message': 'failed',
                  'details': const <String, Object?>{
                    'recoverySuggestion': 'retry',
                  },
                },
              }),
            );
          }),
        );
        return null;
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

    test('multiplexes streams without cross-delivering events', () async {
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      const codec = StandardMethodCodec();
      messenger.setMockMethodCallHandler(methodChannel, (
        MethodCall call,
      ) async {
        if (call.method == 'cancelStream') {
          return null;
        }
        final arguments = call.arguments as Map<Object?, Object?>;
        final String requestId = arguments['requestId']! as String;
        final String sessionId = arguments['sessionId']! as String;
        unawaited(
          Future<void>(() async {
            await _sendNativeMethodCall(
              messenger,
              methodChannel.name,
              codec,
              MethodCall('streamEvent', <String, Object?>{
                'requestId': requestId,
                'event': <String, Object?>{
                  'type': 'textSnapshot',
                  'requestId': requestId,
                  'text': sessionId,
                },
              }),
            );
            await _sendNativeMethodCall(
              messenger,
              methodChannel.name,
              codec,
              MethodCall('streamEvent', <String, Object?>{
                'requestId': requestId,
                'event': <String, Object?>{
                  'type': 'completed',
                  'requestId': requestId,
                  'response': <String, Object?>{
                    'text': sessionId,
                    'usedMode': 'local',
                  },
                },
              }),
            );
          }),
        );
        return null;
      });

      final List<List<SessionEvent>> results =
          await Future.wait(<Future<List<SessionEvent>>>[
            platform
                .stream(
                  sessionId: 'first',
                  prompt: const Prompt.text('hello'),
                  options: const GenerationOptions(),
                )
                .toList(),
            platform
                .stream(
                  sessionId: 'second',
                  prompt: const Prompt.text('hello'),
                  options: const GenerationOptions(),
                )
                .toList(),
          ]);

      expect((results[0].first as TextSnapshotEvent).text, 'first');
      expect((results[1].first as TextSnapshotEvent).text, 'second');
    });

    test('subscription cancellation targets the exact native stream', () async {
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      const codec = StandardMethodCodec();
      final started = Completer<Map<Object?, Object?>>();
      final cancelled = Completer<Map<Object?, Object?>>();
      messenger.setMockMethodCallHandler(methodChannel, (
        MethodCall call,
      ) async {
        final arguments = call.arguments as Map<Object?, Object?>;
        if (call.method == 'startStream') {
          started.complete(arguments);
          return null;
        }
        if (call.method == 'cancelStream') {
          cancelled.complete(arguments);
          return null;
        }
        return null;
      });

      final StreamSubscription<SessionEvent> subscription = platform
          .stream(
            sessionId: 'cancel-session',
            prompt: const Prompt.text('hello'),
            options: const GenerationOptions(),
          )
          .listen((SessionEvent _) {});
      final Map<Object?, Object?> startArguments = await started.future;
      await subscription.cancel();
      final Map<Object?, Object?> cancelArguments = await cancelled.future;

      expect(cancelArguments['sessionId'], 'cancel-session');
      expect(cancelArguments['requestId'], startArguments['requestId']);

      await _sendNativeMethodCall(
        messenger,
        methodChannel.name,
        codec,
        MethodCall('streamEvent', <String, Object?>{
          'requestId': startArguments['requestId'],
          'event': <String, Object?>{
            'type': 'textSnapshot',
            'requestId': startArguments['requestId'],
            'text': 'late',
          },
        }),
      );
    });

    test('forwards startStream platform errors', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(methodChannel, (MethodCall call) async {
            throw PlatformException(code: 'nativeFailure', message: 'failed');
          });

      await expectLater(
        platform.stream(
          sessionId: 's',
          prompt: const Prompt.text('hello'),
          options: const GenerationOptions(),
        ),
        emitsError(isA<FoundationModelsException>()),
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

Future<void> _sendNativeMethodCall(
  TestDefaultBinaryMessenger messenger,
  String channel,
  StandardMethodCodec codec,
  MethodCall call,
) {
  final Completer<void> completer = Completer<void>();
  unawaited(
    messenger.handlePlatformMessage(channel, codec.encodeMethodCall(call), (
      ByteData? reply,
    ) {
      completer.complete();
    }),
  );
  return completer.future;
}

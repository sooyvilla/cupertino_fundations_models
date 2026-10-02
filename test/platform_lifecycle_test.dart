import 'dart:async';

import 'package:cupertino_fundations_models/cupertino_fundations_models.dart';
import 'package:cupertino_fundations_models/src/platform/method_channel_cupertino_foundation_models.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'src/controlled_event_channel.dart';
import 'src/test_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('test/platform/lifecycle');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  const codec = StandardMethodCodec();
  late MethodChannelCupertinoFoundationModels platform;
  late List<MethodCall> calls;

  setUp(() {
    calls = [];
    platform = MethodChannelCupertinoFoundationModels(methodChannel: channel);
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return null;
    });
  });
  tearDown(() {
    messenger.setMockMethodCallHandler(channel, null);
  });

  Future<Object?> native(MethodCall call) async {
    final result = Completer<ByteData?>();
    await messenger.handlePlatformMessage(
      channel.name,
      codec.encodeMethodCall(call),
      result.complete,
    );
    final reply = await result.future;
    return reply == null ? null : codec.decodeEnvelope(reply);
  }

  test(
    'language lists filter invalid values and token requests preserve their target',
    () async {
      messenger.setMockMethodCallHandler(channel, (call) async {
        calls.add(call);
        if (call.method == 'getSupportedLanguages') {
          return <Object?>[
            <Object?, Object?>{'identifier': 'es'},
            'invalid',
          ];
        }
        if (call.method == 'countTokens') {
          return 4;
        }
        if (call.method == 'measureTokenBudget') {
          return <String, Object?>{
            'mode': 'local',
            'components': <String, Object?>{
              'prompt': <String, Object?>{'count': 4, 'precision': 'exact'},
            },
          };
        }
        return null;
      });
      expect((await platform.getSupportedLanguages()).single.identifier, 'es');
      expect(await platform.countTokens(prompt: const Prompt.text('hola')), 4);
      expect(await platform.countSessionTokens(sessionId: 's'), 4);
      expect(calls[1].arguments, <String, Object?>{
        'target': 'prompt',
        'prompt': const Prompt.text('hola').toMap(),
      });
      expect(calls[2].arguments, <String, Object?>{
        'target': 'transcript',
        'sessionId': 's',
      });
      final budget = await platform.measureTokenBudget(
        sessionId: 's',
        prompt: const Prompt.text('hola'),
        options: const GenerationOptions(),
        schema: testSchema(),
      );
      expect(budget.components['prompt']!.count, 4);
      expect(
        (calls.last.arguments as Map<Object?, Object?>)['schema'],
        testSchema().toMap(),
      );
      messenger.setMockMethodCallHandler(channel, (_) async => null);
      expect(await platform.getSupportedLanguages(), isEmpty);
      expect(await platform.countTokens(prompt: const Prompt.text('p')), 0);
      expect(await platform.countSessionTokens(sessionId: 's'), 0);
      expect(
        (await platform.measureTokenBudget(
          sessionId: 's',
          prompt: const Prompt.text('p'),
          options: const GenerationOptions(),
        )).components,
        isEmpty,
      );
    },
  );

  test(
    'missing native registration returns a recoverable Apple platform error',
    () async {
      messenger.setMockMethodCallHandler(channel, null);
      await expectLater(
        platform.getCapabilities(),
        throwsA(
          isA<FoundationModelsException>()
              .having(
                (e) => e.code,
                'code',
                FoundationModelsErrorCode.unsupportedPlatform,
              )
              .having(
                (e) => e.recoverySuggestion,
                'recovery',
                contains('macOS'),
              ),
        ),
      );
    },
  );

  test(
    'tool callbacks route only to live registered sessions and decode JSON objects',
    () async {
      messenger.setMockMethodCallHandler(
        channel,
        (call) async => call.method == 'createSession'
            ? <String, Object?>{'sessionId': 's', 'mode': 'local'}
            : null,
      );
      final session = await platform.createSession(
        options: SessionOptions(
          tools: [TestTool(name: 'echo', callback: (arguments) => arguments)],
        ),
      );
      expect(await native(const MethodCall('unknown')), isNull);
      for (final json in <String?>['{"ok":true}', '', null]) {
        final response =
            await native(
                  MethodCall('toolCall', <String, Object?>{
                    'sessionId': 's',
                    'name': 'echo',
                    'toolCallId': 't',
                    'argumentsJson': json,
                  }),
                )
                as Map<Object?, Object?>;
        expect(response['isError'], isFalse);
        expect(
          response['value'],
          json == '{"ok":true}' ? <Object?, Object?>{'ok': true} : isEmpty,
        );
      }
      for (final json in ['[1]', '{invalid']) {
        final response =
            await native(
                  MethodCall('toolCall', <String, Object?>{
                    'sessionId': 's',
                    'name': 'echo',
                    'argumentsJson': json,
                  }),
                )
                as Map<Object?, Object?>;
        expect(response['isError'], isTrue);
        expect(response['message'], contains('JSON object'));
      }
      await session.dispose();
      final response =
          await native(
                const MethodCall('toolCall', <String, Object?>{
                  'sessionId': 's',
                  'name': 'echo',
                }),
              )
              as Map<Object?, Object?>;
      expect(response['message'], contains('No live session'));
    },
  );

  test(
    'transcription timeout cancels only its request and retains timeout on cancellation failure',
    () async {
      final pending = Completer<Object?>();
      messenger.setMockMethodCallHandler(channel, (call) async {
        calls.add(call);
        if (call.method == 'transcribeAudio') {
          return pending.future;
        }
        throw PlatformException(code: 'nativeFailure');
      });
      await expectLater(
        platform.transcribeAudio(
          request: const AudioTranscriptionRequest(
            filePath: '/a',
            timeout: Duration(milliseconds: 10),
          ),
        ),
        throwsA(
          isA<FoundationModelsException>().having(
            (e) => e.code,
            'code',
            FoundationModelsErrorCode.transcriptionTimeout,
          ),
        ),
      );
      expect(calls.map((call) => call.method), [
        'transcribeAudio',
        'cancelTranscription',
      ]);
      expect(
        (calls.last.arguments as Map<Object?, Object?>)['requestId'],
        (calls.first.arguments as Map<Object?, Object?>)['requestId'],
      );
      pending.complete(null);
    },
  );

  test('live transcription stops after its final snapshot', () async {
    platform = MethodChannelCupertinoFoundationModels(
      methodChannel: channel,
      transcriptionEventChannel: ControlledEventChannel(
        Stream<Object?>.fromIterable([
          const {'text': 'first'},
          const {'text': 'final', 'isFinal': true},
          const {'text': 'late'},
        ]),
      ),
    );
    final results = await platform
        .liveTranscription(request: const LiveTranscriptionRequest())
        .toList();
    expect(results.map((event) => event.text), ['first', 'final']);
    expect(calls.single.method, 'stopLiveTranscription');
  });

  test(
    'live transcription rejects overlapping capture and releases capture after cancellation',
    () async {
      final controller = StreamController<Object?>();
      platform = MethodChannelCupertinoFoundationModels(
        methodChannel: channel,
        transcriptionEventChannel: ControlledEventChannel(controller.stream),
      );
      final seen = Completer<void>();
      final first = platform
          .liveTranscription(request: const LiveTranscriptionRequest())
          .listen((_) => seen.complete());
      controller.add(const {'text': 'partial'});
      await seen.future;
      await expectLater(
        platform.liveTranscription(request: const LiveTranscriptionRequest()),
        emitsError(
          isA<FoundationModelsException>().having(
            (e) => e.code,
            'code',
            FoundationModelsErrorCode.concurrentRequests,
          ),
        ),
      );
      await first.cancel();
      await controller.close();
      expect(calls.single.method, 'stopLiveTranscription');
    },
  );

  test(
    'live transcription converts native errors and releases capture even if stop fails',
    () async {
      platform = MethodChannelCupertinoFoundationModels(
        methodChannel: channel,
        transcriptionEventChannel: ControlledEventChannel.factory(
          () => Stream<Object?>.error(
            PlatformException(code: 'permissionDenied', message: 'microphone'),
          ),
        ),
      );
      await expectLater(
        platform.liveTranscription(request: const LiveTranscriptionRequest()),
        emitsError(isA<FoundationModelsException>()),
      );
      messenger.setMockMethodCallHandler(
        channel,
        (_) async => throw PlatformException(code: 'nativeFailure'),
      );
      await expectLater(
        platform.liveTranscription(request: const LiveTranscriptionRequest()),
        emitsInOrder([
          emitsError(isA<FoundationModelsException>()),
          emitsError(
            isA<FoundationModelsException>().having(
              (e) => e.code,
              'code',
              FoundationModelsErrorCode.nativeFailure,
            ),
          ),
          emitsDone,
        ]),
      );
      messenger.setMockMethodCallHandler(channel, (_) async => null);
      await expectLater(
        platform.liveTranscription(request: const LiveTranscriptionRequest()),
        emitsError(
          isA<FoundationModelsException>().having(
            (e) => e.code,
            'code',
            isNot(FoundationModelsErrorCode.concurrentRequests),
          ),
        ),
      );
    },
  );

  test(
    'live transcription reports malformed snapshots and natural closure',
    () async {
      platform = MethodChannelCupertinoFoundationModels(
        methodChannel: channel,
        transcriptionEventChannel: ControlledEventChannel(
          Stream<Object?>.fromIterable([
            const {'text': 7},
          ]),
        ),
      );
      await expectLater(
        platform.liveTranscription(request: const LiveTranscriptionRequest()),
        emitsInOrder([emitsError(isA<TypeError>()), emitsDone]),
      );
      platform = MethodChannelCupertinoFoundationModels(
        methodChannel: channel,
        transcriptionEventChannel: ControlledEventChannel(
          const Stream<Object?>.empty(),
        ),
      );
      expect(
        await platform
            .liveTranscription(request: const LiveTranscriptionRequest())
            .toList(),
        isEmpty,
      );
      expect(
        calls.where((call) => call.method == 'stopLiveTranscription'),
        hasLength(2),
      );
    },
  );

  test(
    'live transcription handles synchronous source setup failures',
    () async {
      platform = MethodChannelCupertinoFoundationModels(
        methodChannel: channel,
        transcriptionEventChannel: ControlledEventChannel.factory(
          () => throw StateError('setup'),
        ),
      );
      await expectLater(
        platform.liveTranscription(request: const LiveTranscriptionRequest()),
        emitsInOrder([emitsError(isA<StateError>()), emitsDone]),
      );
      expect(calls.single.method, 'stopLiveTranscription');
    },
  );

  test(
    'disposing one session closes its streams without closing another session',
    () async {
      final started = Completer<void>();
      messenger.setMockMethodCallHandler(channel, (call) async {
        calls.add(call);
        if (calls.where((entry) => entry.method == 'startStream').length == 2 &&
            !started.isCompleted) {
          started.complete();
        }
        return null;
      });
      final firstDone = Completer<void>();
      final first = platform
          .stream(
            sessionId: 'first',
            prompt: const Prompt.text('p'),
            options: const GenerationOptions(),
            schema: testSchema(),
          )
          .listen((_) {}, onDone: firstDone.complete);
      final secondDone = Completer<void>();
      final second = platform
          .stream(
            sessionId: 'second',
            prompt: const Prompt.text('p'),
            options: const GenerationOptions(),
          )
          .listen((_) {}, onDone: secondDone.complete);
      await started.future;
      await platform.disposeSession(sessionId: 'first');
      await firstDone.future;
      expect(secondDone.isCompleted, isFalse);
      await first.cancel();
      await second.cancel();
    },
  );

  test(
    'late stream startup failures cannot reopen a cancelled subscription',
    () async {
      final startup = Completer<Object?>();
      final started = Completer<void>();
      messenger.setMockMethodCallHandler(channel, (call) async {
        if (call.method == 'startStream') {
          started.complete();
          return startup.future;
        }
        return null;
      });
      final subscription = platform
          .stream(
            sessionId: 's',
            prompt: const Prompt.text('p'),
            options: const GenerationOptions(),
          )
          .listen(
            (_) {},
            onError: (Object _) => fail('Late failure delivered'),
          );
      await started.future;
      await subscription.cancel();
      startup.completeError(PlatformException(code: 'nativeFailure'));
      await Future<void>.delayed(Duration.zero);
    },
  );
  test('cancellation after a final snapshot awaits native stop', () async {
    final stop = Completer<Object?>();
    final stopping = Completer<void>();
    messenger.setMockMethodCallHandler(channel, (call) async {
      stopping.complete();
      return stop.future;
    });
    platform = MethodChannelCupertinoFoundationModels(
      methodChannel: channel,
      transcriptionEventChannel: ControlledEventChannel(
        Stream<Object?>.value(const {'text': 'final', 'isFinal': true}),
      ),
    );
    final finalSeen = Completer<void>();
    final subscription = platform
        .liveTranscription(request: const LiveTranscriptionRequest())
        .listen((_) => finalSeen.complete());
    await finalSeen.future;
    await stopping.future;
    bool cancelled = false;
    final cancellation = subscription.cancel().then((_) => cancelled = true);
    await Future<void>.delayed(Duration.zero);
    expect(cancelled, isFalse);
    stop.complete(null);
    await cancellation;
    expect(cancelled, isTrue);
  });
}

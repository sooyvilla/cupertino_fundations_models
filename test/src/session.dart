import 'dart:async';

import 'package:cupertino_fundations_models/cupertino_fundations_models.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_helpers.dart';

void main() {
  group('session', () {
    test('delegates requests and resolves tool calls', () async {
      final platform = FakePlatform();
      final session = await platform.createSession(
        options: SessionOptions(
          mode: ModelMode.local,
          tools: <ModelTool>[
            TestTool(name: 'echo', callback: (arguments) => arguments),
          ],
        ),
      );

      expect(session.id, 'session_1');
      expect(session.mode, ModelMode.local);
      expect(
        await session.respond(const Prompt.text('hi')),
        isA<ModelResponse>(),
      );
      expect(
        await session.stream(const Prompt.text('hi')).toList(),
        hasLength(1),
      );
      expect(
        await session.generateStructured(
          prompt: const Prompt.text('hi'),
          schema: testSchema(),
        ),
        isA<ModelResponse>(),
      );
      await session.prewarm(promptPrefix: const Prompt.text('prefix'));
      await session.cancelActiveRequest();
      await session.dispose();

      expect(
        platform.calls,
        containsAll(<String>[
          'respond',
          'stream',
          'generateStructured',
          'prewarm',
          'cancelActiveRequest',
          'disposeSession',
        ]),
      );
      expect(
        (await session.resolveToolCall(
          const ToolCall(
            id: '1',
            name: 'echo',
            arguments: <String, Object?>{'a': 1},
          ),
        )).value,
        <String, Object?>{'a': 1},
      );
      expect(
        (await session.resolveToolCall(
          const ToolCall(
            id: '2',
            name: 'missing',
            arguments: <String, Object?>{},
          ),
        )).isError,
        isTrue,
      );
    });

    test('returns tool failure when a registered tool throws', () async {
      final platform = FakePlatform();
      final session = FoundationModelSession(
        id: 'throwing',
        mode: ModelMode.local,
        platform: platform,
        tools: <ModelTool>[
          TestTool(name: 'boom', callback: (_) => throw StateError('boom')),
        ],
      );

      expect(
        (await session.resolveToolCall(
          const ToolCall(id: '3', name: 'boom', arguments: <String, Object?>{}),
        )).message,
        contains('boom'),
      );
    });

    test('rejects overlapping requests on one session', () async {
      final platform = FakePlatform();
      final completer = Completer<ModelResponse>();
      platform.respondCompleter = completer;
      final session = FoundationModelSession(
        id: 'single-flight',
        mode: ModelMode.local,
        platform: platform,
        tools: const <ModelTool>[],
      );

      final Future<ModelResponse> first = session.respond(
        const Prompt.text('first'),
      );
      await expectLater(
        session.respond(const Prompt.text('second')),
        throwsA(
          isA<FoundationModelsException>().having(
            (FoundationModelsException error) => error.code,
            'code',
            FoundationModelsErrorCode.concurrentRequests,
          ),
        ),
      );

      completer.complete(
        ModelResponse.fromMap(<Object?, Object?>{'text': 'done'}),
      );
      expect((await first).text, 'done');
    });

    test('respond timeout cancels the native request', () async {
      final platform = FakePlatform();
      final completer = Completer<ModelResponse>();
      platform.respondCompleter = completer;
      final session = FoundationModelSession(
        id: 'timeout',
        mode: ModelMode.local,
        platform: platform,
        tools: const <ModelTool>[],
      );

      await expectLater(
        session.respond(
          const Prompt.text('slow'),
          options: const GenerationOptions(timeout: Duration(milliseconds: 5)),
        ),
        throwsA(
          isA<FoundationModelsException>().having(
            (FoundationModelsException error) => error.code,
            'code',
            FoundationModelsErrorCode.generationTimeout,
          ),
        ),
      );
      expect(platform.calls, contains('cancelActiveRequest'));
      completer.complete(
        ModelResponse.fromMap(<Object?, Object?>{'text': 'late'}),
      );
    });

    test('stream timeout cancels the native request', () async {
      final platform = FakePlatform();
      final controller = StreamController<SessionEvent>();
      platform.controlledSessionStream = controller.stream;
      final session = FoundationModelSession(
        id: 'stream-timeout',
        mode: ModelMode.local,
        platform: platform,
        tools: const <ModelTool>[],
      );

      await expectLater(
        session.stream(
          const Prompt.text('slow stream'),
          options: const GenerationOptions(timeout: Duration(milliseconds: 5)),
        ),
        emitsError(
          isA<FoundationModelsException>().having(
            (FoundationModelsException error) => error.code,
            'code',
            FoundationModelsErrorCode.generationTimeout,
          ),
        ),
      );
      expect(platform.calls, contains('cancelActiveRequest'));
      await controller.close();
    });

    test(
      'stream timeout keeps the session busy until cancellation finishes',
      () async {
        final platform = FakePlatform();
        final controller = StreamController<SessionEvent>();
        final cancellation = Completer<void>();
        platform.controlledSessionStream = controller.stream;
        platform.cancelCompleter = cancellation;
        final session = FoundationModelSession(
          id: 'stream-cancelling',
          mode: ModelMode.local,
          platform: platform,
          tools: const <ModelTool>[],
        );
        final errorSeen = Completer<Object>();
        final done = Completer<void>();

        session
            .stream(
              const Prompt.text('slow stream'),
              options: const GenerationOptions(
                timeout: Duration(milliseconds: 5),
              ),
            )
            .listen((_) {}, onError: errorSeen.complete, onDone: done.complete);

        expect(
          await errorSeen.future,
          isA<FoundationModelsException>().having(
            (FoundationModelsException error) => error.code,
            'code',
            FoundationModelsErrorCode.generationTimeout,
          ),
        );
        await expectLater(
          session.respond(const Prompt.text('too early')),
          throwsA(
            isA<FoundationModelsException>().having(
              (FoundationModelsException error) => error.code,
              'code',
              FoundationModelsErrorCode.concurrentRequests,
            ),
          ),
        );

        cancellation.complete();
        await done.future;
        platform.respondCompleter = null;
        expect(
          await session.respond(const Prompt.text('after cancellation')),
          isA<ModelResponse>(),
        );
        await controller.close();
      },
    );

    test('tool timeout returns a bounded failure', () async {
      final platform = FakePlatform();
      final session = FoundationModelSession(
        id: 'tool-timeout',
        mode: ModelMode.local,
        platform: platform,
        tools: <ModelTool>[
          TestTool(
            name: 'slow',
            timeout: const Duration(milliseconds: 5),
            callback: (_) => Completer<Object?>().future,
          ),
        ],
      );

      final ToolResult result = await session.resolveToolCall(
        const ToolCall(
          id: 'slow-1',
          name: 'slow',
          arguments: <String, Object?>{},
        ),
      );
      expect(result.isError, isTrue);
      expect(result.message, contains('timed out'));
    });

    test('disposed sessions reject new work', () async {
      final platform = FakePlatform();
      final session = FoundationModelSession(
        id: 'disposed',
        mode: ModelMode.local,
        platform: platform,
        tools: const <ModelTool>[],
      );
      await session.dispose();

      await expectLater(
        session.respond(const Prompt.text('too late')),
        throwsA(
          isA<FoundationModelsException>().having(
            (FoundationModelsException error) => error.code,
            'code',
            FoundationModelsErrorCode.invalidRequest,
          ),
        ),
      );
    });
  });
}

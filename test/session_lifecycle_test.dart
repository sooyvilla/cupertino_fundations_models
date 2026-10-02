import 'dart:async';
import 'dart:io';

import 'package:cupertino_fundations_models/cupertino_fundations_models.dart';
import 'package:flutter_test/flutter_test.dart';

import 'src/test_helpers.dart';

void main() {
  test(
    'session token operations forward prompt, schema and response allowance',
    () async {
      final platform = FakePlatform();
      final session = await platform.createSession(
        options: const SessionOptions(mode: ModelMode.local),
      );
      expect(await session.countTokens(), session.id.length);
      final budget = await session.measureTokenBudget(
        prompt: const Prompt.text('p'),
        schema: testSchema(),
        options: const GenerationOptions(maximumResponseTokens: 9),
      );
      expect(budget.maximumResponseTokens, 9);
      expect(
        await session
            .streamStructured(
              prompt: const Prompt.text('p'),
              schema: testSchema(),
            )
            .toList(),
        hasLength(2),
      );
      expect(
        platform.calls,
        containsAll(['countSessionTokens', 'measureTokenBudget', 'stream']),
      );
      await session.dispose();
    },
  );

  test(
    'disposal cancels active work once and rejects tool invocations',
    () async {
      final platform = FakePlatform()
        ..respondCompleter = Completer<ModelResponse>();
      final session = await platform.createSession(
        options: const SessionOptions(),
      );
      final response = session.respond(const Prompt.text('pending'));
      final firstDisposal = session.dispose();
      expect(identical(firstDisposal, session.dispose()), isTrue);
      await firstDisposal;
      expect(
        platform.calls.where((value) => value == 'cancelActiveRequest'),
        hasLength(1),
      );
      expect(platform.disposedSessionIds, [session.id]);
      expect(
        (await session.resolveToolCall(
          const ToolCall(id: 't', name: 'echo', arguments: {}),
        )).message,
        contains('disposed'),
      );
      platform.respondCompleter!.complete(
        ModelResponse.fromMap(const {'text': 'late'}),
      );
      await response;
    },
  );

  test(
    'failed cancellation poisons the session and disposal still releases it',
    () async {
      final platform = FakePlatform()
        ..cancelError = const FoundationModelsException(
          code: FoundationModelsErrorCode.nativeFailure,
          message: 'cannot cancel',
        );
      final session = await platform.createSession(
        options: const SessionOptions(),
      );
      await expectLater(
        session.cancelActiveRequest(),
        throwsA(isA<FoundationModelsException>()),
      );
      await expectLater(
        session.countTokens(),
        throwsA(
          isA<FoundationModelsException>().having(
            (e) => e.message,
            'message',
            contains('cancellation'),
          ),
        ),
      );
      await session.dispose();
      expect(platform.disposedSessionIds, [session.id]);
    },
  );

  test('stream cleanup failures require a new session', () async {
    final controller = StreamController<SessionEvent>(
      onCancel: () => throw StateError('cleanup'),
    );
    final platform = FakePlatform()
      ..controlledSessionStream = controller.stream;
    final session = await platform.createSession(
      options: const SessionOptions(),
    );
    final expectation = expectLater(
      session.stream(const Prompt.text('p')),
      emitsInOrder([emitsError(isA<StateError>()), emitsDone]),
    );
    controller.add(
      const CompletionEvent(
        requestId: 'r',
        response: ModelResponse(
          text: 'done',
          usedMode: ModelMode.local,
          metadata: {},
        ),
      ),
    );
    await expectation;
    await expectLater(
      session.respond(const Prompt.text('next')),
      throwsA(
        isA<FoundationModelsException>().having(
          (e) => e.code,
          'code',
          FoundationModelsErrorCode.invalidRequest,
        ),
      ),
    );
    await session.dispose();
    await controller.close();
  });

  for (final failure in <Object>[
    const FoundationModelsException(
      code: FoundationModelsErrorCode.cancelled,
      message: 'cancelled',
    ),
    StateError('unexpected'),
  ]) {
    test(
      'response errors release the session and emit terminal diagnostics: $failure',
      () async {
        final platform = FakePlatform()
          ..respondCompleter = Completer<ModelResponse>();
        final events = <GenerationDiagnosticEvent>[];
        final session = await platform.createSession(
          options: const SessionOptions(),
        );
        final response = session.respond(
          const Prompt.text('fail'),
          options: GenerationOptions(
            diagnostics: GenerationDiagnostics(onEvent: events.add),
          ),
        );
        final expectation = expectLater(response, throwsA(same(failure)));
        platform.respondCompleter!.completeError(failure);
        await expectation;
        final version = RegExp(
          r'^version: (\S+)',
          multiLine: true,
        ).firstMatch(File('pubspec.yaml').readAsStringSync())!.group(1);
        expect(events.first.runtimeMetadata['packageVersion'], version);
        expect(
          events.last.stage,
          failure is FoundationModelsException
              ? GenerationDiagnosticStage.cancelled
              : GenerationDiagnosticStage.failed,
        );
        platform.respondCompleter = null;
        expect(
          (await session.respond(const Prompt.text('next'))).text,
          'response',
        );
        await session.dispose();
      },
    );
  }
}

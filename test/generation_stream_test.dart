import 'dart:async';

import 'package:cupertino_fundations_models/cupertino_fundations_models.dart';
import 'package:cupertino_fundations_models/src/generation_stream.dart';
import 'package:cupertino_fundations_models/src/generation_trace.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late StreamController<SessionEvent> source;
  late List<GenerationDiagnosticEvent> diagnostics;
  late bool sourceListened;
  late int started;
  late int ended;
  late int cancelled;
  late int cancellationFailures;

  setUp(() {
    source = StreamController<SessionEvent>();
    diagnostics = [];
    sourceListened = false;
    started = ended = cancelled = cancellationFailures = 0;
  });

  tearDown(() async {
    if (!sourceListened) {
      source.stream.listen((_) {});
    }
    await source.close();
  });

  GenerationStream generation({
    GenerationOptions options = const GenerationOptions(),
    void Function()? begin,
    Future<void> Function()? cancel,
    Stream<SessionEvent> Function()? events,
  }) {
    return GenerationStream(
      options: options,
      trace: GenerationTrace(
        requestId: 'r',
        sessionId: 's',
        mode: ModelMode.local,
        configuration: GenerationDiagnostics(onEvent: diagnostics.add),
        runtimeMetadata: const {},
      ),
      begin: begin ?? () => started++,
      end: () => ended++,
      cancelNative:
          cancel ??
          () async {
            cancelled++;
          },
      cancellationFailed: () => cancellationFailures++,
      source:
          events ??
          () {
            sourceListened = true;
            return source.stream;
          },
    );
  }

  test(
    'first response timeout cancels work and reports the deadline phase',
    () async {
      final stream = generation(
        options: const GenerationOptions(
          firstResponseTimeout: Duration(milliseconds: 10),
        ),
      ).stream;
      await expectLater(
        stream,
        emitsInOrder([
          emitsError(
            isA<FoundationModelsException>().having(
              (e) => e.details['timeoutPhase'],
              'phase',
              'firstResponse',
            ),
          ),
          emitsDone,
        ]),
      );
      expect(cancelled, 1);
      expect(ended, 1);
    },
  );

  test(
    'total deadline remains active while snapshots reset the idle deadline',
    () async {
      final stream = generation(
        options: const GenerationOptions(
          totalTimeout: Duration(milliseconds: 20),
          idleTimeout: Duration(seconds: 1),
        ),
      ).stream;
      final expectation = expectLater(
        stream,
        emitsInOrder([
          isA<TextSnapshotEvent>(),
          emitsError(
            isA<FoundationModelsException>().having(
              (e) => e.details['timeoutPhase'],
              'phase',
              'total',
            ),
          ),
          emitsDone,
        ]),
      );
      source.add(const TextSnapshotEvent(requestId: 'native', text: 'partial'));
      await expectation;
      expect(diagnostics.last.nativeRequestId, 'native');
    },
  );

  test('idle timeout follows the first snapshot', () async {
    final stream = generation(
      options: const GenerationOptions(
        firstResponseTimeout: Duration(seconds: 1),
        idleTimeout: Duration(milliseconds: 10),
      ),
    ).stream;
    final expectation = expectLater(
      stream,
      emitsInOrder([
        isA<TextSnapshotEvent>(),
        emitsError(
          isA<FoundationModelsException>().having(
            (e) => e.details['timeoutPhase'],
            'phase',
            'idle',
          ),
        ),
        emitsDone,
      ]),
    );
    source.add(const TextSnapshotEvent(requestId: 'native', text: 'partial'));
    await expectation;
    expect(cancelled, 1);
  });

  test('tool activity does not satisfy the first response deadline', () async {
    final stream = generation(
      options: const GenerationOptions(
        firstResponseTimeout: Duration(milliseconds: 10),
      ),
    ).stream;
    final expectation = expectLater(
      stream,
      emitsInOrder([
        isA<ToolCallEvent>(),
        emitsError(isA<FoundationModelsException>()),
        emitsDone,
      ]),
    );
    source.add(
      const ToolCallEvent(
        requestId: 'r',
        toolCallId: 't',
        name: 'lookup',
        arguments: {},
      ),
    );
    await expectation;
  });

  test(
    'premature source closure fails and cancels the native request',
    () async {
      final expectation = expectLater(
        generation().stream,
        emitsInOrder([
          emitsError(
            isA<FoundationModelsException>().having(
              (e) => e.details['streamClosedWithoutResult'],
              'missing result',
              true,
            ),
          ),
          emitsDone,
        ]),
      );
      await source.close();
      await expectation;
      expect(cancelled, 1);
      expect(ended, 1);
    },
  );

  for (final code in ['nativeFailure', 'future']) {
    test(
      'native failure events remain terminal and preserve the error code: $code',
      () async {
        final expectation = expectLater(
          generation().stream,
          emitsInOrder([isA<FailureEvent>(), emitsDone]),
        );
        source.add(
          FailureEvent(requestId: 'native', code: code, message: 'failed'),
        );
        await expectation;
        expect(
          diagnostics.last.errorCode,
          code == 'future'
              ? FoundationModelsErrorCode.unknown
              : FoundationModelsErrorCode.nativeFailure,
        );
        expect(ended, 1);
        expect(cancelled, 0);
      },
    );
  }

  test(
    'request admission failures never cancel another native request',
    () async {
      await expectLater(
        generation(begin: () => throw StateError('busy')).stream,
        emitsInOrder([emitsError(isA<StateError>()), emitsDone]),
      );
      expect(started, 0);
      expect(ended, 0);
      expect(cancelled, 0);
      expect(diagnostics, isEmpty);
    },
  );

  test('invalid stream options are rejected before admission', () async {
    await expectLater(
      generation(
        options: const GenerationOptions(timeout: Duration.zero),
      ).stream,
      emitsInOrder([emitsError(isA<ArgumentError>()), emitsDone]),
    );
    expect(started, 0);
  });

  test('synchronous source creation failures cancel admitted work', () async {
    await expectLater(
      generation(events: () => throw StateError('source')).stream,
      emitsInOrder([emitsError(isA<StateError>()), emitsDone]),
    );
    expect(cancelled, 1);
    expect(ended, 1);
  });

  test('native cancellation errors surface and block session reuse', () async {
    await expectLater(
      generation(
        options: const GenerationOptions(timeout: Duration(milliseconds: 10)),
        cancel: () async => throw StateError('cancel'),
      ).stream,
      emitsInOrder([
        emitsError(isA<FoundationModelsException>()),
        emitsError(isA<StateError>()),
        emitsDone,
      ]),
    );
    expect(cancellationFailures, 1);
    expect(ended, 1);
  });

  test(
    'terminal cleanup errors surface without delivering a successful result',
    () async {
      final failingSource = StreamController<SessionEvent>(
        onCancel: () => throw StateError('cleanup'),
      );
      final expectation = expectLater(
        generation(events: () => failingSource.stream).stream,
        emitsInOrder([emitsError(isA<StateError>()), emitsDone]),
      );
      failingSource.add(
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
      expect(cancellationFailures, 1);
      expect(ended, 1);
      await failingSource.close();
    },
  );

  test('subscription cancellation stops native work once', () async {
    final subscription = generation().stream.listen((_) {});
    await subscription.cancel();
    expect(cancelled, 1);
    expect(ended, 1);
    expect(diagnostics.last.stage, GenerationDiagnosticStage.cancelled);
  });

  test(
    'source cancellation errors retain their terminal classification',
    () async {
      final expectation = expectLater(
        generation().stream,
        emitsInOrder([emitsError(isA<FoundationModelsException>()), emitsDone]),
      );
      source.addError(
        const FoundationModelsException(
          code: FoundationModelsErrorCode.cancelled,
          message: 'cancelled',
        ),
      );
      await expectation;
      expect(diagnostics.last.stage, GenerationDiagnosticStage.cancelled);
      expect(cancelled, 0);
      expect(ended, 1);
    },
  );
}

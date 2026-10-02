import 'package:cupertino_fundations_models/cupertino_fundations_models.dart';
import 'package:cupertino_fundations_models/src/generation_trace.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('diagnostics redact output by default and freeze runtime metadata', () {
    final events = <GenerationDiagnosticEvent>[];
    final metadata = <String, Object?>{'platform': 'macos'};
    final trace = GenerationTrace(
      requestId: 'r',
      sessionId: 's',
      mode: ModelMode.local,
      configuration: GenerationDiagnostics(onEvent: events.add),
      runtimeMetadata: metadata,
    );
    metadata['platform'] = 'ios';
    trace.emit(GenerationDiagnosticStage.started);
    trace.nativeRequestId = 'native';
    trace.emit(GenerationDiagnosticStage.snapshot, output: 'private');
    trace.emit(
      GenerationDiagnosticStage.completed,
      output: 'private',
      usage: const ModelUsage(
        inputTokenCount: 1,
        cachedInputTokenCount: 0,
        outputTokenCount: 2,
        reasoningTokenCount: 0,
        totalTokenCount: 3,
      ),
      termination: const GenerationTermination(
        status: GenerationStatus.completed,
      ),
    );
    expect(events.map((e) => e.stage), [
      GenerationDiagnosticStage.started,
      GenerationDiagnosticStage.snapshot,
      GenerationDiagnosticStage.completed,
    ]);
    expect(events.first.firstResponseLatency, isNull);
    expect(events.last.firstResponseLatency, events[1].firstResponseLatency);
    expect(events.last.output, isNull);
    expect(events.last.nativeRequestId, 'native');
    expect(events.last.usage!.totalTokenCount, 3);
    expect(events.last.termination!.status, GenerationStatus.completed);
    expect(events.last.runtimeMetadata['platform'], 'macos');
    expect(trace.runtimeMetadata.clear, throwsUnsupportedError);
  });

  test('output capture retains bounded output and omits oversized output', () {
    final events = <GenerationDiagnosticEvent>[];
    final trace = GenerationTrace(
      requestId: 'r',
      sessionId: 's',
      mode: ModelMode.privateCloudCompute,
      configuration: GenerationDiagnostics(
        onEvent: events.add,
        captureOutput: true,
        maximumOutputCharacters: 3,
      ),
      runtimeMetadata: const {},
    );
    trace.emit(GenerationDiagnosticStage.snapshot, output: 'abc');
    trace.emit(GenerationDiagnosticStage.completed, output: 'abcd');
    trace.emit(
      GenerationDiagnosticStage.failed,
      errorCode: FoundationModelsErrorCode.nativeFailure,
    );
    expect(events.first.output, 'abc');
    expect(events.first.outputOmitted, isFalse);
    expect(events[1].output, isNull);
    expect(events[1].outputOmitted, isTrue);
    expect(events.last.errorCode, FoundationModelsErrorCode.nativeFailure);
  });

  test('diagnostic callback failures cannot interrupt generation', () {
    final trace = GenerationTrace(
      requestId: 'r',
      sessionId: 's',
      mode: ModelMode.local,
      configuration: GenerationDiagnostics(
        onEvent: (_) => throw StateError('callback'),
      ),
      runtimeMetadata: const {},
    );
    expect(
      () => trace.emit(GenerationDiagnosticStage.started),
      returnsNormally,
    );
  });
}

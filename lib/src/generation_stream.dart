import 'dart:async';

import 'errors.dart';
import 'generation.dart';
import 'generation_diagnostic_event.dart';
import 'generation_termination.dart';
import 'generation_trace.dart';

final class GenerationStream {
  GenerationStream({
    required this.options,
    required this.trace,
    required this.begin,
    required this.end,
    required this.cancelNative,
    required this.cancellationFailed,
    required this.source,
  });

  final GenerationOptions options;
  final GenerationTrace trace;
  final void Function() begin;
  final void Function() end;
  final Future<void> Function() cancelNative;
  final void Function() cancellationFailed;
  final Stream<SessionEvent> Function() source;
  StreamSubscription<SessionEvent>? _subscription;
  Timer? _activityTimer;
  Timer? _totalTimer;
  Future<void>? _cleanup;
  bool _started = false;
  bool _settled = false;
  bool _hasResponse = false;
  late final StreamController<SessionEvent> _controller =
      StreamController<SessionEvent>(onListen: _listen, onCancel: _cancel);

  Stream<SessionEvent> get stream => _controller.stream;

  void _listen() {
    try {
      options.toMap();
      begin();
      _started = true;
      trace.emit(GenerationDiagnosticStage.started);
      _armActivity();
      final total = options.totalTimeout;
      if (total != null) {
        _totalTimer = Timer(
          total,
          () => _timeout(GenerationTimeoutPhase.total, total),
        );
      }
      _subscription = source().listen(
        _event,
        onError: (Object error, StackTrace stack) => _fail(error, stack),
        onDone: () {
          if (!_settled) {
            _fail(const FoundationModelsException(
              code: FoundationModelsErrorCode.nativeFailure,
              message: 'The stream closed without a terminal event.',
              details: <String, Object?>{'streamClosedWithoutResult': true},
            ), StackTrace.current, cancel: true);
          }
        },
      );
    } on Object catch (error, stack) {
      _fail(error, stack, cancel: _started);
    }
  }

  void _armActivity() {
    _activityTimer?.cancel();
    final bool first = !_hasResponse && options.firstResponseTimeout != null;
    final duration = first
        ? options.firstResponseTimeout!
        : options.idleTimeout ?? options.timeout;
    _activityTimer = Timer(
      duration,
      () => _timeout(
        first ? GenerationTimeoutPhase.firstResponse : GenerationTimeoutPhase.idle,
        duration,
      ),
    );
  }

  void _event(SessionEvent event) {
    if (_settled) {
      return;
    }
    if (event is TextSnapshotEvent) {
      _hasResponse = true;
      trace.nativeRequestId = event.requestId;
      trace.emit(GenerationDiagnosticStage.snapshot, output: event.text);
    }
    if (event is CompletionEvent || event is FailureEvent) {
      _settled = true;
      _stopTimers();
      unawaited(_complete(event));
      return;
    }
    if (_hasResponse || options.firstResponseTimeout == null) {
      _armActivity();
    }
    _controller.add(event);
  }

  Future<void> _complete(SessionEvent event) async {
    try {
      await _clean(cancel: false);
      if (event is CompletionEvent) {
        trace.nativeRequestId = event.requestId;
        trace.emit(
          GenerationDiagnosticStage.completed,
          output: event.response.text,
          usage: event.response.usage,
          termination: event.response.termination,
        );
      } else if (event is FailureEvent) {
        trace.nativeRequestId = event.requestId;
        trace.emit(
          GenerationDiagnosticStage.failed,
          termination: event.termination,
          errorCode: FoundationModelsErrorCode.values.firstWhere(
            (value) => value.name == event.code,
            orElse: () => FoundationModelsErrorCode.unknown,
          ),
        );
      }
      if (!_controller.isClosed) {
        _controller.add(event);
      }
    } on Object catch (error, stack) {
      if (!_controller.isClosed) {
        _controller.addError(error, stack);
      }
    } finally {
      unawaited(_controller.close());
    }
  }

  void _timeout(GenerationTimeoutPhase phase, Duration duration) {
    _fail(
      FoundationModelsException(
        code: FoundationModelsErrorCode.generationTimeout,
        message: 'Generation ${phase.name} timeout after ${duration.inMilliseconds}ms.',
        details: <String, Object?>{'timeoutPhase': phase.name},
      ),
      StackTrace.current,
      cancel: true,
    );
  }

  void _fail(Object error, StackTrace stack, {bool cancel = false}) {
    if (_settled) {
      return;
    }
    _settled = true;
    _stopTimers();
    final failure = error is FoundationModelsException ? error : null;
    if (_started) {
      trace.emit(
        failure?.code == FoundationModelsErrorCode.cancelled
            ? GenerationDiagnosticStage.cancelled
            : GenerationDiagnosticStage.failed,
        errorCode: failure?.code ?? FoundationModelsErrorCode.unknown,
        termination: failure?.termination ??
            const GenerationTermination(status: GenerationStatus.failed),
      );
    }
    _controller.addError(error, stack);
    unawaited(_finishFailure(cancel: cancel));
  }

  Future<void> _finishFailure({required bool cancel}) async {
    try {
      await _clean(cancel: cancel);
    } on Object catch (error, stack) {
      if (!_controller.isClosed) {
        _controller.addError(error, stack);
      }
    } finally {
      unawaited(_controller.close());
    }
  }

  Future<void> _cancel() {
    final cancel = !_settled;
    if (cancel) {
      _settled = true;
      trace.emit(
        GenerationDiagnosticStage.cancelled,
        termination: const GenerationTermination(
          status: GenerationStatus.cancelled,
          reason: GenerationStopReason.cancelled,
        ),
      );
    }
    return _clean(cancel: cancel);
  }

  Future<void> _clean({required bool cancel}) =>
      _cleanup ??= _performCleanup(cancel: cancel);

  Future<void> _performCleanup({required bool cancel}) async {
    _stopTimers();
    try {
      try {
        if (cancel && _started) {
          await cancelNative();
        }
      } finally {
        await _subscription?.cancel();
      }
    } on Object {
      if (_started) {
        cancellationFailed();
      }
      rethrow;
    } finally {
      if (_started) {
        end();
      }
    }
  }

  void _stopTimers() {
    _activityTimer?.cancel();
    _totalTimer?.cancel();
  }
}

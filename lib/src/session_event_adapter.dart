import 'dart:async';

import 'adapted_session_event.dart';
import 'errors.dart';
import 'generation.dart';
import 'text_snapshot_reducer.dart';
import 'text_update.dart';

/// Owns adaptation/cleanup for one request without changing native session policy.
final class SessionEventAdapter {
  /// Creates a cold stream; optional disposal is used only for an explicitly owned session.
  SessionEventAdapter({required FutureOr<Stream<SessionEvent>> Function() source,
    Future<void> Function()? dispose, bool allowReplacements = true})
      : _source = source, _dispose = dispose, _allowReplacements = allowReplacements {
    _controller = StreamController<AdaptedSessionEvent>(onListen: _listen,
      onPause: () { _paused = true; _subscription?.pause(); },
      onResume: () { _paused = false; _subscription?.resume(); }, onCancel: _cancel);
  }
  final FutureOr<Stream<SessionEvent>> Function() _source;
  final Future<void> Function()? _dispose;
  final bool _allowReplacements;
  final _reducer = TextSnapshotReducer();
  late final StreamController<AdaptedSessionEvent> _controller;
  StreamSubscription<SessionEvent>? _subscription;
  Future<void>? _starting;
  Future<void>? _cleanup;
  String? _requestId;
  bool _settled = false;
  bool _cancelled = false;
  bool _paused = false;
  /// Single-subscription stream; cancellation awaits source cleanup and owned disposal.
  Stream<AdaptedSessionEvent> get stream => _controller.stream;

  void _listen() {
    _starting = () async {
      try {
        final source = await _source();
        if (_settled) return;
        _subscription = source.listen(_event, onError: (Object error, StackTrace stack) {
          _fail(error, stack);
        }, onDone: () {
          if (!_settled) {
            _fail(const FoundationModelsException(code: FoundationModelsErrorCode.nativeFailure,
              message: 'The adapted stream closed without a terminal event.', details: {'adapterStage': 'missingTerminal'}), StackTrace.current);
          }
        });
        if (_paused) _subscription!.pause();
      } on Object catch (error, stack) { _fail(error, stack); }
    }();
  }

  void _event(SessionEvent event) {
    if (_settled) return;
    try {
      final id = switch (event) {
        TextSnapshotEvent(:final requestId) || ToolCallEvent(:final requestId) ||
        CompletionEvent(:final requestId) || FailureEvent(:final requestId) => requestId,
        UnknownSessionEvent() => null,
      };
      if (id != null && id.isNotEmpty) {
        if (_requestId != null && _requestId != id) {
          throw const FoundationModelsException(code: FoundationModelsErrorCode.invalidRequest,
            message: 'Adapt one request per stream.', details: {'adapterStage': 'mixedRequests'});
        }
        _requestId = id;
      }
      final text = switch (event) {
        TextSnapshotEvent(:final text) => text,
        CompletionEvent(:final response) => response.text,
        _ => null,
      };
      final update = text == null ? null : _reducer.next(text);
      if (!_allowReplacements && update?.kind == TextUpdateKind.replace) {
        throw const FoundationModelsException(code: FoundationModelsErrorCode.unsupportedCapability,
          message: 'This consumer cannot represent a revised text snapshot.', details: {'adapterStage': 'textRevision'});
      }
      final adapted = AdaptedSessionEvent(original: event, textUpdate: update);
      if (adapted.isTerminal) {
        _settled = true;
        unawaited(_finish(adapted));
      } else { _controller.add(adapted); }
    } on Object catch (error, stack) { _fail(error, stack); }
  }

  void _fail(Object error, StackTrace stack) {
    if (_settled) return;
    _settled = true;
    _controller.addError(error, stack);
    unawaited(_finish(null));
  }

  Future<void> _finish(AdaptedSessionEvent? terminal) async {
    try {
      await _clean();
      if (!_cancelled && terminal != null) _controller.add(terminal);
    } on Object catch (error, stack) {
      if (!_cancelled) _controller.addError(error, stack);
    } finally { unawaited(_controller.close()); }
  }

  Future<void> _cancel() {
    final closing = _controller.isClosed;
    _cancelled = true;
    _settled = true;
    if (closing) return _clean().catchError((Object _) {});
    return _clean();
  }

  Future<void> _clean() => _cleanup ??= () async {
    await _starting;
    try { await _subscription?.cancel(); }
    finally { await _dispose?.call(); }
  }();
}

/// Opt-in adaptation for a borrowed session or another single-request event source.
extension FoundationModelsEventAdapters on Stream<SessionEvent> {
  /// Preserves original events and propagates pause, errors and awaited cancellation.
  /// Set allowReplacements false for an append-only consumer; revisions fail explicitly.
  Stream<AdaptedSessionEvent> adaptEvents({bool allowReplacements = true}) =>
    SessionEventAdapter(source: () => this, allowReplacements: allowReplacements).stream;
}

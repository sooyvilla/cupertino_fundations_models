import 'dart:async';

import 'package:flutter/widgets.dart';

import 'availability.dart';
import 'errors.dart';
import 'history_payload.dart';

/// Owns one cold availability subscription and its foreground/pause lifecycle.
final class AvailabilityWatch with WidgetsBindingObserver {
  /// Creates a monitor without native work until its stream is listened to.
  AvailabilityWatch({required Stream<ModelAvailability> Function() source,
    required bool pauseWhenBackgrounded}) : _source = source, _pauseWhenBackgrounded = pauseWhenBackgrounded {
    _controller = StreamController<ModelAvailability>(onListen: _listen,
      onPause: () { _paused = true; _update(); },
      onResume: () { _paused = false; _update(); }, onCancel: _onCancel);
  }

  final Stream<ModelAvailability> Function() _source;
  final bool _pauseWhenBackgrounded;
  late final StreamController<ModelAvailability> _controller;
  // ignore: cancel_subscriptions
  StreamSubscription<ModelAvailability>? _subscription;
  Future<void> _transition = Future<void>.value();
  WidgetsBinding? _binding;
  Object? _previous;
  int _epoch = 0;
  bool _paused = false;
  bool _backgrounded = false;
  bool _closed = false;
  Future<void>? _cleanup;

  /// Single-subscription stream; cancel and await it when its owner is released.
  Stream<ModelAvailability> get stream => _controller.stream;

  void _listen() {
    if (_pauseWhenBackgrounded) {
      _binding = WidgetsBinding.instance;
      _binding!.addObserver(this);
      final state = _binding!.lifecycleState;
      _backgrounded = state != null && state != AppLifecycleState.resumed;
    }
    _update();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _backgrounded = state != AppLifecycleState.resumed;
    _update();
  }

  void _update() {
    final epoch = ++_epoch;
    final previous = _subscription;
    _subscription = null;
    _transition = _transition.then((_) async {
      await previous?.cancel();
      if (_closed || _paused || _backgrounded || epoch != _epoch) return;
      _subscription = _source().listen((value) {
        if (_closed || epoch != _epoch) return;
        try {
          final snapshot = HistoryPayload.freeze(value.toMap());
          if (HistoryPayload.equal(_previous, snapshot)) return;
          _previous = snapshot;
          _controller.add(ModelAvailability.fromMap(snapshot! as Map<String, Object?>));
        } on Object catch (_, stack) {
          _fail(const FoundationModelsException(code: FoundationModelsErrorCode.parsingFailure,
            message: 'The local availability snapshot is malformed.'), stack);
        }
      }, onError: (Object error, StackTrace stack) {
        if (!_closed && epoch == _epoch) _fail(error, stack);
      }, onDone: () {
        if (!_closed && epoch == _epoch) _finish();
      });
    }).catchError((Object error, StackTrace stack) {
      if (_closed) Error.throwWithStackTrace(error, stack);
      _fail(error, stack);
    });
  }

  void _fail(Object error, StackTrace stack) {
    if (_closed) return;
    if (error is FoundationModelsException && error.code == FoundationModelsErrorCode.unsupportedPlatform) {
      _controller.add(ModelAvailability(mode: ModelMode.local, status: AvailabilityStatus.unsupportedPlatform,
        isAvailable: false, supportsFullPower: false, reason: error.message,
        recoverySuggestion: error.recoverySuggestion));
    } else { _controller.addError(error, stack); }
    _finish();
  }

  void _finish() {
    unawaited(_cancel().then((_) { unawaited(_controller.close()); }, onError: (Object error, StackTrace stack) {
      _controller.addError(error, stack);
      unawaited(_controller.close());
    }));
  }

  Future<void> _onCancel() async {
    final controllerClosing = _controller.isClosed;
    try { await _cancel(); }
    on Object { if (!controllerClosing) rethrow; }
  }

  Future<void> _cancel() {
    if (_cleanup != null) return _cleanup!;
    _closed = true;
    ++_epoch;
    _binding?.removeObserver(this);
    final previous = _subscription;
    _subscription = null;
    return _cleanup = () async {
      await _transition;
      await previous?.cancel();
    }();
  }
}

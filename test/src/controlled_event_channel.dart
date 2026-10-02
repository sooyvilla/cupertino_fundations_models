import 'package:flutter/services.dart';

final class ControlledEventChannel extends EventChannel {
  ControlledEventChannel(Stream<Object?> stream)
    : events = (() => stream),
      super('test/transcription');

  const ControlledEventChannel.factory(this.events)
    : super('test/transcription');

  final Stream<Object?> Function() events;

  @override
  Stream<dynamic> receiveBroadcastStream([dynamic arguments]) => events();
}

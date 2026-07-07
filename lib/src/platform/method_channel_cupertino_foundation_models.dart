import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';

import '../availability.dart';
import '../errors.dart';
import '../file_selection.dart';
import '../generation.dart';
import '../schema.dart';
import '../session.dart';
import '../tools.dart';
import '../transcription.dart';
import 'cupertino_foundation_models_platform.dart';

/// MethodChannel implementation for Apple platforms.
final class MethodChannelCupertinoFoundationModels
    implements CupertinoFoundationModelsPlatform {
  MethodChannelCupertinoFoundationModels({
    MethodChannel? methodChannel,
    EventChannel? eventChannel,
    EventChannel? transcriptionEventChannel,
  }) : _methodChannel =
           methodChannel ??
           const MethodChannel('cupertino_fundations_models/methods'),
       _eventChannel =
           eventChannel ??
           const EventChannel('cupertino_fundations_models/events'),
       _transcriptionEventChannel =
           transcriptionEventChannel ??
           const EventChannel(
             'cupertino_fundations_models/transcription_events',
           ) {
    _methodChannel.setMethodCallHandler(_handleNativeCall);
  }

  final MethodChannel _methodChannel;
  final EventChannel _eventChannel;
  final EventChannel _transcriptionEventChannel;
  final Map<String, FoundationModelSession> _liveSessions =
      <String, FoundationModelSession>{};

  @override
  Future<FoundationModelsCapabilities> getCapabilities() async {
    final Object? response = await _invoke('getCapabilities');
    return FoundationModelsCapabilities.fromMap(_asMap(response));
  }

  @override
  Future<FoundationModelsDiagnostics> getDiagnostics({
    required String? localeIdentifier,
  }) async {
    final Object? response = await _invoke('getDiagnostics', <String, Object?>{
      'localeIdentifier': localeIdentifier,
    });
    return FoundationModelsDiagnostics.fromMap(_asMap(response));
  }

  @override
  Future<ModelAvailability> checkAvailability({
    required ModelMode mode,
    required CloudPolicy cloudPolicy,
    required String? localeIdentifier,
  }) async {
    final Object? response =
        await _invoke('checkAvailability', <String, Object?>{
          'mode': mode.name,
          'cloudPolicy': cloudPolicy.name,
          'localeIdentifier': localeIdentifier,
        });
    return ModelAvailability.fromMap(_asMap(response));
  }

  @override
  Future<FoundationModelSession> createSession({
    required SessionOptions options,
  }) async {
    final Object? response = await _invoke('createSession', options.toMap());
    final Map<Object?, Object?> map = _asMap(response);
    final String sessionId = (map['sessionId'] as String?) ?? '';
    final String modeName = (map['mode'] as String?) ?? options.mode.name;

    final FoundationModelSession session = FoundationModelSession(
      id: sessionId,
      mode: _modeFromName(modeName),
      platform: this,
      tools: options.tools,
    );
    if (options.tools.isNotEmpty) {
      _liveSessions[sessionId] = session;
    }
    return session;
  }

  @override
  Future<PickedFoundationModelsFile?> pickFile({
    required FoundationModelsFileKind kind,
  }) async {
    final Object? response = await _invoke('pickFile', <String, Object?>{
      'kind': kind.name,
    });
    if (response == null) {
      return null;
    }
    return PickedFoundationModelsFile.fromMap(_asMap(response));
  }

  @override
  Future<AudioTranscriptionResult> transcribeAudio({
    required AudioTranscriptionRequest request,
  }) async {
    final Object? response = await _invoke('transcribeAudio', request.toMap());
    return AudioTranscriptionResult.fromMap(_asMap(response));
  }

  @override
  Stream<LiveTranscriptionEvent> liveTranscription({
    required LiveTranscriptionRequest request,
  }) {
    final Stream<Object?> nativeStream = _transcriptionEventChannel
        .receiveBroadcastStream(request.toMap())
        .cast<Object?>();
    return nativeStream.transform<LiveTranscriptionEvent>(
      StreamTransformer<Object?, LiveTranscriptionEvent>.fromHandlers(
        handleData: (Object? event, EventSink<LiveTranscriptionEvent> sink) {
          final LiveTranscriptionEvent parsed = LiveTranscriptionEvent.fromMap(
            _asMap(event),
          );
          sink.add(parsed);
          if (parsed.isFinal) {
            sink.close();
          }
        },
        handleError:
            (
              Object error,
              StackTrace stackTrace,
              EventSink<LiveTranscriptionEvent> sink,
            ) {
              if (error is PlatformException) {
                sink.addError(
                  FoundationModelsException.fromPlatformException(error),
                  stackTrace,
                );
                return;
              }
              sink.addError(error, stackTrace);
            },
      ),
    );
  }

  @override
  Future<ModelResponse> respond({
    required String sessionId,
    required Prompt prompt,
    required GenerationOptions options,
  }) async {
    final Object? response = await _invoke('respond', <String, Object?>{
      'sessionId': sessionId,
      'prompt': prompt.toMap(),
      'options': options.toMap(),
    });
    return ModelResponse.fromMap(_asMap(response));
  }

  @override
  Stream<SessionEvent> stream({
    required String sessionId,
    required Prompt prompt,
    required GenerationOptions options,
  }) {
    final String requestId = _createRequestId();
    final Map<String, Object?> arguments = <String, Object?>{
      'sessionId': sessionId,
      'requestId': requestId,
      'prompt': prompt.toMap(),
      'options': options.toMap(),
    };

    final Stream<Object?> nativeStream = _eventChannel
        .receiveBroadcastStream(arguments)
        .cast<Object?>();
    return nativeStream.transform<SessionEvent>(
      StreamTransformer<Object?, SessionEvent>.fromHandlers(
        handleData: (Object? event, EventSink<SessionEvent> sink) {
          final SessionEvent parsed = SessionEvent.fromMap(_asMap(event));
          sink.add(parsed);
          if (parsed is CompletionEvent || parsed is FailureEvent) {
            sink.close();
          }
        },
        handleError:
            (
              Object error,
              StackTrace stackTrace,
              EventSink<SessionEvent> sink,
            ) {
              if (error is PlatformException) {
                sink.addError(
                  FoundationModelsException.fromPlatformException(error),
                  stackTrace,
                );
                return;
              }
              sink.addError(error, stackTrace);
            },
      ),
    );
  }

  @override
  Future<ModelResponse> generateStructured({
    required String sessionId,
    required Prompt prompt,
    required StructuredSchema schema,
    required GenerationOptions options,
  }) async {
    final Object? response =
        await _invoke('generateStructured', <String, Object?>{
          'sessionId': sessionId,
          'prompt': prompt.toMap(),
          'schema': schema.toMap(),
          'options': options.toMap(),
        });
    return ModelResponse.fromMap(_asMap(response));
  }

  @override
  Future<void> prewarm({
    required String sessionId,
    required Prompt? promptPrefix,
  }) async {
    await _invoke<void>('prewarm', <String, Object?>{
      'sessionId': sessionId,
      'promptPrefix': promptPrefix?.toMap(),
    });
  }

  @override
  Future<void> cancelActiveRequest({required String sessionId}) async {
    await _invoke<void>('cancelActiveRequest', <String, Object?>{
      'sessionId': sessionId,
    });
  }

  @override
  Future<void> disposeSession({required String sessionId}) async {
    _liveSessions.remove(sessionId);
    await _invoke<void>('disposeSession', <String, Object?>{
      'sessionId': sessionId,
    });
  }

  /// Handles calls initiated by the native side, currently tool invocations.
  Future<Object?> _handleNativeCall(MethodCall call) async {
    if (call.method != 'toolCall') {
      return null;
    }

    final Map<Object?, Object?> arguments = _asMap(call.arguments);
    final String sessionId = (arguments['sessionId'] as String?) ?? '';
    final String name = (arguments['name'] as String?) ?? '';
    final FoundationModelSession? session = _liveSessions[sessionId];
    if (session == null) {
      return const ToolResult.failure(
        'No live session with registered tools was found.',
      ).toMap();
    }

    final ToolResult result = await session.resolveToolCall(
      ToolCall(
        id: (arguments['toolCallId'] as String?) ?? '',
        name: name,
        arguments: _decodeToolArguments(arguments['argumentsJson'] as String?),
      ),
    );
    return result.toMap();
  }

  Map<String, Object?> _decodeToolArguments(String? argumentsJson) {
    if (argumentsJson == null || argumentsJson.isEmpty) {
      return <String, Object?>{};
    }
    try {
      final Object? decoded = jsonDecode(argumentsJson);
      if (decoded is Map<String, dynamic>) {
        return decoded.cast<String, Object?>();
      }
      return <String, Object?>{'value': decoded};
    } on FormatException {
      return <String, Object?>{'raw': argumentsJson};
    }
  }

  Future<T?> _invoke<T>(String method, [Object? arguments]) async {
    try {
      final T? response = await _methodChannel.invokeMethod<T>(
        method,
        arguments,
      );
      return response;
    } on PlatformException catch (exception) {
      throw FoundationModelsException.fromPlatformException(exception);
    }
  }

  Map<Object?, Object?> _asMap(Object? value) {
    if (value is Map<Object?, Object?>) {
      return value;
    }
    return <Object?, Object?>{};
  }

  String _createRequestId() {
    final int micros = DateTime.now().microsecondsSinceEpoch;
    return 'request_$micros';
  }

  ModelMode _modeFromName(String name) {
    for (final ModelMode value in ModelMode.values) {
      if (value.name == name) {
        return value;
      }
    }
    return ModelMode.local;
  }
}

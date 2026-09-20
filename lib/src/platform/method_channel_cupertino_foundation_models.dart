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
    EventChannel? transcriptionEventChannel,
  }) : _methodChannel =
           methodChannel ??
           const MethodChannel('cupertino_fundations_models/methods'),
       _transcriptionEventChannel =
           transcriptionEventChannel ??
           const EventChannel(
             'cupertino_fundations_models/transcription_events',
           ) {
    _methodChannel.setMethodCallHandler(_handleNativeCall);
  }

  final MethodChannel _methodChannel;
  final EventChannel _transcriptionEventChannel;
  final Map<String, FoundationModelSession> _liveSessions =
      <String, FoundationModelSession>{};
  final Map<String, _ActiveGenerationStream> _activeStreams =
      <String, _ActiveGenerationStream>{};
  int _requestSequence = 0;
  bool _liveTranscriptionActive = false;

  @override
  Future<FoundationModelsCapabilities> getCapabilities() async {
    final Object? response = await _invoke('getCapabilities');
    return FoundationModelsCapabilities.fromMap(_asMap(response));
  }

  @override
  Future<List<FoundationModelsLanguage>> getSupportedLanguages() async {
    final Object? response = await _invoke('getSupportedLanguages');
    final List<Object?> values = response is List<Object?>
        ? response
        : <Object?>[];
    return values
        .whereType<Map<Object?, Object?>>()
        .map(FoundationModelsLanguage.fromMap)
        .toList(growable: false);
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
  Future<int> countTokens({required Prompt prompt}) async {
    final int? response = await _invoke<int>('countTokens', <String, Object?>{
      'target': 'prompt',
      'prompt': prompt.toMap(),
    });
    return response ?? 0;
  }

  @override
  Future<int> countSessionTokens({required String sessionId}) async {
    final int? response = await _invoke<int>('countTokens', <String, Object?>{
      'target': 'transcript',
      'sessionId': sessionId,
    });
    return response ?? 0;
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
    final String requestId = _createRequestId();
    try {
      final Object? response = await _invoke<Object?>(
        'transcribeAudio',
        <String, Object?>{...request.toMap(), 'requestId': requestId},
      ).timeout(request.timeout);
      return AudioTranscriptionResult.fromMap(_asMap(response));
    } on TimeoutException {
      try {
        await _invoke<void>('cancelTranscription', <String, Object?>{
          'requestId': requestId,
        });
      } on FoundationModelsException {
        // The timeout remains the actionable failure for the caller.
      }
      throw FoundationModelsException(
        code: FoundationModelsErrorCode.transcriptionTimeout,
        message:
            'Audio transcription did not finish within '
            '${request.timeout.inMilliseconds}ms.',
        recoverySuggestion:
            'Retry after speech assets finish downloading, use a shorter file, '
            'or increase AudioTranscriptionRequest.timeout.',
      );
    }
  }

  @override
  Stream<LiveTranscriptionEvent> liveTranscription({
    required LiveTranscriptionRequest request,
  }) async* {
    if (_liveTranscriptionActive) {
      throw const FoundationModelsException(
        code: FoundationModelsErrorCode.concurrentRequests,
        message: 'A microphone transcription is already active.',
        recoverySuggestion:
            'Cancel and await the current subscription before starting another.',
      );
    }
    _liveTranscriptionActive = true;
    try {
      await for (final Object? value
          in _transcriptionEventChannel.receiveBroadcastStream(
            request.toMap(),
          )) {
        final LiveTranscriptionEvent event = LiveTranscriptionEvent.fromMap(
          _asMap(value),
        );
        yield event;
        if (event.isFinal) {
          break;
        }
      }
    } on PlatformException catch (error) {
      throw FoundationModelsException.fromPlatformException(error);
    } finally {
      try {
        await _invoke<void>('stopLiveTranscription');
      } finally {
        _liveTranscriptionActive = false;
      }
    }
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
    late final StreamController<SessionEvent> controller;
    controller = StreamController<SessionEvent>(
      sync: true,
      onListen: () {
        _activeStreams[requestId] = _ActiveGenerationStream(
          sessionId: sessionId,
          controller: controller,
        );
        unawaited(_startStream(requestId, arguments, controller));
      },
      onCancel: () async {
        final _ActiveGenerationStream? active = _activeStreams[requestId];
        if (active == null || !identical(active.controller, controller)) {
          return;
        }
        _activeStreams.remove(requestId);
        await _cancelStream(sessionId: sessionId, requestId: requestId);
      },
    );
    return controller.stream;
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
    final List<String> requestIds = _activeStreams.entries
        .where(
          (MapEntry<String, _ActiveGenerationStream> entry) =>
              entry.value.sessionId == sessionId,
        )
        .map((MapEntry<String, _ActiveGenerationStream> entry) => entry.key)
        .toList(growable: false);
    for (final String requestId in requestIds) {
      final _ActiveGenerationStream? active = _activeStreams.remove(requestId);
      await active?.controller.close();
    }
  }

  /// Handles calls initiated by the native side, currently tool invocations.
  Future<Object?> _handleNativeCall(MethodCall call) async {
    if (call.method == 'streamEvent') {
      await _handleStreamEvent(_asMap(call.arguments));
      return null;
    }
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

    try {
      final ToolResult result = await session.resolveToolCall(
        ToolCall(
          id: (arguments['toolCallId'] as String?) ?? '',
          name: name,
          arguments: _decodeToolArguments(
            arguments['argumentsJson'] as String?,
          ),
        ),
      );
      return result.toMap();
    } on FormatException {
      return const ToolResult.failure(
        'Tool arguments must be a valid JSON object.',
      ).toMap();
    }
  }

  Future<void> _startStream(
    String requestId,
    Map<String, Object?> arguments,
    StreamController<SessionEvent> controller,
  ) async {
    try {
      await _invoke<void>('startStream', arguments);
    } on Object catch (error, stackTrace) {
      final _ActiveGenerationStream? active = _activeStreams[requestId];
      if (active == null || !identical(active.controller, controller)) {
        return;
      }
      _activeStreams.remove(requestId);
      controller.addError(error, stackTrace);
      await controller.close();
    }
  }

  Future<void> _cancelStream({
    required String sessionId,
    required String requestId,
  }) async {
    try {
      await _invoke<void>('cancelStream', <String, Object?>{
        'sessionId': sessionId,
        'requestId': requestId,
      });
    } on FoundationModelsException {
      return;
    }
  }

  Future<void> _handleStreamEvent(Map<Object?, Object?> arguments) async {
    final String requestId = (arguments['requestId'] as String?) ?? '';
    final _ActiveGenerationStream? active = _activeStreams[requestId];
    if (active == null) {
      return;
    }

    final Object? errorValue = arguments['error'];
    if (errorValue is Map<Object?, Object?>) {
      _activeStreams.remove(requestId);
      active.controller.addError(
        FoundationModelsException.fromPlatformException(
          PlatformException(
            code: (errorValue['code'] as String?) ?? 'nativeFailure',
            message: errorValue['message'] as String?,
            details: errorValue['details'],
          ),
        ),
      );
      await active.controller.close();
      return;
    }

    final SessionEvent event = SessionEvent.fromMap(_asMap(arguments['event']));
    active.controller.add(event);
    if (event is CompletionEvent || event is FailureEvent) {
      _activeStreams.remove(requestId);
      await active.controller.close();
    }
  }

  Map<String, Object?> _decodeToolArguments(String? argumentsJson) {
    if (argumentsJson == null || argumentsJson.isEmpty) {
      return <String, Object?>{};
    }
    final Object? decoded = jsonDecode(argumentsJson);
    if (decoded is Map<String, dynamic>) {
      return decoded.cast<String, Object?>();
    }
    throw const FormatException('Tool arguments must be a JSON object.');
  }

  Future<T?> _invoke<T>(String method, [Object? arguments]) async {
    try {
      final T? response = await _methodChannel.invokeMethod<T>(
        method,
        arguments,
      );
      return response;
    } on MissingPluginException {
      throw const FoundationModelsException(
        code: FoundationModelsErrorCode.unsupportedPlatform,
        message: 'The native iOS Foundation Models plugin is unavailable.',
        recoverySuggestion:
            'Use an iOS host with the plugin registered and rebuild after adding it.',
      );
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
    _requestSequence += 1;
    return 'request_${micros}_$_requestSequence';
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

final class _ActiveGenerationStream {
  const _ActiveGenerationStream({
    required this.sessionId,
    required this.controller,
  });

  final String sessionId;
  final StreamController<SessionEvent> controller;
}

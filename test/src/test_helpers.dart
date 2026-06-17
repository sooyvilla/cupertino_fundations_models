import 'dart:async';

import 'package:cupertino_fundations_models/cupertino_fundations_models.dart';
import 'package:cupertino_fundations_models/src/platform/cupertino_foundation_models_platform.dart';
import 'package:flutter/services.dart';

final class TestTool implements ModelTool {
  const TestTool({
    required this.name,
    required this.callback,
    this.description = 'description',
    this.parameters = const <String, Object?>{},
    this.timeout = const Duration(seconds: 20),
  });

  @override
  final String name;

  @override
  final String description;

  @override
  final Map<String, Object?> parameters;

  @override
  final Duration timeout;

  final FutureOr<Object?> Function(Map<String, Object?> arguments) callback;

  @override
  FutureOr<Object?> call(Map<String, Object?> arguments) => callback(arguments);
}

final class FakePlatform implements CupertinoFoundationModelsPlatform {
  FoundationModelsCapabilities capabilities = testCapabilities();
  final List<String> calls = <String>[];
  final List<String> disposedSessionIds = <String>[];
  int _sessionIndex = 0;

  @override
  Future<FoundationModelsCapabilities> getCapabilities() async {
    calls.add('getCapabilities');
    return capabilities;
  }

  @override
  Future<FoundationModelsDiagnostics> getDiagnostics({
    required String? localeIdentifier,
  }) async {
    calls.add('getDiagnostics');
    return FoundationModelsDiagnostics.fromMap(
      diagnosticsMap(<Object?, Object?>{'localeIdentifier': localeIdentifier}),
    );
  }

  @override
  Future<ModelAvailability> checkAvailability({
    required ModelMode mode,
    required CloudPolicy cloudPolicy,
    required String? localeIdentifier,
  }) async {
    calls.add('checkAvailability');
    return ModelAvailability.fromMap(availabilityMap());
  }

  @override
  Future<FoundationModelSession> createSession({
    required SessionOptions options,
  }) async {
    calls.add('createSession');
    _sessionIndex += 1;
    return FoundationModelSession(
      id: 'session_$_sessionIndex',
      mode: options.mode == ModelMode.automatic
          ? ModelMode.local
          : options.mode,
      platform: this,
      tools: options.tools,
    );
  }

  @override
  Future<PickedFoundationModelsFile?> pickFile({
    required FoundationModelsFileKind kind,
  }) async {
    calls.add('pickFile');
    return PickedFoundationModelsFile.fromMap(<Object?, Object?>{
      'path': '/tmp/file',
      'name': 'file',
      'kind': kind.name,
    });
  }

  @override
  Future<AudioTranscriptionResult> transcribeAudio({
    required AudioTranscriptionRequest request,
  }) async {
    calls.add('transcribeAudio');
    return AudioTranscriptionResult.fromMap(<Object?, Object?>{
      'text': request.filePath,
      'isFinal': true,
    });
  }

  @override
  Future<ModelResponse> respond({
    required String sessionId,
    required Prompt prompt,
    required GenerationOptions options,
  }) async {
    calls.add('respond');
    return ModelResponse.fromMap(<Object?, Object?>{'text': 'response'});
  }

  @override
  Stream<SessionEvent> stream({
    required String sessionId,
    required Prompt prompt,
    required GenerationOptions options,
  }) {
    calls.add('stream');
    return Stream<SessionEvent>.value(
      const TextDeltaEvent(requestId: 'r', text: 'delta'),
    );
  }

  @override
  Future<ModelResponse> generateStructured({
    required String sessionId,
    required Prompt prompt,
    required StructuredSchema schema,
    required GenerationOptions options,
  }) async {
    calls.add('generateStructured');
    return ModelResponse.fromMap(<Object?, Object?>{
      'text': 'structured',
      'structuredValue': <Object?, Object?>{'ok': true},
    });
  }

  @override
  Future<void> prewarm({
    required String sessionId,
    required Prompt? promptPrefix,
  }) async {
    calls.add('prewarm');
  }

  @override
  Future<void> cancelActiveRequest({required String sessionId}) async {
    calls.add('cancelActiveRequest');
  }

  @override
  Future<void> disposeSession({required String sessionId}) async {
    calls.add('disposeSession');
    disposedSessionIds.add(sessionId);
  }
}

final class ThrowingEventChannel extends EventChannel {
  const ThrowingEventChannel(super.name);

  @override
  Stream<dynamic> receiveBroadcastStream([dynamic arguments]) {
    return Stream<dynamic>.error(StateError('stream failed'));
  }
}

FoundationModelsCapabilities testCapabilities({
  bool supportsFullPower = true,
  ModelMode preferredMode = ModelMode.privateCloudCompute,
  Set<ModelCapability> capabilities = const <ModelCapability>{
    ModelCapability.localText,
    ModelCapability.fullPower,
  },
}) {
  return FoundationModelsCapabilities(
    platform: 'ios',
    operatingSystemVersion: '27.0',
    sdkVersion: '27.0',
    capabilities: capabilities,
    supportsFullPower: supportsFullPower,
    preferredMode: preferredMode,
  );
}

StructuredSchema testSchema() {
  return const StructuredSchema.object(
    name: 'Result',
    properties: <String, SchemaProperty>{'ok': SchemaProperty.boolean()},
    requiredProperties: <String>['ok'],
  );
}

Map<String, Object?> capabilitiesMap() => testCapabilities().toMap();

Map<String, Object?> availabilityMap() {
  return const ModelAvailability(
    mode: ModelMode.local,
    status: AvailabilityStatus.available,
    isAvailable: true,
    supportsFullPower: false,
  ).toMap();
}

Map<String, Object?> diagnosticsMap(Map<Object?, Object?> arguments) {
  final locale = arguments['localeIdentifier'] as String? ?? 'en_US';
  return FoundationModelsDiagnostics(
    platform: 'ios',
    operatingSystemVersion: '27.0',
    sdkVersion: '27.0',
    currentLocaleIdentifier: 'en_US',
    targetLocaleIdentifier: locale,
    preferredLanguages: const <String>['en_US'],
    localAvailability: ModelAvailability.fromMap(availabilityMap()),
    localSupportedLanguages: const <String>['en_US'],
    localPreferredLanguageSupport: const <LanguageSupport>[
      LanguageSupport(identifier: 'en_US', isSupported: true),
    ],
  ).toMap();
}

import 'package:cupertino_fundations_models/cupertino_fundations_models.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_helpers.dart';

void main() {
  group('cupertino foundation models facade', () {
    test('delegates public APIs and disposes one-shot sessions', () async {
      expect(CupertinoFoundationModels(), isA<CupertinoFoundationModels>());

      final platform = FakePlatform();
      final api = CupertinoFoundationModels(platform: platform);

      expect((await api.getCapabilities()).supportsFullPower, isTrue);
      expect(
        (await api.getDiagnostics(
          localeIdentifier: 'es_ES',
        )).targetLocaleIdentifier,
        'es_ES',
      );
      expect(
        (await api.checkAvailability(localeIdentifier: 'en_US')).isAvailable,
        isTrue,
      );
      expect(await api.supportsFullPower(), isTrue);
      expect(
        await api.supportsFullPower(cloudPolicy: CloudPolicy.never),
        isFalse,
      );

      platform.capabilities = testCapabilities(supportsFullPower: false);
      expect(await api.supportsFullPower(), isFalse);
      platform.capabilities = testCapabilities(
        preferredMode: ModelMode.local,
        capabilities: const <ModelCapability>{ModelCapability.fullPower},
      );
      expect(
        await api.supportsFullPower(cloudPolicy: CloudPolicy.never),
        isTrue,
      );

      expect(
        await api.pickFile(kind: FoundationModelsFileKind.audio),
        isA<PickedFoundationModelsFile>(),
      );
      expect(
        await api.transcribeAudio(
          const AudioTranscriptionRequest(filePath: '/tmp/a.m4a'),
        ),
        isA<AudioTranscriptionResult>(),
      );
      expect(
        (await api.respond(const Prompt.text('one shot'))).text,
        'response',
      );
      expect(
        (await api.generateStructured(
          prompt: const Prompt.text('structured'),
          schema: testSchema(),
        )).structuredValue,
        <String, Object?>{'ok': true},
      );
      expect(platform.disposedSessionIds, contains('session_2'));
    });
  });
}

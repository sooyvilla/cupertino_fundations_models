import 'package:cupertino_fundations_models/cupertino_fundations_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('transcription', () {
    test('requests serialize and results parse maps', () {
      const request = AudioTranscriptionRequest(
        filePath: '/tmp/audio.m4a',
        localeIdentifier: 'es_ES',
        mode: AudioTranscriptionMode.server,
        taskHint: AudioTranscriptionTaskHint.search,
        addsPunctuation: false,
        timeout: Duration(seconds: 3),
      );
      expect(request.toMap()['timeoutMilliseconds'], 3000);

      final transcription = AudioTranscriptionResult.fromMap(<Object?, Object?>{
        'text': 'hola',
        'isFinal': true,
        'usedMode': AudioTranscriptionMode.onDevice.name,
        'localeIdentifier': 'es_ES',
        'segments': <Object?>[
          <Object?, Object?>{
            'text': 'ho',
            'timestamp': 1.5,
            'duration': 0.25,
            'confidence': 0.9,
          },
          'skip',
        ],
        'metadata': <Object?, Object?>{'engine': 'speech'},
      });
      expect(transcription.usedMode, AudioTranscriptionMode.onDevice);
      expect(
        transcription.segments.single.timestamp,
        const Duration(milliseconds: 1500),
      );
      expect(
        AudioTranscriptionResult.fromMap(<Object?, Object?>{
          'usedMode': 'future',
        }).usedMode,
        AudioTranscriptionMode.automatic,
      );
    });
  });
}

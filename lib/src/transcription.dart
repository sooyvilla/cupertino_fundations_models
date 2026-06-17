enum AudioTranscriptionMode { automatic, onDevice, server }

enum AudioTranscriptionTaskHint { unspecified, dictation, search, confirmation }

final class AudioTranscriptionRequest {
  const AudioTranscriptionRequest({
    required this.filePath,
    this.localeIdentifier = 'en_US',
    this.mode = AudioTranscriptionMode.onDevice,
    this.taskHint = AudioTranscriptionTaskHint.dictation,
    this.addsPunctuation = true,
    this.timeout = const Duration(minutes: 2),
  });

  final String filePath;
  final String localeIdentifier;
  final AudioTranscriptionMode mode;
  final AudioTranscriptionTaskHint taskHint;
  final bool addsPunctuation;
  final Duration timeout;

  Map<String, Object?> toMap() {
    return <String, Object?>{
      'filePath': filePath,
      'localeIdentifier': localeIdentifier,
      'mode': mode.name,
      'taskHint': taskHint.name,
      'addsPunctuation': addsPunctuation,
      'timeoutMilliseconds': timeout.inMilliseconds,
    };
  }
}

final class AudioTranscriptionResult {
  const AudioTranscriptionResult({
    required this.text,
    required this.isFinal,
    required this.usedMode,
    required this.localeIdentifier,
    required this.segments,
    required this.metadata,
  });

  factory AudioTranscriptionResult.fromMap(Map<Object?, Object?> map) {
    final List<Object?> rawSegments =
        (map['segments'] as List<Object?>?) ?? <Object?>[];
    final Map<Object?, Object?> rawMetadata =
        (map['metadata'] as Map<Object?, Object?>?) ?? <Object?, Object?>{};

    return AudioTranscriptionResult(
      text: (map['text'] as String?) ?? '',
      isFinal: (map['isFinal'] as bool?) ?? false,
      usedMode: _modeFromName((map['usedMode'] as String?) ?? 'automatic'),
      localeIdentifier: (map['localeIdentifier'] as String?) ?? '',
      segments: rawSegments
          .whereType<Map<Object?, Object?>>()
          .map(AudioTranscriptionSegment.fromMap)
          .toList(growable: false),
      metadata: rawMetadata.cast<String, Object?>(),
    );
  }

  final String text;
  final bool isFinal;
  final AudioTranscriptionMode usedMode;
  final String localeIdentifier;
  final List<AudioTranscriptionSegment> segments;
  final Map<String, Object?> metadata;
}

final class AudioTranscriptionSegment {
  const AudioTranscriptionSegment({
    required this.text,
    required this.timestamp,
    required this.duration,
    required this.confidence,
  });

  factory AudioTranscriptionSegment.fromMap(Map<Object?, Object?> map) {
    return AudioTranscriptionSegment(
      text: (map['text'] as String?) ?? '',
      timestamp: Duration(
        milliseconds: ((map['timestamp'] as num?)?.toDouble() ?? 0) * 1000 ~/ 1,
      ),
      duration: Duration(
        milliseconds: ((map['duration'] as num?)?.toDouble() ?? 0) * 1000 ~/ 1,
      ),
      confidence: (map['confidence'] as num?)?.toDouble() ?? 0,
    );
  }

  final String text;
  final Duration timestamp;
  final Duration duration;
  final double confidence;
}

AudioTranscriptionMode _modeFromName(String name) {
  for (final AudioTranscriptionMode value in AudioTranscriptionMode.values) {
    if (value.name == name) {
      return value;
    }
  }
  return AudioTranscriptionMode.automatic;
}

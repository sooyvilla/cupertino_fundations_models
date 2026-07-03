/// Selects the speech recognition path used for audio transcription.
enum AudioTranscriptionMode { automatic, onDevice, server }

/// Gives Apple's speech recognizer context about the expected audio content.
enum AudioTranscriptionTaskHint { unspecified, dictation, search, confirmation }

/// Request used to transcribe an audio file through Apple's Speech framework.
final class AudioTranscriptionRequest {
  /// Creates an audio transcription request.
  const AudioTranscriptionRequest({
    required this.filePath,
    this.localeIdentifier = 'en_US',
    this.mode = AudioTranscriptionMode.onDevice,
    this.taskHint = AudioTranscriptionTaskHint.dictation,
    this.addsPunctuation = true,
    this.timeout = const Duration(minutes: 2),
  });

  /// Absolute path to the audio file on the native iOS filesystem.
  final String filePath;

  /// Locale identifier passed to the speech recognizer, such as `en_US`.
  final String localeIdentifier;

  /// Recognition path requested for this transcription.
  final AudioTranscriptionMode mode;

  /// Task hint used to tune speech recognition.
  final AudioTranscriptionTaskHint taskHint;

  /// Whether the recognizer should add punctuation when supported.
  final bool addsPunctuation;

  /// Maximum time allowed for the transcription request.
  final Duration timeout;

  /// Converts this request into a platform-channel payload.
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

/// Result returned after transcribing an audio file.
final class AudioTranscriptionResult {
  /// Creates an audio transcription result.
  const AudioTranscriptionResult({
    required this.text,
    required this.isFinal,
    required this.usedMode,
    required this.localeIdentifier,
    required this.segments,
    required this.metadata,
  });

  /// Creates a result from the native platform-channel payload.
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

  /// Full recognized text.
  final String text;

  /// Whether the recognizer marked the result as final.
  final bool isFinal;

  /// Recognition mode that was used by the native implementation.
  final AudioTranscriptionMode usedMode;

  /// Locale identifier used for recognition.
  final String localeIdentifier;

  /// Timestamped transcription segments returned by Speech.
  final List<AudioTranscriptionSegment> segments;

  /// Extra native metadata exposed for diagnostics.
  final Map<String, Object?> metadata;
}

/// Request used to start live microphone transcription.
final class LiveTranscriptionRequest {
  /// Creates a live transcription request.
  const LiveTranscriptionRequest({
    this.localeIdentifier = 'en_US',
    this.mode = AudioTranscriptionMode.onDevice,
    this.taskHint = AudioTranscriptionTaskHint.dictation,
    this.addsPunctuation = true,
    this.reportPartialResults = true,
  });

  /// Locale identifier passed to the speech recognizer, such as `en_US`.
  final String localeIdentifier;

  /// Recognition path requested for this transcription.
  final AudioTranscriptionMode mode;

  /// Task hint used to tune speech recognition.
  final AudioTranscriptionTaskHint taskHint;

  /// Whether the recognizer should add punctuation when supported.
  final bool addsPunctuation;

  /// Whether volatile partial results are emitted while the user speaks.
  final bool reportPartialResults;

  /// Converts this request into a platform-channel payload.
  Map<String, Object?> toMap() {
    return <String, Object?>{
      'localeIdentifier': localeIdentifier,
      'mode': mode.name,
      'taskHint': taskHint.name,
      'addsPunctuation': addsPunctuation,
      'reportPartialResults': reportPartialResults,
    };
  }
}

/// Incremental result emitted during live microphone transcription.
final class LiveTranscriptionEvent {
  /// Creates a live transcription event.
  const LiveTranscriptionEvent({
    required this.text,
    required this.isFinal,
    this.metadata = const <String, Object?>{},
  });

  /// Creates an event from the native platform-channel payload.
  factory LiveTranscriptionEvent.fromMap(Map<Object?, Object?> map) {
    final Map<Object?, Object?> rawMetadata =
        (map['metadata'] as Map<Object?, Object?>?) ?? <Object?, Object?>{};
    return LiveTranscriptionEvent(
      text: (map['text'] as String?) ?? '',
      isFinal: (map['isFinal'] as bool?) ?? false,
      metadata: rawMetadata.cast<String, Object?>(),
    );
  }

  /// Best transcription snapshot recognized so far.
  ///
  /// Treat this as a full replacement of the previous snapshot, not a delta.
  final String text;

  /// Whether the recognizer marked this snapshot as final.
  ///
  /// A final event is the last event emitted before the stream closes.
  final bool isFinal;

  /// Extra native metadata exposed for diagnostics.
  final Map<String, Object?> metadata;
}

/// Timestamped piece of a transcription result.
final class AudioTranscriptionSegment {
  /// Creates a transcription segment.
  const AudioTranscriptionSegment({
    required this.text,
    required this.timestamp,
    required this.duration,
    required this.confidence,
  });

  /// Creates a segment from the native platform-channel payload.
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

  /// Recognized text for this segment.
  final String text;

  /// Start time of the segment within the source audio.
  final Duration timestamp;

  /// Duration of the segment within the source audio.
  final Duration duration;

  /// Recognition confidence reported by Speech, from `0.0` to `1.0`.
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

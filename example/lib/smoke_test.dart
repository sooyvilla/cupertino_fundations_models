import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:cupertino_fundations_models/cupertino_fundations_models.dart';
import 'package:flutter/material.dart';

final class FoundationModelsSmokeTestApp extends StatefulWidget {
  const FoundationModelsSmokeTestApp({super.key});

  @override
  State<FoundationModelsSmokeTestApp> createState() =>
      _FoundationModelsSmokeTestAppState();
}

final class _FoundationModelsSmokeTestAppState
    extends State<FoundationModelsSmokeTestApp> {
  String _status = 'Starting iOS 27 smoke test...';
  Map<String, Object?>? _report;

  @override
  void initState() {
    super.initState();
    unawaited(_run());
  }

  Future<void> _run() async {
    final Map<String, Object?> report = await _FoundationModelsSmokeRunner(
      onProgress: (String value) {
        if (mounted) {
          setState(() => _status = value);
        }
      },
    ).run();
    debugPrint('CFM_SMOKE_RESULT=${jsonEncode(report)}');
    if (mounted) {
      setState(() {
        _report = report;
        _status = report['passed'] == true
            ? 'All executable smoke checks passed.'
            : 'Smoke test completed with failures.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        appBar: AppBar(title: const Text('Foundation Models Smoke Test')),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Text(_status, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 16),
                Expanded(
                  child: SingleChildScrollView(
                    child: SelectableText(
                      const JsonEncoder.withIndent(
                        '  ',
                      ).convert(_report ?? <String, Object?>{}),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

final class _FoundationModelsSmokeRunner {
  _FoundationModelsSmokeRunner({required this.onProgress});

  static const GenerationOptions _shortGeneration = GenerationOptions(
    maximumResponseTokens: 48,
    maximumToolCalls: 2,
  );

  final ValueChanged<String> onProgress;
  final CupertinoFoundationModels _models = CupertinoFoundationModels();
  final Map<String, Object?> _steps = <String, Object?>{};
  ModelAvailability? _localAvailability;
  ModelAvailability? _privateCloudAvailability;

  Future<Map<String, Object?>> run() async {
    final Stopwatch stopwatch = Stopwatch()..start();
    await _persist(complete: false, elapsedMilliseconds: 0);
    await _step('capabilities', _readCapabilities);
    await _step('supportedLanguages', _readSupportedLanguages);
    await _step('diagnostics', _readDiagnostics);
    await _step('availability', _readAvailability);
    await _step('audioFileTranscription', _testAudioFileTranscription);
    await _step('liveTranscriptionStartCancel', _testLiveTranscription);

    if (_localAvailability?.isAvailable ?? false) {
      await _step('tokenCounting', _testTokenCounting);
      await _step('respondAndUsage', _testRespondAndUsage);
      await _step('structuredOutput', _testStructuredOutput);
      await _step('toolCalling', _testToolCalling);
      await _step('streamCompletion', _testStreamCompletion);
      await _step('streamCancellationAndReuse', _testStreamCancellation);
      await _step('multiplexedStreams', _testMultiplexedStreams);
      await _step('contentTaggingModel', _testContentTagging);
      await _step('imageVisionFallback', _testImageVisionFallback);
    } else {
      _skipLocalGenerationSteps();
    }

    if (_privateCloudAvailability?.isAvailable ?? false) {
      await _step('privateCloudCompute', _testPrivateCloudCompute);
    } else {
      _steps['privateCloudCompute'] = <String, Object?>{
        'status': 'skipped',
        'reason': _privateCloudAvailability?.status.name ?? 'unavailable',
      };
      await _persist(
        complete: false,
        elapsedMilliseconds: stopwatch.elapsedMilliseconds,
      );
    }

    stopwatch.stop();
    final bool passed = _steps.values.whereType<Map<String, Object?>>().every(
      (Map<String, Object?> value) => value['status'] != 'failed',
    );
    final Map<String, Object?> report = <String, Object?>{
      'passed': passed,
      'durationMilliseconds': stopwatch.elapsedMilliseconds,
      'steps': _steps,
    };
    await _persist(
      complete: true,
      elapsedMilliseconds: stopwatch.elapsedMilliseconds,
      passed: passed,
    );
    return report;
  }

  Future<void> _step(
    String name,
    Future<Map<String, Object?>> Function() action,
  ) async {
    onProgress('Running $name...');
    final Stopwatch stopwatch = Stopwatch()..start();
    try {
      final Map<String, Object?> details = await action();
      stopwatch.stop();
      _steps[name] = <String, Object?>{
        'status': 'passed',
        'durationMilliseconds': stopwatch.elapsedMilliseconds,
        ...details,
      };
    } on FoundationModelsException catch (error) {
      stopwatch.stop();
      _steps[name] = <String, Object?>{
        'status': 'failed',
        'durationMilliseconds': stopwatch.elapsedMilliseconds,
        'errorCode': error.code.name,
        'message': error.message,
        'recoverySuggestion': error.recoverySuggestion,
      };
    } on Object catch (error) {
      stopwatch.stop();
      _steps[name] = <String, Object?>{
        'status': 'failed',
        'durationMilliseconds': stopwatch.elapsedMilliseconds,
        'message': error.toString(),
      };
    }
    await _persist(
      complete: false,
      elapsedMilliseconds: stopwatch.elapsedMilliseconds,
    );
  }

  Future<void> _persist({
    required bool complete,
    required int elapsedMilliseconds,
    bool? passed,
  }) async {
    final Map<String, Object?> report = <String, Object?>{
      'complete': complete,
      'passed': passed,
      'elapsedMilliseconds': elapsedMilliseconds,
      'steps': _steps,
    };
    await File(
      '${Directory.systemTemp.path}/cfm_smoke_result.json',
    ).writeAsString(jsonEncode(report), flush: true);
    debugPrint('CFM_SMOKE_PROGRESS complete=$complete steps=${_steps.length}');
  }

  Future<Map<String, Object?>> _readCapabilities() async {
    final FoundationModelsCapabilities value = await _models.getCapabilities();
    return <String, Object?>{
      'platform': value.platform,
      'operatingSystemVersion': value.operatingSystemVersion,
      'sdkVersion': value.sdkVersion,
      'capabilities': value.capabilities
          .map((ModelCapability capability) => capability.name)
          .toList(growable: false),
      'preferredMode': value.preferredMode.name,
      'contextSize': value.contextSize,
      'privateCloudContextSize': value.privateCloudContextSize,
    };
  }

  Future<Map<String, Object?>> _readSupportedLanguages() async {
    final List<FoundationModelsLanguage> values = await _models
        .getSupportedLanguages();
    return <String, Object?>{
      'count': values.length,
      'identifiers': values
          .map((FoundationModelsLanguage value) => value.identifier)
          .toList(growable: false),
      'installedTranscriptionAssets': values
          .where(
            (FoundationModelsLanguage value) =>
                value.isTranscriptionAssetInstalled,
          )
          .map((FoundationModelsLanguage value) => value.identifier)
          .toList(growable: false),
    };
  }

  Future<Map<String, Object?>> _readDiagnostics() async {
    final FoundationModelsDiagnostics value = await _models.getDiagnostics();
    return <String, Object?>{
      'localStatus': value.localAvailability.status.name,
      'privateCloudStatus': value.privateCloudAvailability?.status.name,
      'currentLocaleIdentifier': value.currentLocaleIdentifier,
      'targetLocaleIdentifier': value.targetLocaleIdentifier,
      'localSupportedLanguageCount': value.localSupportedLanguages.length,
      'privateCloudSupportedLanguageCount':
          value.privateCloudSupportedLanguages.length,
    };
  }

  Future<Map<String, Object?>> _readAvailability() async {
    final List<ModelAvailability> values =
        await Future.wait(<Future<ModelAvailability>>[
          _models.checkAvailability(mode: ModelMode.local),
          _models.checkAvailability(
            mode: ModelMode.privateCloudCompute,
            cloudPolicy: CloudPolicy.whenExplicit,
          ),
        ]);
    _localAvailability = values.first;
    _privateCloudAvailability = values.last;
    return <String, Object?>{
      'local': _availabilitySummary(values.first),
      'privateCloudCompute': _availabilitySummary(values.last),
    };
  }

  Map<String, Object?> _availabilitySummary(ModelAvailability value) {
    return <String, Object?>{
      'status': value.status.name,
      'isAvailable': value.isAvailable,
      'supportsFullPower': value.supportsFullPower,
      'contextSize': value.contextSize,
      'reason': value.reason,
    };
  }

  Future<Map<String, Object?>> _testTokenCounting() async {
    final int count = await _models.countTokens(
      const Prompt.text('Count the tokens in this deterministic smoke prompt.'),
    );
    if (count <= 0) {
      throw StateError('The tokenizer returned a non-positive token count.');
    }
    return <String, Object?>{'promptTokenCount': count};
  }

  Future<Map<String, Object?>> _testAudioFileTranscription() async {
    final File audio = File('${Directory.systemTemp.path}/cfm_silence.wav');
    await audio.writeAsBytes(_silentWaveBytes(), flush: true);
    try {
      final AudioTranscriptionResult result = await _models.transcribeAudio(
        AudioTranscriptionRequest(
          filePath: audio.path,
          timeout: const Duration(seconds: 45),
        ),
      );
      if (!result.isFinal) {
        throw StateError('The file transcription did not finish.');
      }
      return <String, Object?>{
        'engine': result.metadata['engine'],
        'usedMode': result.usedMode.name,
        'recognizedTextLength': result.text.length,
        'segmentCount': result.segments.length,
      };
    } finally {
      if (audio.existsSync()) {
        await audio.delete();
      }
    }
  }

  Uint8List _silentWaveBytes() {
    const int sampleRate = 16000;
    const int sampleCount = sampleRate;
    const int dataBytes = sampleCount * 2;
    final Uint8List bytes = Uint8List(44 + dataBytes);
    final ByteData header = bytes.buffer.asByteData();
    _writeAscii(bytes, 0, 'RIFF');
    header.setUint32(4, 36 + dataBytes, Endian.little);
    _writeAscii(bytes, 8, 'WAVE');
    _writeAscii(bytes, 12, 'fmt ');
    header.setUint32(16, 16, Endian.little);
    header.setUint16(20, 1, Endian.little);
    header.setUint16(22, 1, Endian.little);
    header.setUint32(24, sampleRate, Endian.little);
    header.setUint32(28, sampleRate * 2, Endian.little);
    header.setUint16(32, 2, Endian.little);
    header.setUint16(34, 16, Endian.little);
    _writeAscii(bytes, 36, 'data');
    header.setUint32(40, dataBytes, Endian.little);
    return bytes;
  }

  void _writeAscii(Uint8List target, int offset, String value) {
    final List<int> characters = ascii.encode(value);
    target.setRange(offset, offset + characters.length, characters);
  }

  Future<Map<String, Object?>> _testLiveTranscription() async {
    StreamSubscription<LiveTranscriptionEvent>? subscription;
    final Completer<void> terminal = Completer<void>();
    Object? streamError;
    StackTrace? streamStackTrace;
    int eventCount = 0;
    try {
      subscription = _models.liveTranscription().listen(
        (LiveTranscriptionEvent event) {
          eventCount += 1;
          if (event.isFinal && !terminal.isCompleted) {
            terminal.complete();
          }
        },
        onError: (Object error, StackTrace stackTrace) {
          streamError = error;
          streamStackTrace = stackTrace;
          if (!terminal.isCompleted) {
            terminal.complete();
          }
        },
        onDone: () {
          if (!terminal.isCompleted) {
            terminal.complete();
          }
        },
      );
      await Future.any(<Future<void>>[
        Future<void>.delayed(const Duration(seconds: 2)),
        terminal.future,
      ]);
      if (streamError case final Object error) {
        Error.throwWithStackTrace(
          error,
          streamStackTrace ?? StackTrace.current,
        );
      }
      await subscription.cancel().timeout(const Duration(seconds: 15));
      subscription = null;
      return <String, Object?>{
        'listenDurationMilliseconds': 2000,
        'eventCount': eventCount,
        'cancelledCleanly': true,
      };
    } finally {
      await subscription?.cancel();
    }
  }

  Future<Map<String, Object?>> _testRespondAndUsage() async {
    final FoundationModelSession session = await _models.createSession(
      options: const SessionOptions(
        mode: ModelMode.local,
        instructions: 'Answer smoke-test prompts directly and briefly.',
      ),
    );
    try {
      await session.prewarm(
        promptPrefix: const Prompt.text('Foundation Models smoke test'),
      );
      final ModelResponse response = await session.respond(
        const Prompt.text('Reply with exactly: LOCAL_OK'),
        options: _shortGeneration,
      );
      final int transcriptTokens = await session.countTokens();
      if (response.text.trim().isEmpty || transcriptTokens <= 0) {
        throw StateError(
          'The local response or transcript token count is empty.',
        );
      }
      return <String, Object?>{
        'usedMode': response.usedMode.name,
        'responseLength': response.text.length,
        'transcriptTokenCount': transcriptTokens,
        'usageTotalTokenCount': response.usage?.totalTokenCount,
      };
    } finally {
      await session.dispose();
    }
  }

  Future<Map<String, Object?>> _testStructuredOutput() async {
    final ModelResponse response = await _models.generateStructured(
      prompt: const Prompt.text(
        'Return label ios27 and score 27 using the requested schema.',
      ),
      schema: const StructuredSchema.object(
        name: 'smoke_result',
        properties: <String, SchemaProperty>{
          'label': SchemaProperty.string(),
          'score': SchemaProperty.integer(),
        },
        requiredProperties: <String>['label', 'score'],
      ),
      mode: ModelMode.local,
      options: _shortGeneration,
    );
    if (response.structuredValue is! Map<Object?, Object?>) {
      throw StateError('Structured output did not return an object.');
    }
    return <String, Object?>{
      'usedMode': response.usedMode.name,
      'structuredValue': response.structuredValue,
      'usageTotalTokenCount': response.usage?.totalTokenCount,
    };
  }

  Future<Map<String, Object?>> _testToolCalling() async {
    final _SmokeTool tool = _SmokeTool();
    final FoundationModelSession session = await _models.createSession(
      options: SessionOptions(
        mode: ModelMode.local,
        instructions: 'Always use the registered tool when asked.',
        tools: <ModelTool>[tool],
      ),
    );
    try {
      final ModelResponse response = await session.respond(
        const Prompt.text(
          'Retrieve the current runtime nonce with get_runtime_nonce. The '
          'nonce is not in this prompt, so do not guess it. Reply with only '
          'the exact value returned by the tool.',
        ),
        options: const GenerationOptions(
          maximumResponseTokens: 48,
          maximumToolCalls: 2,
        ),
      );
      if (tool.callCount != 1 || response.text.trim().isEmpty) {
        throw StateError(
          'Expected one tool invocation and a non-empty final response.',
        );
      }
      return <String, Object?>{
        'callCount': tool.callCount,
        'responseLength': response.text.length,
      };
    } finally {
      await session.dispose();
    }
  }

  Future<Map<String, Object?>> _testStreamCompletion() async {
    final FoundationModelSession session = await _models.createSession(
      options: const SessionOptions(mode: ModelMode.local),
    );
    try {
      return await _collectStream(
        session,
        const Prompt.text('Reply with one short sentence about iOS 27.'),
      );
    } finally {
      await session.dispose();
    }
  }

  Future<Map<String, Object?>> _collectStream(
    FoundationModelSession session,
    Prompt prompt,
  ) async {
    int snapshots = 0;
    int completionEvents = 0;
    String latest = '';
    await for (final SessionEvent event in session.stream(
      prompt,
      options: _shortGeneration,
    )) {
      switch (event) {
        case TextSnapshotEvent():
          snapshots += 1;
          latest = event.text;
        case CompletionEvent():
          completionEvents += 1;
          latest = event.response.text;
        case FailureEvent():
          throw StateError('${event.code}: ${event.message}');
        case ToolCallEvent() || UnknownSessionEvent():
          break;
      }
    }
    if (snapshots == 0 || completionEvents != 1 || latest.trim().isEmpty) {
      throw StateError('The stream did not emit snapshots and one completion.');
    }
    return <String, Object?>{
      'snapshotCount': snapshots,
      'completionCount': completionEvents,
      'responseLength': latest.length,
    };
  }

  Future<Map<String, Object?>> _testStreamCancellation() async {
    final FoundationModelSession session = await _models.createSession(
      options: const SessionOptions(mode: ModelMode.local),
    );
    StreamSubscription<SessionEvent>? subscription;
    try {
      final Completer<void> firstSnapshot = Completer<void>();
      int snapshots = 0;
      subscription = session
          .stream(
            const Prompt.text(
              'Write a detailed multi-paragraph story with at least 500 words.',
            ),
            options: const GenerationOptions(maximumResponseTokens: 512),
          )
          .listen(
            (SessionEvent event) {
              if (event is TextSnapshotEvent) {
                snapshots += 1;
                if (!firstSnapshot.isCompleted) {
                  firstSnapshot.complete();
                }
              }
            },
            onError: (Object error, StackTrace stackTrace) {
              if (!firstSnapshot.isCompleted) {
                firstSnapshot.completeError(error, stackTrace);
              }
            },
            onDone: () {
              if (!firstSnapshot.isCompleted) {
                firstSnapshot.completeError(
                  StateError('The stream ended before its first snapshot.'),
                );
              }
            },
          );
      await firstSnapshot.future.timeout(const Duration(seconds: 45));
      await subscription.cancel();
      subscription = null;

      final ModelResponse reused = await session.respond(
        const Prompt.text('Reply with exactly: REUSED_OK'),
        options: _shortGeneration,
      );
      if (reused.text.trim().isEmpty) {
        throw StateError('The session did not recover after cancellation.');
      }
      return <String, Object?>{
        'snapshotsBeforeCancellation': snapshots,
        'reuseResponseLength': reused.text.length,
      };
    } finally {
      await subscription?.cancel();
      await session.dispose();
    }
  }

  Future<Map<String, Object?>> _testMultiplexedStreams() async {
    final FoundationModelSession first = await _models.createSession(
      options: const SessionOptions(mode: ModelMode.local),
    );
    final FoundationModelSession second = await _models.createSession(
      options: const SessionOptions(mode: ModelMode.local),
    );
    try {
      final List<Map<String, Object?>> results = await Future.wait(
        <Future<Map<String, Object?>>>[
          _collectStream(first, const Prompt.text('Reply exactly: STREAM_A')),
          _collectStream(second, const Prompt.text('Reply exactly: STREAM_B')),
        ],
      );
      return <String, Object?>{'streams': results};
    } finally {
      await first.dispose();
      await second.dispose();
    }
  }

  Future<Map<String, Object?>> _testContentTagging() async {
    final FoundationModelSession session = await _models.createSession(
      options: const SessionOptions(
        mode: ModelMode.local,
        useCase: FoundationModelsUseCase.contentTagging,
      ),
    );
    try {
      final ModelResponse response = await session.respond(
        const Prompt.text('Return one tag for: Swift concurrency actor.'),
        options: _shortGeneration,
      );
      if (response.text.trim().isEmpty) {
        throw StateError('The content-tagging model returned empty text.');
      }
      return <String, Object?>{
        'responseLength': response.text.length,
        'usedMode': response.usedMode.name,
      };
    } finally {
      await session.dispose();
    }
  }

  Future<Map<String, Object?>> _testImageVisionFallback() async {
    const String image =
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR4nGP6zwAAAgcBApocMXEAAAAASUVORK5CYII=';
    final ModelResponse response = await _models.respond(
      Prompt(
        text: 'Describe the attached image in one short sentence.',
        attachments: <PromptAttachment>[
          PromptAttachment.bytes(
            bytes: base64Decode(image),
            label: 'one-pixel smoke image',
            mimeType: 'image/png',
          ),
        ],
      ),
      mode: ModelMode.local,
      options: _shortGeneration,
    );
    if (response.text.trim().isEmpty) {
      throw StateError('The Vision-backed image request returned empty text.');
    }
    return <String, Object?>{
      'responseLength': response.text.length,
      'usedMode': response.usedMode.name,
    };
  }

  Future<Map<String, Object?>> _testPrivateCloudCompute() async {
    final ModelResponse response = await _models.respond(
      const Prompt.text('Reply with exactly: PCC_OK'),
      mode: ModelMode.privateCloudCompute,
      cloudPolicy: CloudPolicy.whenExplicit,
      options: const GenerationOptions(
        maximumResponseTokens: 32,
        cloudPolicy: CloudPolicy.whenExplicit,
        reasoningLevel: ReasoningLevel.light,
        timeout: Duration(seconds: 90),
      ),
    );
    if (response.text.trim().isEmpty) {
      throw StateError('Private Cloud Compute returned empty text.');
    }
    return <String, Object?>{
      'responseLength': response.text.length,
      'usedMode': response.usedMode.name,
      'usageTotalTokenCount': response.usage?.totalTokenCount,
    };
  }

  void _skipLocalGenerationSteps() {
    final String reason = _localAvailability?.status.name ?? 'unavailable';
    for (final String name in <String>[
      'tokenCounting',
      'respondAndUsage',
      'structuredOutput',
      'toolCalling',
      'streamCompletion',
      'streamCancellationAndReuse',
      'multiplexedStreams',
      'contentTaggingModel',
      'imageVisionFallback',
    ]) {
      _steps[name] = <String, Object?>{'status': 'skipped', 'reason': reason};
    }
  }
}

final class _SmokeTool implements ModelTool {
  int callCount = 0;

  @override
  String get description =>
      'Retrieves a runtime nonce that is unavailable without this tool.';

  @override
  String get name => 'get_runtime_nonce';

  @override
  Map<String, Object?> get parameters => const <String, Object?>{
    'type': 'object',
    'properties': <String, Object?>{},
  };

  @override
  Duration get timeout => const Duration(seconds: 5);

  @override
  Object? call(Map<String, Object?> arguments) {
    callCount += 1;
    return 'RUNTIME_NONCE_27_OK';
  }
}

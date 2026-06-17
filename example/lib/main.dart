import 'dart:async';

import 'package:cupertino_fundations_models/cupertino_fundations_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

const Locale _exampleLocale = Locale('en', 'US');
const String _exampleLocaleIdentifier = 'en_US';

void main() {
  runApp(const _FoundationModelsExampleApp());
}

final class _FoundationModelsExampleApp extends StatelessWidget {
  const _FoundationModelsExampleApp();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Foundation Models Example',
      locale: _exampleLocale,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        useMaterial3: true,
      ),
      home: const _FoundationModelsExamplePage(),
    );
  }
}

final class _FoundationModelsExamplePage extends StatefulWidget {
  const _FoundationModelsExamplePage();

  @override
  State<_FoundationModelsExamplePage> createState() {
    return _FoundationModelsExamplePageState();
  }
}

final class _FoundationModelsExamplePageState
    extends State<_FoundationModelsExamplePage> {
  final CupertinoFoundationModels _models = CupertinoFoundationModels();
  final TextEditingController _promptController = TextEditingController(
    text: 'Analyze the selected context and answer in Spanish.',
  );
  final TextEditingController _instructionsController = TextEditingController(
    text: 'You are a concise assistant. Respond in Spanish.',
  );
  final TextEditingController _maxTokensController = TextEditingController(
    text: '240',
  );
  final List<String> _logs = <String>[];
  final List<PickedFoundationModelsFile> _attachments =
      <PickedFoundationModelsFile>[];

  bool _isBusy = false;
  bool _allowCloud = false;
  bool _useTemperature = false;
  double _temperature = 0.7;
  ModelMode _mode = ModelMode.local;
  SamplingMode _samplingMode = SamplingMode.greedy;
  ToolCallingPolicy _toolCallingPolicy = ToolCallingPolicy.automatic;
  ReasoningLevel _reasoningLevel = ReasoningLevel.automatic;
  FoundationModelsCapabilities? _capabilities;
  ModelAvailability? _availability;
  FoundationModelsDiagnostics? _diagnostics;
  PickedFoundationModelsFile? _audioFile;
  AudioTranscriptionResult? _transcription;
  FoundationModelSession? _session;
  String _liveStreamText = '';

  @override
  void dispose() {
    _promptController.dispose();
    _instructionsController.dispose();
    _maxTokensController.dispose();
    unawaited(_session?.dispose());
    super.dispose();
  }

  Future<void> _loadCapabilities() async {
    await _run('Capabilities', () async {
      final FoundationModelsCapabilities capabilities = await _models
          .getCapabilities();
      final bool fullPower = await _models.supportsFullPower(
        cloudPolicy: _effectiveCloudPolicy(),
      );
      setState(() {
        _capabilities = capabilities;
      });
      _log('Platform: ${capabilities.platform}');
      _log('OS: ${capabilities.operatingSystemVersion}');
      _log('SDK: ${capabilities.sdkVersion}');
      _log('Preferred mode: ${capabilities.preferredMode.name}');
      _log('Full power: $fullPower');
      _log(
        'Capabilities: ${capabilities.capabilities.map((ModelCapability value) => value.name).join(', ')}',
      );
    });
  }

  Future<void> _loadDiagnostics() async {
    await _run('Diagnostics', () async {
      final FoundationModelsDiagnostics diagnostics = await _models
          .getDiagnostics(localeIdentifier: _exampleLocaleIdentifier);
      setState(() {
        _diagnostics = diagnostics;
        _availability = diagnostics.localAvailability;
      });
      _log('Platform: ${diagnostics.platform}');
      _log('OS: ${diagnostics.operatingSystemVersion}');
      _log('SDK: ${diagnostics.sdkVersion}');
      _log('Current locale: ${diagnostics.currentLocaleIdentifier}');
      _log('Target locale: ${diagnostics.targetLocaleIdentifier}');
      _log('Preferred languages: ${diagnostics.preferredLanguages.join(', ')}');
      _log(
        'Local supports current locale: ${diagnostics.localSupportsCurrentLocale}',
      );
      _log(
        'Local supported languages: ${diagnostics.localSupportedLanguages.join(', ')}',
      );
      _logLanguageSupport(
        'Local preferred support',
        diagnostics.localPreferredLanguageSupport,
      );
      _logAvailability(diagnostics.localAvailability);
      final ModelAvailability? privateCloud =
          diagnostics.privateCloudAvailability;
      if (privateCloud != null) {
        _log(
          'PCC supports current locale: ${diagnostics.privateCloudSupportsCurrentLocale}',
        );
        _log(
          'PCC supported languages: ${diagnostics.privateCloudSupportedLanguages.join(', ')}',
        );
        _logLanguageSupport(
          'PCC preferred support',
          diagnostics.privateCloudPreferredLanguageSupport,
        );
        _logAvailability(privateCloud);
      }
    });
  }

  Future<void> _checkSelectedAvailability() async {
    await _run('Availability ${_mode.name}', () async {
      final ModelAvailability availability = await _models.checkAvailability(
        mode: _mode,
        cloudPolicy: _effectiveCloudPolicy(),
        localeIdentifier: _exampleLocaleIdentifier,
      );
      setState(() {
        _availability = availability;
      });
      _logAvailability(availability);
    });
  }

  Future<void> _pickAttachment(FoundationModelsFileKind kind) async {
    await _run('Pick ${kind.name}', () async {
      final PickedFoundationModelsFile? file = await _models.pickFile(
        kind: kind,
      );
      if (file == null) {
        _log('File picker cancelled.');
        return;
      }
      setState(() {
        _attachments.add(file);
      });
      _log('Attachment added: ${file.name}');
      _log('Path: ${file.path}');
      _log('MIME: ${file.mimeType ?? 'unknown'}');
    });
  }

  Future<void> _pickAudio() async {
    await _run('Pick audio', () async {
      final PickedFoundationModelsFile? file = await _models.pickFile(
        kind: FoundationModelsFileKind.audio,
      );
      if (file == null) {
        _log('Audio picker cancelled.');
        return;
      }
      setState(() {
        _audioFile = file;
      });
      _log('Audio selected: ${file.name}');
      _log('Path: ${file.path}');
    });
  }

  Future<void> _transcribeAudio(AudioTranscriptionMode mode) async {
    final PickedFoundationModelsFile? audioFile = _audioFile;
    if (audioFile == null) {
      _showSnackBar('Pick an audio file first.');
      return;
    }

    await _run('Transcribe ${mode.name}', () async {
      final AudioTranscriptionResult result = await _models.transcribeAudio(
        AudioTranscriptionRequest(filePath: audioFile.path, mode: mode),
      );
      setState(() {
        _transcription = result;
      });
      _log('Transcription mode: ${result.usedMode.name}');
      _log('Transcription final: ${result.isFinal}');
      _log('Segments: ${result.segments.length}');
      _log('Transcript: ${result.text}');
    });
  }

  void _useTranscriptAsPrompt() {
    final AudioTranscriptionResult? transcription = _transcription;
    if (transcription == null || transcription.text.trim().isEmpty) {
      _showSnackBar('No transcript available.');
      return;
    }
    setState(() {
      _promptController.text = transcription.text;
    });
    _showSnackBar('Transcript copied to prompt.');
  }

  Future<void> _respondSelected() async {
    await _run('Respond ${_mode.name}', () async {
      final ModelAvailability availability = await _selectedAvailability();
      if (!availability.isAvailable) {
        _log(
          'Request skipped because ${availability.mode.name} is unavailable.',
        );
        return;
      }

      final Prompt prompt = _buildPrompt();
      _logPrompt(prompt);
      final ModelResponse response = await _models.respond(
        prompt,
        mode: _mode,
        cloudPolicy: _effectiveCloudPolicy(),
        instructions: _instructionsText,
        options: _generationOptions(),
      );
      _log('Used mode: ${response.usedMode.name}');
      _log('Response: ${response.text}');
      _logMetadata(response.metadata);
    });
  }

  Future<void> _streamSelected() async {
    await _run('Stream ${_mode.name}', () async {
      final ModelAvailability availability = await _selectedAvailability();
      if (!availability.isAvailable) {
        _log(
          'Request skipped because ${availability.mode.name} is unavailable.',
        );
        return;
      }

      final Prompt prompt = _buildPrompt();
      _logPrompt(prompt);
      final FoundationModelSession session = await _models.createSession(
        options: SessionOptions(
          mode: _mode,
          cloudPolicy: _effectiveCloudPolicy(),
          instructions: _instructionsText,
        ),
      );
      _session = session;
      setState(() {
        _liveStreamText = '';
      });

      await for (final SessionEvent event in session.stream(
        prompt,
        options: _generationOptions(),
      )) {
        switch (event) {
          case TextDeltaEvent():
            setState(() {
              _liveStreamText = event.text;
            });
          case CompletionEvent():
            _log('Stream used mode: ${event.response.usedMode.name}');
            _log('Stream completed: ${event.response.text}');
            _logMetadata(event.response.metadata);
          case FailureEvent():
            _log('Stream failed: ${event.code} ${event.message}');
          case ToolCallEvent():
            _log('Tool call: ${event.name}');
          case UnknownSessionEvent():
            _log('Unknown stream event: ${event.payload}');
        }
      }

      await session.dispose();
      if (identical(_session, session)) {
        _session = null;
      }
    });
  }

  Future<ModelAvailability> _selectedAvailability() async {
    final ModelAvailability availability = await _models.checkAvailability(
      mode: _mode,
      cloudPolicy: _effectiveCloudPolicy(),
      localeIdentifier: _exampleLocaleIdentifier,
    );
    setState(() {
      _availability = availability;
    });
    _logAvailability(availability);
    return availability;
  }

  Prompt _buildPrompt() {
    final List<PromptAttachment> promptAttachments = _attachments
        .map(
          (PickedFoundationModelsFile file) =>
              file.toPromptAttachment(label: file.name),
        )
        .toList(growable: false);
    return Prompt(
      text: _promptController.text.trim(),
      attachments: promptAttachments,
    );
  }

  GenerationOptions _generationOptions() {
    final int? maximumResponseTokens = int.tryParse(
      _maxTokensController.text.trim(),
    );
    return GenerationOptions(
      samplingMode: _samplingMode,
      temperature: _useTemperature ? _temperature : null,
      maximumResponseTokens: maximumResponseTokens,
      toolCallingPolicy: _toolCallingPolicy,
      reasoningLevel: _reasoningLevel,
      cloudPolicy: _effectiveCloudPolicy(),
    );
  }

  CloudPolicy _effectiveCloudPolicy() {
    if (_mode == ModelMode.privateCloudCompute) {
      return CloudPolicy.whenExplicit;
    }
    if (_mode == ModelMode.automatic && _allowCloud) {
      return CloudPolicy.whenExplicit;
    }
    return CloudPolicy.never;
  }

  String? get _instructionsText {
    final String text = _instructionsController.text.trim();
    if (text.isEmpty) {
      return null;
    }
    return text;
  }

  void _logPrompt(Prompt prompt) {
    _log('Prompt sent: ${prompt.text}');
    if (prompt.attachments.isNotEmpty) {
      _log('Attachments sent: ${prompt.attachments.length}');
    }
  }

  void _logAvailability(ModelAvailability availability) {
    _log('Mode: ${availability.mode.name}');
    _log('Status: ${availability.status.name}');
    _log('Available: ${availability.isAvailable}');
    _log('Full power: ${availability.supportsFullPower}');
    _log('Context size: ${availability.contextSize ?? 'unknown'}');
    if (availability.reason != null) {
      _log('Reason: ${availability.reason}');
    }
    if (availability.recoverySuggestion != null) {
      _log('Recovery: ${availability.recoverySuggestion}');
    }
  }

  void _logLanguageSupport(String title, List<LanguageSupport> support) {
    if (support.isEmpty) {
      _log('$title: unknown');
      return;
    }
    final String summary = support
        .map(
          (LanguageSupport value) => '${value.identifier}=${value.isSupported}',
        )
        .join(', ');
    _log('$title: $summary');
  }

  void _logMetadata(Map<String, Object?> metadata) {
    if (metadata.isEmpty) {
      return;
    }
    _log(
      'Metadata: ${metadata.entries.map((MapEntry<String, Object?> entry) => '${entry.key}=${entry.value}').join(', ')}',
    );
  }

  Future<void> _run(String title, Future<void> Function() operation) async {
    if (_isBusy) {
      return;
    }

    setState(() {
      _isBusy = true;
    });
    _log('--- $title ---');

    try {
      await operation();
    } on FoundationModelsException catch (error) {
      _log('FoundationModelsException: ${error.code.name}');
      _log(error.message);
      if (error.recoverySuggestion != null) {
        _log('Recovery: ${error.recoverySuggestion}');
      }
    } on Object catch (error) {
      _log('Error: $error');
    } finally {
      if (mounted) {
        setState(() {
          _isBusy = false;
        });
      }
    }
  }

  void _log(String message) {
    setState(() {
      _logs.insert(0, message);
    });
  }

  void _clearLogs() {
    setState(() {
      _logs.clear();
      _liveStreamText = '';
    });
  }

  Future<void> _copyLogs() async {
    final String logsText = _logsText;
    if (logsText.isEmpty) {
      _showSnackBar('No logs to copy.');
      return;
    }

    await Clipboard.setData(ClipboardData(text: logsText));
    if (!mounted) {
      return;
    }
    _showSnackBar('Copied ${_logs.length} log entries.');
  }

  void _clearAttachments() {
    setState(_attachments.clear);
  }

  String get _logsText {
    return _logs.join('\n\n');
  }

  void _showSnackBar(String message) {
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    messenger.clearSnackBars();
    messenger.showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Foundation Models'),
        actions: <Widget>[
          IconButton(
            tooltip: 'Copy logs',
            onPressed: _copyLogs,
            icon: const Icon(Icons.copy_all_outlined),
          ),
          IconButton(
            tooltip: 'Clear logs',
            onPressed: _clearLogs,
            icon: const Icon(Icons.delete_outline),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: <Widget>[
            _StatusPanel(
              isBusy: _isBusy,
              allowCloud: _allowCloud,
              capabilities: _capabilities,
              availability: _availability,
              diagnostics: _diagnostics,
              liveStreamText: _liveStreamText,
              onCloudChanged: (bool value) {
                setState(() {
                  _allowCloud = value;
                });
              },
            ),
            const SizedBox(height: 16),
            _ModelControls(
              isBusy: _isBusy,
              mode: _mode,
              samplingMode: _samplingMode,
              toolCallingPolicy: _toolCallingPolicy,
              reasoningLevel: _reasoningLevel,
              useTemperature: _useTemperature,
              temperature: _temperature,
              maxTokensController: _maxTokensController,
              onModeChanged: (ModelMode value) {
                setState(() {
                  _mode = value;
                });
              },
              onSamplingChanged: (SamplingMode value) {
                setState(() {
                  _samplingMode = value;
                });
              },
              onToolCallingChanged: (ToolCallingPolicy value) {
                setState(() {
                  _toolCallingPolicy = value;
                });
              },
              onReasoningChanged: (ReasoningLevel value) {
                setState(() {
                  _reasoningLevel = value;
                });
              },
              onUseTemperatureChanged: (bool value) {
                setState(() {
                  _useTemperature = value;
                });
              },
              onTemperatureChanged: (double value) {
                setState(() {
                  _temperature = value;
                });
              },
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _instructionsController,
              minLines: 2,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Instructions',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _promptController,
              minLines: 3,
              maxLines: 8,
              decoration: const InputDecoration(
                labelText: 'Prompt',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            _AttachmentPanel(
              attachments: _attachments,
              audioFile: _audioFile,
              transcription: _transcription,
              onPickText: _isBusy
                  ? null
                  : () => _pickAttachment(FoundationModelsFileKind.text),
              onPickImage: _isBusy
                  ? null
                  : () => _pickAttachment(FoundationModelsFileKind.image),
              onPickAny: _isBusy
                  ? null
                  : () => _pickAttachment(FoundationModelsFileKind.any),
              onPickAudio: _isBusy ? null : _pickAudio,
              onTranscribeOnDevice: _isBusy
                  ? null
                  : () => _transcribeAudio(AudioTranscriptionMode.onDevice),
              onTranscribeServer: _isBusy
                  ? null
                  : () => _transcribeAudio(AudioTranscriptionMode.server),
              onUseTranscript: _isBusy ? null : _useTranscriptAsPrompt,
              onClearAttachments: _attachments.isEmpty
                  ? null
                  : _clearAttachments,
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                FilledButton(
                  onPressed: _isBusy ? null : _loadCapabilities,
                  child: const Text('Capabilities'),
                ),
                FilledButton(
                  onPressed: _isBusy ? null : _loadDiagnostics,
                  child: const Text('Diagnostics'),
                ),
                FilledButton.tonal(
                  onPressed: _isBusy ? null : _checkSelectedAvailability,
                  child: const Text('Availability'),
                ),
                FilledButton(
                  onPressed: _isBusy ? null : _respondSelected,
                  child: const Text('Respond'),
                ),
                OutlinedButton(
                  onPressed: _isBusy ? null : _streamSelected,
                  child: const Text('Stream'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    'Logs',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                TextButton.icon(
                  onPressed: _copyLogs,
                  icon: const Icon(Icons.copy_all_outlined),
                  label: const Text('Copy all'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            DecoratedBox(
              decoration: BoxDecoration(
                border: Border.all(
                  color: Theme.of(context).colorScheme.outlineVariant,
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: SelectableText(
                  _logs.isEmpty ? 'No logs yet.' : _logsText,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

final class _StatusPanel extends StatelessWidget {
  const _StatusPanel({
    required this.isBusy,
    required this.allowCloud,
    required this.capabilities,
    required this.availability,
    required this.diagnostics,
    required this.liveStreamText,
    required this.onCloudChanged,
  });

  final bool isBusy;
  final bool allowCloud;
  final FoundationModelsCapabilities? capabilities;
  final ModelAvailability? availability;
  final FoundationModelsDiagnostics? diagnostics;
  final String liveStreamText;
  final ValueChanged<bool> onCloudChanged;

  @override
  Widget build(BuildContext context) {
    final String mode = capabilities?.preferredMode.name ?? 'unknown';
    final String status = availability?.status.name ?? 'not checked';
    final bool fullPower = capabilities?.supportsFullPower ?? false;
    final String locale = diagnostics?.currentLocaleIdentifier ?? 'unknown';
    final String targetLocale = diagnostics?.targetLocaleIdentifier ?? 'en_US';

    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    isBusy ? 'Running request' : 'Ready',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                Switch(
                  value: allowCloud,
                  onChanged: isBusy ? null : onCloudChanged,
                ),
              ],
            ),
            Text('Cloud allowed in automatic: $allowCloud'),
            Text('Preferred mode: $mode'),
            Text('Availability: $status'),
            Text('Full power: $fullPower'),
            Text('Locale: $locale'),
            Text('Target locale: $targetLocale'),
            if (liveStreamText.isNotEmpty) ...<Widget>[
              const SizedBox(height: 8),
              SelectableText('Live stream: $liveStreamText'),
            ],
          ],
        ),
      ),
    );
  }
}

final class _ModelControls extends StatelessWidget {
  const _ModelControls({
    required this.isBusy,
    required this.mode,
    required this.samplingMode,
    required this.toolCallingPolicy,
    required this.reasoningLevel,
    required this.useTemperature,
    required this.temperature,
    required this.maxTokensController,
    required this.onModeChanged,
    required this.onSamplingChanged,
    required this.onToolCallingChanged,
    required this.onReasoningChanged,
    required this.onUseTemperatureChanged,
    required this.onTemperatureChanged,
  });

  final bool isBusy;
  final ModelMode mode;
  final SamplingMode samplingMode;
  final ToolCallingPolicy toolCallingPolicy;
  final ReasoningLevel reasoningLevel;
  final bool useTemperature;
  final double temperature;
  final TextEditingController maxTokensController;
  final ValueChanged<ModelMode> onModeChanged;
  final ValueChanged<SamplingMode> onSamplingChanged;
  final ValueChanged<ToolCallingPolicy> onToolCallingChanged;
  final ValueChanged<ReasoningLevel> onReasoningChanged;
  final ValueChanged<bool> onUseTemperatureChanged;
  final ValueChanged<double> onTemperatureChanged;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: <Widget>[
            _EnumDropdown<ModelMode>(
              label: 'Mode',
              value: mode,
              values: ModelMode.values,
              enabled: !isBusy,
              onChanged: onModeChanged,
            ),
            const SizedBox(height: 12),
            _EnumDropdown<SamplingMode>(
              label: 'Sampling',
              value: samplingMode,
              values: SamplingMode.values,
              enabled: !isBusy,
              onChanged: onSamplingChanged,
            ),
            const SizedBox(height: 12),
            _EnumDropdown<ToolCallingPolicy>(
              label: 'Tool calling',
              value: toolCallingPolicy,
              values: ToolCallingPolicy.values,
              enabled: !isBusy,
              onChanged: onToolCallingChanged,
            ),
            const SizedBox(height: 12),
            _EnumDropdown<ReasoningLevel>(
              label: 'Reasoning',
              value: reasoningLevel,
              values: ReasoningLevel.values,
              enabled: !isBusy,
              onChanged: onReasoningChanged,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: maxTokensController,
              enabled: !isBusy,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Maximum response tokens',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Temperature'),
              subtitle: Text(
                useTemperature ? temperature.toStringAsFixed(2) : 'Default',
              ),
              value: useTemperature,
              onChanged: isBusy ? null : onUseTemperatureChanged,
            ),
            Slider(
              value: temperature,
              max: 2,
              divisions: 20,
              onChanged: isBusy || !useTemperature
                  ? null
                  : onTemperatureChanged,
            ),
          ],
        ),
      ),
    );
  }
}

final class _AttachmentPanel extends StatelessWidget {
  const _AttachmentPanel({
    required this.attachments,
    required this.audioFile,
    required this.transcription,
    required this.onPickText,
    required this.onPickImage,
    required this.onPickAny,
    required this.onPickAudio,
    required this.onTranscribeOnDevice,
    required this.onTranscribeServer,
    required this.onUseTranscript,
    required this.onClearAttachments,
  });

  final List<PickedFoundationModelsFile> attachments;
  final PickedFoundationModelsFile? audioFile;
  final AudioTranscriptionResult? transcription;
  final VoidCallback? onPickText;
  final VoidCallback? onPickImage;
  final VoidCallback? onPickAny;
  final VoidCallback? onPickAudio;
  final VoidCallback? onTranscribeOnDevice;
  final VoidCallback? onTranscribeServer;
  final VoidCallback? onUseTranscript;
  final VoidCallback? onClearAttachments;

  @override
  Widget build(BuildContext context) {
    final String attachmentText = attachments.isEmpty
        ? 'No prompt attachments'
        : attachments
              .map(
                (PickedFoundationModelsFile file) =>
                    '${file.kind.name}: ${file.name}',
              )
              .join('\n');
    final String audioText = audioFile == null
        ? 'No audio selected'
        : audioFile!.name;
    final String transcriptText = transcription == null
        ? 'No transcript'
        : transcription!.text;

    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text('Inputs', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                OutlinedButton(
                  onPressed: onPickText,
                  child: const Text('Pick text'),
                ),
                OutlinedButton(
                  onPressed: onPickImage,
                  child: const Text('Pick image'),
                ),
                OutlinedButton(
                  onPressed: onPickAny,
                  child: const Text('Pick any'),
                ),
                TextButton(
                  onPressed: onClearAttachments,
                  child: const Text('Clear attachments'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            SelectableText(attachmentText),
            const Divider(height: 24),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                OutlinedButton(
                  onPressed: onPickAudio,
                  child: const Text('Pick audio'),
                ),
                FilledButton.tonal(
                  onPressed: onTranscribeOnDevice,
                  child: const Text('Transcribe local'),
                ),
                FilledButton.tonal(
                  onPressed: onTranscribeServer,
                  child: const Text('Transcribe server'),
                ),
                TextButton(
                  onPressed: onUseTranscript,
                  child: const Text('Use transcript'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            SelectableText('Audio: $audioText'),
            const SizedBox(height: 8),
            SelectableText('Transcript: $transcriptText'),
          ],
        ),
      ),
    );
  }
}

final class _EnumDropdown<T extends Enum> extends StatelessWidget {
  const _EnumDropdown({
    required this.label,
    required this.value,
    required this.values,
    required this.enabled,
    required this.onChanged,
  });

  final String label;
  final T value;
  final List<T> values;
  final bool enabled;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<T>(
      initialValue: value,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
      items: values
          .map(
            (T item) =>
                DropdownMenuItem<T>(value: item, child: Text(item.name)),
          )
          .toList(growable: false),
      onChanged: enabled
          ? (T? selected) {
              if (selected != null) {
                onChanged(selected);
              }
            }
          : null,
    );
  }
}

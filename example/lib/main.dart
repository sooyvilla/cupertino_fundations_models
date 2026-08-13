import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:cupertino_fundations_models/cupertino_fundations_models.dart';
import 'package:flutter/material.dart';

/// Optional Gemini API key used to demo hybrid routing.
///
/// Run with an external fallback provider:
/// flutter run --dart-define=GEMINI_API_KEY=your_key
const String geminiApiKey = String.fromEnvironment('GEMINI_API_KEY');

/// Backend selection exposed in the example UI.
enum ChatBackend { auto, local, privateCloud, gemini }

enum _ChatAction { diagnostics, reset }

void main() {
  runApp(const ExampleApp());
}

final class ExampleApp extends StatelessWidget {
  const ExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Foundation Models Chat',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF0A84FF)),
      ),
      home: const ChatScreen(),
    );
  }
}

/// Minimal Gemini adapter used to demo Apple + external hybrid routing.
///
/// The package never ships provider clients; this adapter lives in the app.
final class GeminiExternalProvider extends FoundationModelsExternalProvider {
  const GeminiExternalProvider({required this.apiKey});

  final String apiKey;

  @override
  String get name => 'gemini';

  @override
  Future<bool> isAvailable() async => apiKey.isNotEmpty;

  @override
  Future<FoundationModelsProviderResponse> respond(
    FoundationModelsRequest request,
  ) async {
    final List<Map<String, Object?>> contents = <Map<String, Object?>>[
      for (final FoundationModelsChatMessage message in request.history)
        <String, Object?>{
          'role': message.role == FoundationModelsChatRole.assistant
              ? 'model'
              : 'user',
          'parts': <Map<String, Object?>>[
            <String, Object?>{'text': message.text},
          ],
        },
      <String, Object?>{
        'role': 'user',
        'parts': <Map<String, Object?>>[
          <String, Object?>{'text': request.prompt.text},
        ],
      },
    ];

    final Map<String, Object?> body = <String, Object?>{
      'contents': contents,
      if (request.instructions != null)
        'systemInstruction': <String, Object?>{
          'parts': <Map<String, Object?>>[
            <String, Object?>{'text': request.instructions},
          ],
        },
    };

    final HttpClient client = HttpClient();
    try {
      final HttpClientRequest httpRequest = await client.postUrl(
        Uri.parse(
          'https://generativelanguage.googleapis.com/v1beta/models/'
          'gemini-2.5-flash:generateContent?key=$apiKey',
        ),
      );
      httpRequest.headers.contentType = ContentType.json;
      httpRequest.write(jsonEncode(body));
      final HttpClientResponse httpResponse = await httpRequest.close();
      final String payload = await httpResponse.transform(utf8.decoder).join();
      if (httpResponse.statusCode != 200) {
        throw FoundationModelsException(
          code: FoundationModelsErrorCode.networkUnavailable,
          message: 'Gemini request failed with ${httpResponse.statusCode}.',
        );
      }
      final Map<String, Object?> decoded = (jsonDecode(payload) as Map)
          .cast<String, Object?>();
      final List<Object?> candidates =
          (decoded['candidates'] as List<Object?>?) ?? <Object?>[];
      final Map<String, Object?> first = candidates.isEmpty
          ? <String, Object?>{}
          : (candidates.first as Map).cast<String, Object?>();
      final Map<String, Object?> content =
          (first['content'] as Map?)?.cast<String, Object?>() ??
          <String, Object?>{};
      final List<Object?> parts =
          (content['parts'] as List<Object?>?) ?? <Object?>[];
      final String text = parts
          .whereType<Map<String, Object?>>()
          .map((Map<String, Object?> part) => part['text'] as String? ?? '')
          .join();
      return FoundationModelsProviderResponse(text: text);
    } finally {
      client.close(force: true);
    }
  }
}

/// Demo tool: the on-device model can call this to read the device clock.
final class DeviceTimeTool implements ModelTool {
  const DeviceTimeTool();

  @override
  String get name => 'get_current_time';

  @override
  String get description =>
      'Returns the current date and time on this device in ISO 8601 format.';

  @override
  Map<String, Object?> get parameters => const <String, Object?>{
    'type': 'object',
    'properties': <String, Object?>{},
  };

  @override
  Duration get timeout => const Duration(seconds: 5);

  @override
  Object? call(Map<String, Object?> arguments) {
    return DateTime.now().toIso8601String();
  }
}

final class ChatMessageView {
  ChatMessageView({
    required this.isUser,
    required this.text,
    this.providerName,
    this.isStreaming = false,
    this.attachmentName,
  });

  final bool isUser;
  String text;
  String? providerName;
  bool isStreaming;
  final String? attachmentName;
}

final class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

final class _ChatScreenState extends State<ChatScreen> {
  final CupertinoFoundationModels _models = CupertinoFoundationModels();
  late FoundationModelsOrchestrator _orchestrator;
  late FoundationModelsChatSession _chat;

  final TextEditingController _input = TextEditingController();
  final ScrollController _scroll = ScrollController();
  final List<ChatMessageView> _messages = <ChatMessageView>[];

  ModelAvailability? _localAvailability;
  PickedFoundationModelsFile? _pendingAttachment;
  StreamSubscription<LiveTranscriptionEvent>? _liveTranscription;
  bool _sending = false;
  bool _listening = false;
  ChatBackend _backend = ChatBackend.auto;
  String? _transcriptionEngine;
  late FoundationModelsLanguage _selectedLanguage;
  List<FoundationModelsLanguage> _supportedLanguages =
      <FoundationModelsLanguage>[];
  bool _loadingLanguages = true;
  String? _languageLoadError;

  static final String _deviceLocale = Platform.localeName;

  String get _selectedLocaleIdentifier => _selectedLanguage.identifier;

  String get _instructions =>
      'You are a helpful, versatile assistant. Always respond in '
      '${_selectedLanguage.displayName} using locale '
      '${_selectedLanguage.identifier}, unless the user explicitly asks for '
      'another language. Fulfill creative requests such as stories, poems, '
      'or brainstorming. Give complete, well-developed answers; only be '
      'brief when the user asks for brevity.';

  @override
  void initState() {
    super.initState();
    _selectedLanguage = FoundationModelsLanguage(
      identifier: _deviceLocale,
      languageCode: _languageCode(_deviceLocale),
      displayName: _deviceLocale,
      nativeDisplayName: _deviceLocale,
      isTranscriptionAssetInstalled: false,
    );
    _configureChat();
    unawaited(_loadSupportedLanguages());
  }

  void _configureChat() {
    _orchestrator = FoundationModelsOrchestrator(
      apple: _models,
      externalProvider: geminiApiKey.isEmpty
          ? null
          : const GeminiExternalProvider(apiKey: geminiApiKey),
      router: switch (_backend) {
        ChatBackend.auto => FoundationModelsRoutingPolicy.hybrid(
          allowPrivateCloud: true,
          allowExternalFallback: geminiApiKey.isNotEmpty,
        ),
        ChatBackend.local => FoundationModelsRoutingPolicy.localOnly(),
        ChatBackend.privateCloud =>
          FoundationModelsRoutingPolicy.privateCloudFirst(
            allowLocalFallback: false,
          ),
        ChatBackend.gemini => FoundationModelsRoutingPolicy.externalFirst(
          allowAppleFallback: false,
        ),
      },
      defaults: FoundationModelsDefaults(
        localeIdentifier: _selectedLocaleIdentifier,
        options: const GenerationOptions(maximumResponseTokens: 2000),
        tools: const <ModelTool>[DeviceTimeTool()],
      ),
    );
    _chat = _orchestrator.startChat(instructions: _instructions);
  }

  Future<void> _loadSupportedLanguages() async {
    try {
      final List<FoundationModelsLanguage> languages = await _models
          .getSupportedLanguages();
      if (!mounted) {
        return;
      }

      if (languages.isEmpty) {
        setState(() {
          _supportedLanguages = <FoundationModelsLanguage>[];
          _loadingLanguages = false;
          _languageLoadError =
              'No language is currently shared by Apple Intelligence and '
              'live transcription on this device.';
        });
        await _refreshAvailability();
        return;
      }

      final String deviceLocale = _normalizedLocale(_deviceLocale);
      final String deviceLanguage = _languageCode(_deviceLocale);
      FoundationModelsLanguage? preferred;
      for (final FoundationModelsLanguage language in languages) {
        if (_normalizedLocale(language.identifier) == deviceLocale) {
          preferred = language;
          break;
        }
      }
      if (preferred == null) {
        for (final FoundationModelsLanguage language in languages) {
          if (language.languageCode.toLowerCase() == deviceLanguage) {
            preferred = language;
            break;
          }
        }
      }
      preferred ??= languages.first;

      final FoundationModelsChatSession previous = _chat;
      setState(() {
        _supportedLanguages = languages;
        _selectedLanguage = preferred!;
        _loadingLanguages = false;
        _languageLoadError = null;
        _configureChat();
      });
      await previous.dispose();
      await _refreshAvailability();
    } on FoundationModelsException catch (error) {
      if (mounted) {
        setState(() {
          _loadingLanguages = false;
          _languageLoadError = error.recoverySuggestion ?? error.message;
        });
        await _refreshAvailability();
      }
    } on Object catch (error) {
      if (mounted) {
        setState(() {
          _loadingLanguages = false;
          _languageLoadError = 'Could not load languages: $error';
        });
        await _refreshAvailability();
      }
    }
  }

  Future<void> _showLanguagePicker() async {
    if (_loadingLanguages) {
      _showSnack('Loading available languages…');
      return;
    }
    if (_supportedLanguages.isEmpty) {
      _showSnack(
        _languageLoadError ?? 'No compatible languages are available.',
      );
      return;
    }

    final FoundationModelsLanguage? language =
        await showModalBottomSheet<FoundationModelsLanguage>(
          context: context,
          isScrollControlled: true,
          showDragHandle: true,
          builder: (BuildContext context) {
            return _LanguagePickerSheet(
              languages: _supportedLanguages,
              selectedIdentifier: _selectedLocaleIdentifier,
            );
          },
        );
    if (language != null) {
      await _switchLanguage(language);
    }
  }

  Future<void> _switchLanguage(FoundationModelsLanguage language) async {
    if (_normalizedLocale(language.identifier) ==
        _normalizedLocale(_selectedLocaleIdentifier)) {
      return;
    }

    await _stopLiveTranscription();
    if (!mounted) {
      return;
    }
    final FoundationModelsChatSession previous = _chat;
    setState(() {
      _selectedLanguage = language;
      _messages.clear();
      _transcriptionEngine = null;
      _configureChat();
    });
    await previous.dispose();
    await _refreshAvailability();
    _showSnack(
      'Language changed to ${language.nativeDisplayName}. '
      'A new conversation was started.',
    );
  }

  static String _normalizedLocale(String identifier) {
    return identifier.replaceAll('_', '-').toLowerCase();
  }

  static String _languageCode(String identifier) {
    return _normalizedLocale(identifier).split('-').first;
  }

  Future<void> _switchBackend(ChatBackend backend) async {
    if (backend == _backend) {
      return;
    }
    final FoundationModelsChatSession previous = _chat;
    setState(() {
      _backend = backend;
      _messages.clear();
      _configureChat();
    });
    await previous.dispose();
  }

  String _backendLabel(ChatBackend backend) {
    return switch (backend) {
      ChatBackend.auto => 'Auto (hybrid)',
      ChatBackend.local => 'Apple on-device',
      ChatBackend.privateCloud => 'Private Cloud Compute',
      ChatBackend.gemini => 'Gemini',
    };
  }

  @override
  void dispose() {
    unawaited(_liveTranscription?.cancel());
    unawaited(_chat.dispose());
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _refreshAvailability() async {
    try {
      final ModelAvailability availability = await _models.checkAvailability(
        mode: ModelMode.local,
        localeIdentifier: _selectedLocaleIdentifier,
      );
      if (mounted) {
        setState(() => _localAvailability = availability);
      }
    } on FoundationModelsException catch (error) {
      if (mounted) {
        setState(
          () =>
              _localAvailability = ModelAvailability.fromMap(<Object?, Object?>{
                'status': 'unavailable',
                'reason': error.message,
              }),
        );
      }
    }
  }

  Future<void> _send() async {
    if (_loadingLanguages) {
      _showSnack('Wait while compatible languages are loaded.');
      return;
    }
    final String text = _input.text.trim();
    if (text.isEmpty || _sending) {
      return;
    }

    final PickedFoundationModelsFile? attachment = _pendingAttachment;
    final ChatMessageView reply = ChatMessageView(
      isUser: false,
      text: '',
      isStreaming: true,
    );
    setState(() {
      _sending = true;
      _pendingAttachment = null;
      _messages
        ..add(
          ChatMessageView(
            isUser: true,
            text: text,
            attachmentName: attachment?.name,
          ),
        )
        ..add(reply);
      _input.clear();
    });
    _scrollToEnd();

    try {
      await _stopLiveTranscription();
      final Stream<OrchestratedChatEvent> stream = _chat.sendStream(
        text,
        attachments: <PromptAttachment>[
          if (attachment != null)
            attachment.toPromptAttachment(label: attachment.name),
        ],
      );
      await for (final OrchestratedChatEvent event in stream) {
        if (!mounted) {
          return;
        }
        switch (event) {
          case OrchestratedChatTextEvent():
            setState(() {
              reply
                ..text = event.text
                ..providerName = event.route.label;
            });
          case OrchestratedChatCompletionEvent():
            setState(() {
              reply
                ..text = event.response.text
                ..providerName = event.response.providerName
                ..isStreaming = false;
            });
        }
        _scrollToEnd();
      }
    } on FoundationModelsException catch (error) {
      if (mounted) {
        setState(() {
          reply
            ..text = error.recoverySuggestion ?? error.message
            ..providerName = 'error: ${error.code.name}'
            ..isStreaming = false;
        });
      }
    } on Object catch (error) {
      if (mounted) {
        setState(() {
          reply
            ..text = 'Unexpected request failure: $error'
            ..providerName = 'error'
            ..isStreaming = false;
        });
      }
    } finally {
      if (mounted) {
        setState(() => _sending = false);
      }
      _scrollToEnd();
    }
  }

  Future<void> _toggleLiveTranscription() async {
    if (_loadingLanguages) {
      _showSnack('Wait while compatible languages are loaded.');
      return;
    }
    if (_listening) {
      await _stopLiveTranscription();
      return;
    }

    setState(() {
      _listening = true;
      _transcriptionEngine = null;
    });
    _liveTranscription = _models
        .liveTranscription(
          request: LiveTranscriptionRequest(
            localeIdentifier: _selectedLocaleIdentifier,
            mode: AudioTranscriptionMode.automatic,
          ),
        )
        .listen(
          (LiveTranscriptionEvent event) {
            _input
              ..text = event.text
              ..selection = TextSelection.collapsed(offset: event.text.length);
            final String? engine = event.metadata['engine'] as String?;
            if (mounted && engine != null && engine != _transcriptionEngine) {
              setState(() => _transcriptionEngine = engine);
            }
            if (event.isFinal && mounted) {
              setState(() => _listening = false);
            }
          },
          onError: (Object error) {
            final String message = error is FoundationModelsException
                ? (error.recoverySuggestion ?? error.message)
                : error.toString();
            _showSnack(message);
            if (mounted) {
              setState(() => _listening = false);
            }
          },
          onDone: () {
            if (mounted && _listening) {
              setState(() => _listening = false);
            }
          },
        );
  }

  Future<void> _stopLiveTranscription() async {
    final StreamSubscription<LiveTranscriptionEvent>? subscription =
        _liveTranscription;
    _liveTranscription = null;
    if (subscription != null) {
      await subscription.cancel();
    }
    if (mounted && _listening) {
      setState(() => _listening = false);
    }
  }

  Future<void> _pickAttachment() async {
    try {
      final PickedFoundationModelsFile? file = await _models.pickFile();
      if (file != null && mounted) {
        setState(() => _pendingAttachment = file);
      }
    } on FoundationModelsException catch (error) {
      _showSnack(error.recoverySuggestion ?? error.message);
    }
  }

  Future<void> _resetChat() async {
    await _chat.reset();
    if (mounted) {
      setState(_messages.clear);
    }
  }

  Future<void> _showDiagnostics() async {
    try {
      final FoundationModelsDiagnostics diagnostics = await _models
          .getDiagnostics(localeIdentifier: _selectedLocaleIdentifier);
      final String runtimeContext = await _orchestrator
          .buildRuntimePromptContext(refresh: true);
      if (!mounted) {
        return;
      }
      await showDialog<void>(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Text('Diagnostics'),
            content: SingleChildScrollView(
              child: Text(
                'OS: ${diagnostics.platform} '
                '${diagnostics.operatingSystemVersion}\n'
                'Device locale: ${diagnostics.currentLocaleIdentifier}\n'
                'Selected locale: ${diagnostics.targetLocaleIdentifier}\n'
                'Local model: ${diagnostics.localAvailability.status.name}\n'
                'PCC: '
                '${diagnostics.privateCloudAvailability?.status.name ?? 'unknown'}'
                '\n\n$runtimeContext',
              ),
            ),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Close'),
              ),
            ],
          );
        },
      );
    } on FoundationModelsException catch (error) {
      _showSnack(error.recoverySuggestion ?? error.message);
    }
  }

  void _showSnack(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        unawaited(
          _scroll.animateTo(
            _scroll.position.maxScrollExtent,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
          ),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final ModelAvailability? availability = _localAvailability;
    final bool localReady = availability?.isAvailable ?? false;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Text('Foundation Models Chat'),
            Text(
              '${_backendLabel(_backend)} · '
              '${_selectedLanguage.nativeDisplayName}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
        actions: <Widget>[
          IconButton(
            tooltip: _loadingLanguages
                ? 'Loading languages'
                : 'Language: ${_selectedLanguage.nativeDisplayName}',
            onPressed: _sending ? null : _showLanguagePicker,
            icon: _loadingLanguages
                ? const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.language),
          ),
          PopupMenuButton<ChatBackend>(
            tooltip: 'Model backend',
            icon: const Icon(Icons.cloud_outlined),
            enabled: !_sending && !_loadingLanguages,
            onSelected: (ChatBackend backend) =>
                unawaited(_switchBackend(backend)),
            itemBuilder: (BuildContext context) {
              return <PopupMenuEntry<ChatBackend>>[
                for (final ChatBackend backend in ChatBackend.values)
                  CheckedPopupMenuItem<ChatBackend>(
                    value: backend,
                    checked: backend == _backend,
                    enabled:
                        backend != ChatBackend.gemini ||
                        geminiApiKey.isNotEmpty,
                    child: Text(_backendLabel(backend)),
                  ),
              ];
            },
          ),
          PopupMenuButton<_ChatAction>(
            tooltip: 'More actions',
            onSelected: (_ChatAction action) {
              switch (action) {
                case _ChatAction.diagnostics:
                  unawaited(_showDiagnostics());
                case _ChatAction.reset:
                  unawaited(_resetChat());
              }
            },
            itemBuilder: (BuildContext context) {
              return <PopupMenuEntry<_ChatAction>>[
                const PopupMenuItem<_ChatAction>(
                  value: _ChatAction.diagnostics,
                  child: ListTile(
                    leading: Icon(Icons.info_outline),
                    title: Text('Diagnostics'),
                  ),
                ),
                PopupMenuItem<_ChatAction>(
                  value: _ChatAction.reset,
                  enabled: !_sending,
                  child: const ListTile(
                    leading: Icon(Icons.refresh),
                    title: Text('Reset conversation'),
                  ),
                ),
              ];
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: <Widget>[
            if (availability != null && !localReady)
              MaterialBanner(
                content: Text(
                  'Apple on-device model unavailable: '
                  '${availability.recoverySuggestion ?? availability.reason ?? availability.status.name}',
                ),
                leading: const Icon(Icons.warning_amber),
                actions: <Widget>[
                  TextButton(
                    onPressed: _refreshAvailability,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            Expanded(
              child: _messages.isEmpty
                  ? _EmptyChatHint(
                      localReady: localReady,
                      hasExternalProvider: geminiApiKey.isNotEmpty,
                    )
                  : ListView.builder(
                      controller: _scroll,
                      padding: const EdgeInsets.all(12),
                      itemCount: _messages.length,
                      itemBuilder: (BuildContext context, int index) {
                        return _MessageBubble(message: _messages[index]);
                      },
                    ),
            ),
            if (_pendingAttachment != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: InputChip(
                    avatar: const Icon(Icons.image_outlined, size: 18),
                    label: Text(_pendingAttachment!.name),
                    onDeleted: () => setState(() => _pendingAttachment = null),
                  ),
                ),
              ),
            if (_listening)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    _transcriptionEngine == null
                        ? 'Listening ($_selectedLocaleIdentifier)…'
                        : 'Listening ($_selectedLocaleIdentifier, '
                              'engine: $_transcriptionEngine)',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ),
            _InputBar(
              controller: _input,
              sending: _sending,
              listening: _listening,
              onPickAttachment: _pickAttachment,
              onToggleMicrophone: _toggleLiveTranscription,
              onSend: _send,
            ),
          ],
        ),
      ),
    );
  }
}

final class _LanguagePickerSheet extends StatefulWidget {
  const _LanguagePickerSheet({
    required this.languages,
    required this.selectedIdentifier,
  });

  final List<FoundationModelsLanguage> languages;
  final String selectedIdentifier;

  @override
  State<_LanguagePickerSheet> createState() => _LanguagePickerSheetState();
}

final class _LanguagePickerSheetState extends State<_LanguagePickerSheet> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final String normalizedQuery = _query.trim().toLowerCase();
    final List<FoundationModelsLanguage> visibleLanguages = widget.languages
        .where((FoundationModelsLanguage language) {
          if (normalizedQuery.isEmpty) {
            return true;
          }
          return language.nativeDisplayName.toLowerCase().contains(
                normalizedQuery,
              ) ||
              language.displayName.toLowerCase().contains(normalizedQuery) ||
              language.identifier.toLowerCase().contains(normalizedQuery);
        })
        .toList(growable: false);

    return SafeArea(
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.72,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'Choose language',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Applies to AI responses and live transcription.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 16),
                  SearchBar(
                    hintText: 'Search languages',
                    leading: const Icon(Icons.search),
                    onChanged: (String value) => setState(() => _query = value),
                  ),
                ],
              ),
            ),
            Expanded(
              child: visibleLanguages.isEmpty
                  ? const Center(child: Text('No languages match your search.'))
                  : ListView.builder(
                      padding: const EdgeInsets.only(bottom: 12),
                      itemCount: visibleLanguages.length,
                      itemBuilder: (BuildContext context, int index) {
                        final FoundationModelsLanguage language =
                            visibleLanguages[index];
                        final bool selected =
                            _ChatScreenState._normalizedLocale(
                              language.identifier,
                            ) ==
                            _ChatScreenState._normalizedLocale(
                              widget.selectedIdentifier,
                            );
                        final String details = <String>[
                          if (language.displayName !=
                              language.nativeDisplayName)
                            language.displayName,
                          language.identifier,
                          if (!language.isTranscriptionAssetInstalled)
                            'Speech download required',
                        ].join(' · ');
                        return ListTile(
                          leading: Icon(
                            language.isTranscriptionAssetInstalled
                                ? Icons.record_voice_over_outlined
                                : Icons.cloud_download_outlined,
                          ),
                          title: Text(language.nativeDisplayName),
                          subtitle: Text(details),
                          trailing: selected
                              ? const Icon(Icons.check_circle)
                              : null,
                          selected: selected,
                          onTap: () => Navigator.of(context).pop(language),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

final class _EmptyChatHint extends StatelessWidget {
  const _EmptyChatHint({
    required this.localReady,
    required this.hasExternalProvider,
  });

  final bool localReady;
  final bool hasExternalProvider;

  @override
  Widget build(BuildContext context) {
    final String routes = <String>[
      if (localReady) 'Apple on-device model',
      'Private Cloud Compute (when available)',
      if (hasExternalProvider) 'Gemini fallback',
    ].join(' + ');
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(Icons.forum_outlined, size: 56),
            const SizedBox(height: 12),
            Text(
              'Start chatting with $routes.\n\n'
              'Use the mic for live transcription and the image button to '
              'attach a picture to your prompt.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

final class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message});

  final ChatMessageView message;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final bool isUser = message.isUser;
    final String body = message.text.isEmpty && message.isStreaming
        ? '…'
        : message.text;

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.8,
        ),
        decoration: BoxDecoration(
          color: isUser ? colors.primary : colors.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            if (message.attachmentName != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Icon(
                      Icons.attachment,
                      size: 14,
                      color: isUser ? colors.onPrimary : colors.onSurface,
                    ),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        message.attachmentName!,
                        style: TextStyle(
                          fontSize: 12,
                          color: isUser ? colors.onPrimary : colors.onSurface,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            Text(
              body,
              style: TextStyle(
                color: isUser ? colors.onPrimary : colors.onSurface,
              ),
            ),
            if (!isUser && message.providerName != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  message.isStreaming
                      ? '${message.providerName} · streaming'
                      : message.providerName!,
                  style: TextStyle(
                    fontSize: 11,
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

final class _InputBar extends StatelessWidget {
  const _InputBar({
    required this.controller,
    required this.sending,
    required this.listening,
    required this.onPickAttachment,
    required this.onToggleMicrophone,
    required this.onSend,
  });

  final TextEditingController controller;
  final bool sending;
  final bool listening;
  final VoidCallback onPickAttachment;
  final VoidCallback onToggleMicrophone;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: <Widget>[
          IconButton(
            tooltip: 'Attach image',
            onPressed: sending ? null : onPickAttachment,
            icon: const Icon(Icons.image_outlined),
          ),
          IconButton(
            tooltip: listening
                ? 'Stop live transcription'
                : 'Start live transcription',
            onPressed: sending ? null : onToggleMicrophone,
            icon: Icon(
              listening ? Icons.mic : Icons.mic_none,
              color: listening ? colors.error : null,
            ),
          ),
          Expanded(
            child: TextField(
              controller: controller,
              minLines: 1,
              maxLines: 5,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => onSend(),
              decoration: InputDecoration(
                hintText: listening ? 'Listening…' : 'Message',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
              ),
            ),
          ),
          const SizedBox(width: 4),
          IconButton.filled(
            tooltip: 'Send',
            onPressed: sending ? null : onSend,
            icon: sending
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.arrow_upward),
          ),
        ],
      ),
    );
  }
}

# Cupertino Foundations Models

Apple Intelligence and Apple Foundation Models for Flutter: on-device AI text generation, streaming responses, multi-turn chat with conversation context, live speech-to-text microphone transcription, multimodal image prompts, runtime diagnostics, Private Cloud Compute on iOS 27, and hybrid orchestration that combines the local Apple model with an external provider such as Gemini, ChatGPT, or your own backend.

This package is designed as a native-first Flutter plugin. It uses Dart DTOs and Flutter platform channels on the public side, and Apple frameworks (Foundation Models, Speech, AVFoundation) on the iOS side. It has zero runtime third-party dependencies.

## Status

This package is iOS-only and targets real-device use of Apple Intelligence and Foundation Models on iOS 26 and iOS 27.

Implemented:

- Runtime capabilities and availability diagnostics.
- Local on-device text generation through `SystemLanguageModel`.
- `LanguageModelSession` handles for multi-turn conversation context.
- One-shot `respond()` convenience calls.
- Streaming responses.
- Native tool calling: Dart tools invoked by the on-device or PCC model.
- Native guided structured generation with runtime JSON-like schemas.
- Hybrid orchestration and multi-turn hybrid chat across Apple local, Private Cloud Compute, and app-provided external providers.
- Text and image prompt attachments.
- Audio file transcription with `SpeechAnalyzer`/`SpeechTranscriber` on iOS 26+ and an `SFSpeechRecognizer` fallback.
- Live microphone transcription with the iOS 27 capture provider, the iOS 26 `SpeechAnalyzer` pipeline, and an `SFSpeechRecognizer` fallback.
- Session prewarm and in-flight request cancellation.
- Content-tagging on-device model variant.
- Explicit local, automatic, and Private Cloud Compute mode selection.
- Stable Dart error codes with recovery suggestions.
- Prompt and local transcript token counting through Apple's tokenizer.
- Typed iOS 27 response usage, PCC quota state, and transcript error policy.
- Swift Package Manager and CocoaPods support.
- iOS chat example app with streaming, live transcription, tool calling, and attachments.

In progress:

- Direct Photos picker.
- Dynamic Profiles and the iOS 27 `LanguageModel` protocol bridge.

## Platform Support

This Flutter plugin currently supports iOS only. The `platforms` field in `pubspec.yaml` is intentionally restricted to iOS so pub.dev does not advertise Android, Linux, macOS, Web, or Windows support.

| Capability | Apple API | Minimum OS | Notes |
| --- | --- | --- | --- |
| Local text generation | `SystemLanguageModel`, `LanguageModelSession` | iOS 26+ | Requires Apple Intelligence, supported language, and downloaded model assets. |
| Conversation context | `LanguageModelSession` transcript | iOS 26+ | Reuse the same `FoundationModelSession`; one-shot calls are stateless. |
| Streaming | `streamResponse` | iOS 26+ | Emits model text updates and completion events. |
| Context size diagnostics | `contextSize` | iOS 26+ | Local model context is limited; manage long conversations. |
| Token counting | `tokenCount(for:)` | iOS 26.4+ | Counts a prompt or the transcript of a local session. Requires an Xcode 27 build in this package release. |
| Tool calling | `Tool` | iOS 26+ | Dart `ModelTool` implementations are called by the native model. |
| Guided structured output | `DynamicGenerationSchema`, `GenerationSchema` | iOS 26+ | Runtime schemas built from Dart; the model returns validated JSON. |
| Content tagging | `SystemLanguageModel(useCase: .contentTagging)` | iOS 26+ | Specialized on-device model for categorizing text. |
| Session prewarm | `prewarm(promptPrefix:)` | iOS 26+ | Preloads model resources for lower first-token latency. |
| Image prompts | Vision preprocessing; `Attachment<ImageAttachmentContent>` when runtime-safe | iOS 27+ | iOS 27 beta 5 crashes before throwing when its native attachment ABI is called, so this package uses local OCR, classification, and barcode context on that runtime. |
| Reasoning options | `ContextOptions.ReasoningLevel` | iOS 27+ | Requires building with Xcode 27, beta or official. Mapped from Dart `ReasoningLevel`. |
| Private Cloud Compute | `PrivateCloudComputeLanguageModel` | iOS 27+ | Requires building with Xcode 27, beta or official, plus Apple availability, network, quota, and entitlement. |
| Audio transcription | `SpeechAnalyzer`, `AssetInputSequenceProvider` | iOS 26+ (fallback iOS 13+) | Accurate on-device file transcription; beta 5 uses the native asset input provider on iOS 27. Explicit server mode uses `SFSpeechRecognizer`. |
| Live microphone transcription | `SpeechAnalyzer`, `CaptureInputSequenceProvider` | iOS 26+ (fallback iOS 13+) | iOS 27 uses Apple's native capture provider; iOS 26 uses a validated audio-buffer pipeline. Requires microphone and speech permissions. |

## Conversation Context

Yes, Apple Foundation Models support conversation context through `LanguageModelSession`.

Use `createSession()` when you want a multi-turn conversation. The native session keeps its transcript while the session is alive, so each `session.respond()` or `session.stream()` call can use previous turns as context.

```dart
final CupertinoFoundationModels models = CupertinoFoundationModels();

final FoundationModelSession session = await models.createSession(
  options: const SessionOptions(
    mode: ModelMode.local,
    cloudPolicy: CloudPolicy.never,
    instructions: 'You are a concise assistant. Answer in English.',
  ),
);

try {
  final ModelResponse first = await session.respond(
    const Prompt.text('My app helps users organize personal finances.'),
  );

  final ModelResponse second = await session.respond(
    const Prompt.text('Based on what I just told you, suggest three feature names.'),
  );

  print(first.text);
  print(second.text);
} finally {
  await session.dispose();
}
```

Use `models.respond()` only for single-turn requests. It creates a native session, sends one prompt, then disposes the session, so it does not preserve conversation history.

## Installation

Add the package to your Flutter app:

```yaml
dependencies:
  cupertino_fundations_models: ^0.2.1
```

Then import it:

```dart
import 'package:cupertino_fundations_models/cupertino_fundations_models.dart';
```

## iOS Setup

Use a real Apple Intelligence-compatible device. Simulator support for these APIs is limited and can differ across iOS betas.

For speech transcription, add these keys to your app `Info.plist`:

```xml
<key>NSSpeechRecognitionUsageDescription</key>
<string>This app uses speech recognition to transcribe selected audio files.</string>
<key>NSMicrophoneUsageDescription</key>
<string>This app can use audio input for speech transcription.</string>
```

Features that require iOS 27 must be compiled with Xcode 27, either the beta or the official release if it is already available. For iOS 27 beta development, build with the iOS 27 SDK:

```bash
DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer flutter build ios
```

Always use `checkAvailability()` and `supportsLocale()` diagnostics at runtime. Availability depends on Apple Intelligence settings, downloaded model assets, device eligibility, and the selected model's supported languages.

## Availability First

Always check availability before sending a model request.

```dart
final CupertinoFoundationModels models = CupertinoFoundationModels();

final ModelAvailability availability = await models.checkAvailability(
  mode: ModelMode.local,
  cloudPolicy: CloudPolicy.never,
  localeIdentifier: 'en_US',
);

if (!availability.isAvailable) {
  throw StateError(
    availability.recoverySuggestion ?? availability.reason ?? availability.status.name,
  );
}
```

Use diagnostics when availability is not enough:

```dart
final FoundationModelsDiagnostics diagnostics = await models.getDiagnostics(
  localeIdentifier: 'en_US',
);

print(diagnostics.currentLocaleIdentifier);
print(diagnostics.localAvailability.status.name);
print(diagnostics.localSupportedLanguages);
```

Use the same compatible locale for model generation and transcription:

```dart
final List<FoundationModelsLanguage> languages =
    await models.getSupportedLanguages();
final FoundationModelsLanguage spanish = languages.firstWhere(
  (FoundationModelsLanguage language) => language.languageCode == 'es',
);

final FoundationModelsOrchestrator ai = FoundationModelsOrchestrator(
  defaults: FoundationModelsDefaults(
    localeIdentifier: spanish.identifier,
    instructions: 'Respond in ${spanish.displayName}.',
  ),
);

final Stream<LiveTranscriptionEvent> dictation = models.liveTranscription(
  request: LiveTranscriptionRequest(
    localeIdentifier: spanish.identifier,
  ),
);
```

`getSupportedLanguages()` returns the runtime intersection of locales accepted
by `SystemLanguageModel.supportsLocale(_:)` and
`SpeechTranscriber.supportedLocales`. Each entry reports whether its speech
asset is already installed; the first transcription may take longer when the
asset still needs to download.

## Hybrid Orchestration

Use `FoundationModelsOrchestrator` when your app already has a larger AI
orchestrator and wants Apple models as a primary, secondary, or cost-saving
route. The Apple bridge stays available through `CupertinoFoundationModels`;
the orchestrator only adds route selection and external-provider fallback.

```dart
final FoundationModelsOrchestrator ai = FoundationModelsOrchestrator(
  defaults: const FoundationModelsDefaults(
    localeIdentifier: 'es_CO',
    instructions: 'Respond in Spanish. Prefer private, low-cost routes.',
    options: GenerationOptions(maximumResponseTokens: 240),
  ),
  router: FoundationModelsRoutingPolicy.hybrid(
    allowPrivateCloud: true,
    allowExternalFallback: true,
  ),
  externalProvider: YourGeminiProvider(),
);

final String runtimeContext = await ai.buildRuntimePromptContext();
print(runtimeContext);

final OrchestratedModelResponse response = await ai.respondText(
  'Resume este texto y extrae las acciones importantes.',
  task: FoundationModelsTask.summarize,
);

print(response.providerName);
print(response.text);
```

The built-in policies are:

- `localOnly()`: only Apple on-device models.
- `appleFirst()`: Apple local first, then optional PCC or external fallback.
- `privateCloudFirst()`: Private Cloud Compute first (iOS 27+), with optional
  local and external fallbacks.
- `externalFirst()`: external provider first, with optional Apple fallback.
- `hybrid()`: local-first for simple work, external-first for complex reasoning
  and tool-routing tasks.

External providers are app adapters. The package does not ship API clients for
Gemini, OpenAI, Anthropic, or a custom backend, but it gives those adapters the
same `Prompt`, `GenerationOptions`, `StructuredSchema`, task metadata, and
conversation history used by Apple routes. Override
`FoundationModelsExternalProvider.respondStream()` to stream cumulative text
snapshots from providers that support server streaming.

## Hybrid Chat

Use `startChat()` for a multi-turn conversation that survives route fallback.
Apple turns reuse one persistent native `LanguageModelSession`; when a turn is
served by the external provider, the shared history is replayed through
`FoundationModelsRequest.history`, so Gemini, ChatGPT, or your backend sees the
same conversation.

```dart
final FoundationModelsChatSession chat = ai.startChat(
  instructions: 'You are a concise assistant.',
);

await for (final OrchestratedChatEvent event in chat.sendStream(
  'Summarize my week in three bullet points.',
)) {
  switch (event) {
    case OrchestratedChatTextEvent():
      // Cumulative snapshot: replace the rendered text.
      print(event.text);
    case OrchestratedChatCompletionEvent():
      print('answered by ${event.response.providerName}');
  }
}

await chat.dispose();
```

`chat.send()` is the non-streaming variant, `chat.history` exposes the turns,
and `chat.reset()` clears the conversation.

## Local Generation

```dart
final ModelResponse response = await models.respond(
  const Prompt.text('Summarize why on-device AI is useful.'),
  mode: ModelMode.local,
  cloudPolicy: CloudPolicy.never,
  instructions: 'Answer in English with one sentence.',
  options: const GenerationOptions(maximumResponseTokens: 120),
);

print(response.text);
```

## Streaming

```dart
final FoundationModelSession session = await models.createSession(
  options: const SessionOptions(
    mode: ModelMode.local,
    cloudPolicy: CloudPolicy.never,
  ),
);

try {
  await for (final SessionEvent event in session.stream(
    const Prompt.text('Write a short product description.'),
    options: const GenerationOptions(maximumResponseTokens: 180),
  )) {
    switch (event) {
      case TextSnapshotEvent():
        print(event.text);
      case CompletionEvent():
        print(event.response.text);
      case FailureEvent():
        print(event.message);
      case ToolCallEvent():
        print(event.name);
      case UnknownSessionEvent():
        print(event.payload);
    }
  }
} finally {
  await session.dispose();
}
```

Treat `TextSnapshotEvent.text` as the latest cumulative text snapshot emitted by the native stream.

## Tool Calling

Declare tools in Dart; the on-device model decides when to call them and the
result flows back into the generation.

```dart
final class WeatherTool implements ModelTool {
  const WeatherTool();

  @override
  String get name => 'get_weather';

  @override
  String get description => 'Returns the current weather for a city.';

  @override
  Map<String, Object?> get parameters => const <String, Object?>{
    'type': 'object',
    'properties': <String, Object?>{
      'city': <String, Object?>{'type': 'string', 'description': 'City name'},
    },
    'requiredProperties': <String>['city'],
  };

  @override
  Duration get timeout => const Duration(seconds: 10);

  @override
  Future<Object?> call(Map<String, Object?> arguments) async {
    return lookUpWeather(arguments['city']! as String);
  }
}

final FoundationModelSession session = await models.createSession(
  options: const SessionOptions(
    mode: ModelMode.local,
    tools: <ModelTool>[WeatherTool()],
  ),
);
```

Keep tool names and descriptions short: they consume context-window tokens.
iOS 27 beta 5 fixes the excessive tool-call issue Apple documented for earlier
betas when tool calling and guided generation were used together.

## Structured Output

`generateStructured()` uses Apple guided generation, so the model output is
constrained to your schema and returned as validated JSON.

```dart
final ModelResponse response = await models.generateStructured(
  prompt: const Prompt.text('Extract the contact details from this email...'),
  schema: const StructuredSchema.object(
    name: 'Contact',
    properties: <String, SchemaProperty>{
      'name': SchemaProperty.string(),
      'email': SchemaProperty.string(),
      'topics': SchemaProperty.array(items: SchemaProperty.string()),
    },
    requiredProperties: <String>['name'],
  ),
  mode: ModelMode.local,
);

print(response.structuredValue); // Object?, List<Object?>, or Map<String, Object?>
```

Root arrays and scalar schemas now preserve their real value instead of being
dropped when the result isn't a JSON object.

## Performance

- Call `session.prewarm()` when you know a request is coming within a second
  or two; it preloads model resources and lowers first-token latency.
- Reuse a session only when you need the conversation history; use one-shot
  `respond()` for independent requests.
- Keep instructions and tools stable for the life of a session to preserve the
  native KV cache.
- Prefer streaming for responsive UIs, and cap `maximumResponseTokens` when
  the UI does not need long answers.
- Use `session.cancelActiveRequest()` to stop an in-flight request; it
  surfaces as the `cancelled` error code.
- Use `FoundationModelsUseCase.contentTagging` for tagging/categorization
  workloads instead of prompting the general model.

## Token Counts And Usage

Count a prompt before sending it on iOS 26.4 or later:

```dart
final int promptTokens = await models.countTokens(
  const Prompt.text('Summarize this note.'),
);
```

For a local multi-turn session, inspect the whole current transcript:

```dart
final int transcriptTokens = await session.countTokens();
```

On iOS 27, completed responses expose typed usage through `response.usage`,
including input, cached input, output, reasoning, and total token counts.
Use `ReasoningLevel.light`, `.moderate`, `.deep`, or
`ReasoningLevel.custom('provider-level')` when the selected iOS 27 model
documents a custom reasoning level.

## Image And Text Attachments

The package can select files with the native iOS document picker and attach supported files to a prompt.

```dart
final PickedFoundationModelsFile? image = await models.pickFile(
  kind: FoundationModelsFileKind.image,
);

if (image == null) {
  return;
}

final ModelResponse response = await models.respond(
  Prompt(
    text: 'Describe the important details in this image.',
    attachments: <PromptAttachment>[
      image.toPromptAttachment(label: image.name),
    ],
  ),
  mode: ModelMode.local,
  cloudPolicy: CloudPolicy.never,
);
```

Current attachment behavior:

- UTF-8 text, Markdown, JSON, and CSV files are inserted into the prompt, up to 5 MB.
- Text-based PDFs are extracted locally with PDFKit and inserted into the prompt. Scanned PDFs need OCR first.
- Images up to 50 MB are decoded and downsampled locally. On iOS 27 beta 5, Vision OCR, classification, and barcode results are inserted as safe prompt context because the published native Foundation Models attachment API terminates the process before Swift can catch an error.
- Audio files are not attached directly to Foundation Models; transcribe them first with `transcribeAudio()`.
- Word `.doc` and `.docx` files are not natively readable on iOS. Export them as a text-based PDF or UTF-8 text before attaching them.
- Unsupported, corrupt, empty, inaccessible, or oversized files return a typed error instead of being silently ignored.

## Audio Transcription

Audio transcription uses `Speech.framework`.

```dart
final PickedFoundationModelsFile? audio = await models.pickFile(
  kind: FoundationModelsFileKind.audio,
);

if (audio == null) {
  return;
}

final AudioTranscriptionResult transcript = await models.transcribeAudio(
  AudioTranscriptionRequest(
    filePath: audio.path,
    localeIdentifier: 'en_US',
    mode: AudioTranscriptionMode.onDevice,
  ),
);

final ModelResponse response = await models.respond(
  Prompt.text(transcript.text),
  mode: ModelMode.local,
  cloudPolicy: CloudPolicy.never,
);
```

Use `AudioTranscriptionMode.onDevice` to require local speech recognition. Use `server` only when your app allows Apple Speech's remote path.

On iOS 26 or later, file transcription uses `SpeechAnalyzer`, the modern long-form on-device engine. On iOS 27 beta 5 it also uses `AssetInputSequenceProvider` so Speech performs file decoding, audio conversion, and backpressure. `AudioTranscriptionRequest.timeout` cancels the native task and reports `transcriptionTimeout` instead of leaving work running in the background. The first request for a locale can still take longer while Apple downloads its speech assets.

## Live Microphone Transcription

Stream speech-to-text from the microphone while the user talks. Each event is
the best snapshot recognized so far; the stream closes after the final result,
and cancelling the subscription stops the microphone.

```dart
final StreamSubscription<LiveTranscriptionEvent> subscription = models
    .liveTranscription(
      request: const LiveTranscriptionRequest(
        localeIdentifier: 'en_US',
        mode: AudioTranscriptionMode.automatic,
      ),
    )
    .listen((LiveTranscriptionEvent event) {
      print(event.text);
      if (event.isFinal) {
        print('done');
      }
    });

// Later, to stop dictation early:
await subscription.cancel();
```

Live transcription requires `NSMicrophoneUsageDescription` and
`NSSpeechRecognitionUsageDescription` in your app `Info.plist`.

The example's language button lists only locales shared by the Apple model and
live transcription. Selecting one updates both features, stops any active
dictation, and opens a new chat session so the previous language does not remain
in the model transcript.

Only one generation request may run on a `FoundationModelSession` or `FoundationModelsChatSession` at a time. Concurrent calls now fail with `concurrentRequests` instead of racing the native session. `GenerationOptions.timeout` is enforced for both one-shot and streaming generation and cancels the native request on timeout.

## Private Cloud Compute

Private Cloud Compute must be explicit.

```dart
final ModelAvailability availability = await models.checkAvailability(
  mode: ModelMode.privateCloudCompute,
  cloudPolicy: CloudPolicy.whenExplicit,
  localeIdentifier: 'en_US',
);

if (availability.isAvailable) {
  final ModelResponse response = await models.respond(
    const Prompt.text('Plan a release checklist.'),
    mode: ModelMode.privateCloudCompute,
    cloudPolicy: CloudPolicy.whenExplicit,
  );
  print(response.text);
}
```

Do not use PCC silently. Keep `CloudPolicy.never` for offline behavior.

## Error Handling

```dart
try {
  final ModelResponse response = await models.respond(
    const Prompt.text('Hello'),
    mode: ModelMode.local,
    cloudPolicy: CloudPolicy.never,
  );
  print(response.text);
} on FoundationModelsException catch (error) {
  print(error.code.name);
  print(error.message);
  print(error.recoverySuggestion);
}
```

Important error codes:

- `appleIntelligenceDisabled`
- `assetsUnavailable`
- `unsupportedLanguage`
- `unsupportedPlatform`
- `unsupportedOsVersion`
- `privateCloudUnavailable`
- `networkUnavailable`
- `quotaExceeded`
- `contextSizeExceeded`
- `rateLimited`
- `guardrailViolation`
- `refusal`
- `unsupportedCapability`
- `unsupportedGenerationGuide`
- `generationTimeout`
- `concurrentRequests`
- `transcriptMutationWhileResponding`
- `parsingFailure`
- `speechRecognitionDenied`
- `speechRecognitionUnavailable`
- `transcriptionTimeout`

## Example App

The example app is in `example/`.

```bash
cd example
flutter pub get
flutter run -d <ios-device-id>
```

The example is a chat app that shows the most important runtime paths from a real iPhone: hybrid orchestration with streaming message bubbles, multi-turn conversation context, live microphone transcription into the input field, image attachments, and runtime diagnostics.

Run it with an optional Gemini fallback to see hybrid routing in action:

```bash
cd example
flutter run -d <ios-device-id> --dart-define=GEMINI_API_KEY=your_key
```

Full example source:

- [`example/lib/main.dart`](example/lib/main.dart)
- [`example/README.md`](example/README.md)

## Documentation

- [`implementation_for_agents.md`](implementation_for_agents.md): integration guide for agents and maintainers.
- [`doc/ios-27-beta-5-foundation-models.md`](doc/ios-27-beta-5-foundation-models.md): official Apple beta 5 research, SDK findings, and the `0.2.0` migration table.
- [Apple Foundation Models documentation](https://developer.apple.com/documentation/FoundationModels)
- [Dart package publishing documentation](https://dart.dev/tools/pub/publishing)

## Agent Skill Guide

This repository includes [`implementation_for_agents.md`](implementation_for_agents.md), a skill-style guide for agents and maintainers. It describes the architecture, supported APIs, availability workflow, conversation context, streaming, attachments, audio transcription, validation commands, and publishing checklist.

Use it when implementing features in an app or extending the package itself.

## Source Code

Source code, issues, and package metadata are linked through `pubspec.yaml`:

- Repository: https://github.com/sooyvilla/cupertino_fundations_models
- Issues: https://github.com/sooyvilla/cupertino_fundations_models/issues
- Documentation: https://github.com/sooyvilla/cupertino_fundations_models#readme

## Package Name

The package is currently named `cupertino_fundations_models`. The intended English term is "foundations", but package names are permanent after publishing. Decide whether to rename before the first public release.

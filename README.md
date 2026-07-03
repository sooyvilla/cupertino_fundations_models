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
- Audio file transcription through `Speech.framework`.
- Live microphone transcription with `SpeechAnalyzer`/`SpeechTranscriber` on iOS 26+ and an `SFSpeechRecognizer` fallback.
- Session prewarm and in-flight request cancellation.
- Content-tagging on-device model variant.
- Explicit local, automatic, and Private Cloud Compute mode selection.
- Stable Dart error codes with recovery suggestions.
- Swift Package Manager and CocoaPods support.
- iOS chat example app with streaming, live transcription, tool calling, and attachments.

In progress:

- Direct Photos picker.
- Token counting (`tokenCount(for:)`, iOS 26.4+).
- Dynamic Profiles and the iOS 27 `LanguageModel` protocol bridge.

## Platform Support

This Flutter plugin currently supports iOS only. The `platforms` field in `pubspec.yaml` is intentionally restricted to iOS so pub.dev does not advertise Android, Linux, macOS, Web, or Windows support.

| Capability | Apple API | Minimum OS | Notes |
| --- | --- | --- | --- |
| Local text generation | `SystemLanguageModel`, `LanguageModelSession` | iOS 26+ | Requires Apple Intelligence, supported language, and downloaded model assets. |
| Conversation context | `LanguageModelSession` transcript | iOS 26+ | Reuse the same `FoundationModelSession`; one-shot calls are stateless. |
| Streaming | `streamResponse` | iOS 26+ | Emits model text updates and completion events. |
| Context size diagnostics | `contextSize` | iOS 26+ | Local model context is limited; manage long conversations. |
| Tool calling | `Tool` | iOS 26+ | Dart `ModelTool` implementations are called by the native model. |
| Guided structured output | `DynamicGenerationSchema`, `GenerationSchema` | iOS 26+ | Runtime schemas built from Dart; the model returns validated JSON. |
| Content tagging | `SystemLanguageModel(useCase: .contentTagging)` | iOS 26+ | Specialized on-device model for categorizing text. |
| Session prewarm | `prewarm(promptPrefix:)` | iOS 26+ | Preloads model resources for lower first-token latency. |
| Image prompts | `Attachment<ImageAttachmentContent>` | iOS 27+ | Requires building with Xcode 27, beta or official. Experimental in the iOS 27 SDK. |
| Reasoning options | `ContextOptions.ReasoningLevel` | iOS 27+ | Requires building with Xcode 27, beta or official. Mapped from Dart `ReasoningLevel`. |
| Private Cloud Compute | `PrivateCloudComputeLanguageModel` | iOS 27+ | Requires building with Xcode 27, beta or official, plus Apple availability, network, quota, and entitlement. |
| Audio transcription | `SFSpeechURLRecognitionRequest` | iOS 13+ | Uses Speech, not Foundation Models. On-device mode requires locale support. |
| Live microphone transcription | `SpeechAnalyzer`, `SpeechTranscriber` | iOS 26+ (fallback iOS 13+) | Modern on-device pipeline with asset management; falls back to `SFSpeechRecognizer`. Requires microphone and speech permissions. |

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
  cupertino_fundations_models: ^0.1.0
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

When testing on the iOS 27 beta, Foundation Models currently work only when the device is fully configured in English, including system language and Siri language.

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
      case TextDeltaEvent():
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

Treat `TextDeltaEvent.text` as the latest text snapshot emitted by the native stream.

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

Keep tool names and descriptions short: they consume context-window tokens. On
the iOS 27 beta, combining tool calling with guided generation can trigger
excessive tool calls; adjust instructions if you hit that.

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

print(response.structuredValue); // Map<String, Object?> validated by the model
```

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

- Text files are read as UTF-8 and inserted into the prompt.
- Image files use Foundation Models image attachments on iOS 27+.
- Audio files are not attached directly to Foundation Models; transcribe them first.

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
- `contextExceeded`
- `speechRecognitionDenied`
- `speechRecognitionUnavailable`

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

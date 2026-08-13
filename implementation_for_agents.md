# Implementation For Agents

This document explains how to use, validate, and extend `cupertino_fundations_models` without rediscovering the package architecture.

## Purpose

`cupertino_fundations_models` is a Flutter plugin with a native Swift bridge for Apple Foundation Models. It provides a Dart API for:

- Runtime capabilities and availability checks.
- Local on-device generation through Apple Intelligence.
- Reusable sessions with conversation context.
- Streaming responses.
- Text and image prompt attachments.
- Audio file transcription through `Speech.framework`.
- Explicit local, automatic, and Private Cloud Compute model selection.
- Typed errors with recovery suggestions.
- Zero runtime third-party dependencies.

Offline means `SystemLanguageModel` with `ModelMode.local` and `CloudPolicy.never`. It still requires Apple Intelligence to be enabled, supported languages to be configured, and model assets to be downloaded by the system.

Audio transcription uses `Speech.framework`, not Foundation Models. On iOS 26+, `onDevice` uses `SpeechAnalyzer`/`SpeechTranscriber`; on iOS 27 the beta 5 input providers handle file and microphone audio conversion. Explicit `server` mode and older systems use `SFSpeechRecognizer`. This is separate from Private Cloud Compute.

## Official References

- Apple Foundation Models: https://developer.apple.com/documentation/FoundationModels
- LanguageModelSession: https://developer.apple.com/documentation/foundationmodels/languagemodelsession
- Transcript: https://developer.apple.com/documentation/foundationmodels/transcript
- Managing the context window: https://developer.apple.com/documentation/foundationmodels/managing-the-context-window
- Optimizing key-value caching: https://developer.apple.com/documentation/foundationmodels/optimizing-key-value-caching-in-language-model-sessions
- Multimodal prompting: https://developer.apple.com/documentation/foundationmodels/analyzing-images-with-multimodal-prompting
- Private Cloud Compute: https://developer.apple.com/documentation/foundationmodels/adding-server-side-intelligence-with-private-cloud-compute
- Tool calling: https://developer.apple.com/documentation/foundationmodels/expanding-generation-with-tool-calling
- Guided generation: https://developer.apple.com/documentation/FoundationModels/generating-swift-data-structures-with-guided-generation
- Speech recognition: https://developer.apple.com/documentation/speech
- SpeechAnalyzer: https://developer.apple.com/documentation/speech/speechanalyzer
- Asset input provider: https://developer.apple.com/documentation/speech/assetinputsequenceprovider
- Capture input provider: https://developer.apple.com/documentation/speech/captureinputsequenceprovider
- Pubspec format: https://dart.dev/tools/pub/pubspec
- Publishing packages: https://dart.dev/tools/pub/publishing
- Writing package pages: https://dart.dev/tools/pub/writing-package-pages

## Current API

Implemented:

- `getCapabilities()`
- `getDiagnostics()`
- `checkAvailability()`
- `supportsFullPower()`
- `createSession()`
- `respond()`
- `stream()` through `FoundationModelSession`
- `pickFile()`
- `transcribeAudio()` with `SpeechAnalyzer` for on-device files on iOS 26+, `AssetInputSequenceProvider` on iOS 27, and a legacy/server fallback.
- `liveTranscription()` streaming microphone speech-to-text with partial results; uses `CaptureInputSequenceProvider` on iOS 27, a validated `SpeechAnalyzer` buffer pipeline on iOS 26, and falls back to `SFSpeechRecognizer`.
- Native tool calling: `SessionOptions.tools` registers Dart `ModelTool`s on the native session; the model calls back into Dart over the method channel (`toolCall`), with per-tool timeouts enforced in Dart.
- Native guided structured generation: `generateStructured()` maps the Dart `StructuredSchema` to `DynamicGenerationSchema` and returns model-validated JSON in `structuredValue`.
- `prewarm()` and `cancelActiveRequest()` are real native calls; cancellation maps to the `cancelled` error code.
- `SessionOptions.useCase` selects the `contentTagging` on-device model variant.
- `countTokens()` on the facade for prompts and on local sessions for the current transcript.
- Typed iOS 27 `ModelUsage`, PCC quota state, and transcript error handling policy.
- `FoundationModelsOrchestrator` for Apple-first, external-first, local-only, and hybrid routing.
- `FoundationModelsChatSession` through `orchestrator.startChat()`: multi-turn hybrid chat with shared history across Apple and external routes, `send()`, `sendStream()`, `reset()`, and `dispose()`.
- External provider adapters through `FoundationModelsExternalProvider` (including `respondStream()` for streaming) and `FoundationModelsExternalTranscriptionProvider`.
- Dart DTOs for prompts, attachments, options, schemas, responses, stream events, tools, diagnostics, file selection, transcription, and typed errors.
- Native preflight availability checks before session creation.
- Native prompt construction from text, text files, and iOS 27 image attachments.
- iOS 27 `ContextOptions.reasoningLevel` mapping.
- iOS 27 typed response usage when Apple exposes it.
- Any feature that requires iOS 27 must be compiled with Xcode 27, either beta or official when available.
- Check runtime availability and locale support instead of assuming a specific device language.

Pending:

- Direct Photos picker.
- Dynamic Profiles and the iOS 27 `LanguageModel` protocol bridge.

## Important Files

- `lib/cupertino_fundations_models.dart`: public barrel.
- `lib/src/cupertino_foundation_models.dart`: public facade.
- `lib/src/availability.dart`: modes, cloud policies, capabilities, availability, quota, and diagnostics.
- `lib/src/file_selection.dart`: file picker DTOs.
- `lib/src/generation.dart`: prompt, attachments, generation options, responses, and stream events.
- `lib/src/orchestration.dart`: optional high-level router for local/PCC/external hybrid apps.
- `lib/src/session.dart`: session handle and lifecycle.
- `lib/src/transcription.dart`: audio transcription contracts.
- `lib/src/schema.dart`: runtime schema model for guided generation.
- `lib/src/tools.dart`: Dart tool contracts.
- `lib/src/errors.dart`: stable typed errors.
- `lib/src/platform/method_channel_cupertino_foundation_models.dart`: MethodChannel and EventChannel implementation.
- `ios/cupertino_fundations_models/Package.swift`: Swift Package Manager manifest; sources live under `ios/cupertino_fundations_models/Sources/cupertino_fundations_models/` and the podspec points at the same files.
- `.../Sources/cupertino_fundations_models/AvailabilityService.swift`: native capabilities and availability.
- `.../Sources/cupertino_fundations_models/CupertinoFoundationModelsPlugin.swift`: Flutter plugin registration, method routing, and per-session request/stream task tracking for cancellation.
- `.../Sources/cupertino_fundations_models/FileSelectionService.swift`: native `UIDocumentPickerViewController`.
- `.../Sources/cupertino_fundations_models/SessionRegistry.swift`: actor that owns native model sessions, tools, prewarm, and structured generation.
- `.../Sources/cupertino_fundations_models/SchemaMapper.swift`: Dart schema maps to `DynamicGenerationSchema`/`GenerationSchema`.
- `.../Sources/cupertino_fundations_models/ToolBridge.swift`: forwards native tool calls to Dart and returns the result to the model.
- `.../Sources/cupertino_fundations_models/SpeechTranscriptionService.swift`: `SpeechAnalyzer` file transcription with the iOS 27 asset provider and legacy/server fallback.
- `.../Sources/cupertino_fundations_models/LiveTranscriptionService.swift`: generation-token-guarded live microphone transcription with the iOS 27 capture provider, iOS 26 buffer conversion, and an `SFSpeechRecognizer` fallback.
- `.../Sources/cupertino_fundations_models/ErrorMapper.swift`: Swift error to `FlutterError` mapping, including `CancellationError` to `cancelled`.
- `example/lib/main.dart`: chat example with hybrid orchestration, streaming, live transcription, tool calling, and attachments.

## Conversation Context

The package supports conversation context when the caller reuses a `FoundationModelSession`.

Use this for multi-turn conversations:

```dart
final FoundationModelSession session = await models.createSession(
  options: const SessionOptions(
    mode: ModelMode.local,
    cloudPolicy: CloudPolicy.never,
    instructions: 'You are a concise assistant. Answer in English.',
  ),
);

try {
  await session.respond(const Prompt.text('My product is a finance app.'));
  final ModelResponse response = await session.respond(
    const Prompt.text('Suggest three onboarding messages based on that product.'),
  );
  print(response.text);
} finally {
  await session.dispose();
}
```

Do not use `models.respond()` when conversation memory is required. That convenience method creates a session, sends one request, and disposes it.

Context is not infinite. Apple documents context-window constraints, and the local model can throw context-size errors when instructions, prompts, prior outputs, tools, schemas, attachments, and generated content exceed the active limit.

## Model Modes

`ModelMode.local` uses the on-device model. Pair it with `CloudPolicy.never` for offline behavior.

`ModelMode.privateCloudCompute` explicitly asks for Apple's Private Cloud Compute path. It requires iOS 27+, Xcode 27 beta or official, an SDK that exposes `PrivateCloudComputeLanguageModel`, Apple availability, network, quota, and entitlement.

`ModelMode.automatic` uses the best path allowed by `CloudPolicy`. It must never send work to cloud when `CloudPolicy.never` is set.

## Cloud Policy

`CloudPolicy.never` forbids cloud use.

`CloudPolicy.whenExplicit` allows cloud only when the caller explicitly asks for a cloud-capable mode.

`CloudPolicy.automaticWithUserConsent` is reserved for apps that have their own durable user consent flow.

## Hybrid Orchestration

Use `FoundationModelsOrchestrator` when an app already has a larger AI layer and
wants this package to act as primary, secondary, or local cost-saving route.

```dart
final FoundationModelsOrchestrator ai = FoundationModelsOrchestrator(
  defaults: const FoundationModelsDefaults(
    localeIdentifier: 'es_CO',
    instructions: 'Respond in Spanish. Prefer Apple local routes when enough.',
  ),
  router: FoundationModelsRoutingPolicy.hybrid(
    allowPrivateCloud: true,
    allowExternalFallback: true,
  ),
  externalProvider: MyExternalProvider(),
);

final String context = await ai.buildRuntimePromptContext();
final OrchestratedModelResponse response = await ai.respondText(
  'Improve this user message.',
  task: FoundationModelsTask.rewrite,
);
```

Routing policy guidance:

- `localOnly()`: use for strict offline behavior.
- `appleFirst()`: use when Apple local/PCC should be primary and external models are fallback.
- `externalFirst()`: use when the app's existing cloud model remains primary and Apple models are fallback.
- `hybrid()`: use for cost optimization; simple tasks try Apple first, complex reasoning and tool routing try the external provider first.

`buildRuntimePromptContext()` returns a short prompt block that can be injected
into a larger model so it knows Apple local/PCC routes exist and when they are
available. Do not log that block together with user prompts unless the host app
has its own logging policy.

For multi-turn conversations across routes, use the hybrid chat session:

```dart
final FoundationModelsChatSession chat = ai.startChat(
  instructions: 'You are a concise assistant.',
);

final OrchestratedModelResponse first = await chat.send('Hello.');
await for (final OrchestratedChatEvent event in chat.sendStream('More.')) {
  // OrchestratedChatTextEvent carries cumulative snapshots;
  // OrchestratedChatCompletionEvent carries the final response.
}
await chat.dispose();
```

Apple turns reuse one persistent native session. External turns receive the
shared history through `FoundationModelsRequest.history`, so a stateless HTTP
provider rebuilds the same conversation. If routing falls back and returns to
Apple, the chat recreates the native session and replays the history in the
prompt.

## Availability Workflow

Always check availability before generation:

```dart
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

Use diagnostics when availability is blocked:

```dart
final FoundationModelsDiagnostics diagnostics = await models.getDiagnostics(
  localeIdentifier: 'en_US',
);

print(diagnostics.localAvailability.status.name);
print(diagnostics.localSupportedLanguages);
print(diagnostics.preferredLanguages);
```

Interpretation rules:

- `appleIntelligenceDisabled`: Apple Intelligence is not available to the app yet. Check device language, Siri language, supported region/language, settings, and asset downloads.
- `assetsUnavailable`: Apple Intelligence is enabled but model assets are not ready.
- `unsupportedLanguage`: switch to a supported Foundation Models locale.
- `unsupportedPlatform`: the device or selected backend is not eligible.
- `privateCloudUnavailable`: PCC is not available for this runtime, SDK, entitlement, quota, network, or account state.

## Prompt Attachments

Use `Prompt` with `PromptAttachment`:

```dart
final PickedFoundationModelsFile? file = await models.pickFile(
  kind: FoundationModelsFileKind.image,
);

if (file == null) {
  return;
}

final ModelResponse response = await models.respond(
  Prompt(
    text: 'Describe this image.',
    attachments: <PromptAttachment>[
      file.toPromptAttachment(label: file.name),
    ],
  ),
  mode: ModelMode.local,
  cloudPolicy: CloudPolicy.never,
);
```

Current native behavior:

- Text attachments are read as UTF-8 and inserted into the prompt.
- Image attachments use `Attachment<ImageAttachmentContent>` on iOS 27+.
- Audio must be transcribed first and then sent as text.

## Streaming

```dart
await for (final SessionEvent event in session.stream(
  const Prompt.text('Draft a short release note.'),
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
```

Treat `TextSnapshotEvent.text` as the latest cumulative native text snapshot.

## Audio

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
```

Use the transcript as a model prompt:

```dart
final ModelResponse response = await models.respond(
  Prompt.text(transcript.text),
  mode: ModelMode.local,
  cloudPolicy: CloudPolicy.never,
);
```

Live microphone transcription streams partial results and stops when the
subscription is cancelled:

```dart
final StreamSubscription<LiveTranscriptionEvent> dictation = models
    .liveTranscription(
      request: const LiveTranscriptionRequest(
        mode: AudioTranscriptionMode.automatic,
      ),
    )
    .listen((LiveTranscriptionEvent event) {
      // event.text is a cumulative snapshot; event.isFinal closes the stream.
    });
```

The host app must include `NSSpeechRecognitionUsageDescription`, and `NSMicrophoneUsageDescription` for live microphone transcription.

Treat generation sessions as single-flight resources. Dart rejects overlapping `respond`, `stream`, structured generation, prewarm, or transcript token-count calls with `concurrentRequests`. Generation and file-transcription timeouts are real caller-visible failures; never wrap these calls in an additional unbounded wait.

## SEO And Pub.dev Checklist

Public package discoverability depends on:

- English `description` in `pubspec.yaml`.
- `repository`, `issue_tracker`, `homepage`, and `documentation`.
- Up to five relevant `topics`.
- Platform declaration.
- Strong `README.md` with a short description, compatibility matrix, examples, and next steps.
- `CHANGELOG.md` with release notes.
- `example/README.md` for the pub.dev Example tab.
- `LICENSE`.
- `dart pub publish --dry-run` before publication.

## Validation

Do not create tests in this repository.

Run:

```bash
/Users/villa/Developer/tools/flutter/bin/flutter analyze
cd example && /Users/villa/Developer/tools/flutter/bin/flutter analyze
cd example && DEVELOPER_DIR=/Users/villa/Downloads/Xcode-beta.app/Contents/Developer /Users/villa/Developer/tools/flutter/bin/flutter build ios --no-codesign
```

Use Xcode 27 beta or the official Xcode 27 release for every iOS 27 feature. During the iOS 27 beta, validate Foundation Models on a device fully configured in English.

Before publishing, run:

```bash
/Users/villa/Developer/tools/flutter/bin/dart pub publish --dry-run
```

## Maintenance Rules

1. Read `context.md` before changing code.
2. Keep public docs in English.
3. Do not create tests.
4. Do not add runtime third-party dependencies without explicit approval.
5. Check availability before model invocation.
6. Keep offline as `ModelMode.local` plus `CloudPolicy.never`.
7. Never silently route to Private Cloud Compute.
8. Map native failures to `FoundationModelsException`.
9. Do not log prompts, attachments, transcripts, or model outputs by default.
10. Update `context.md` when behavior, architecture, or operational workflows change.

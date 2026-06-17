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

Audio transcription uses `Speech.framework`, not Foundation Models. `AudioTranscriptionMode.onDevice` forces `requiresOnDeviceRecognition = true`; `server` allows Apple Speech's remote path; `automatic` prefers on-device when the locale recognizer supports it. This is separate from Private Cloud Compute.

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
- `transcribeAudio()`
- Dart DTOs for prompts, attachments, options, schemas, responses, stream events, tools, diagnostics, file selection, transcription, and typed errors.
- Native preflight availability checks before session creation.
- Native prompt construction from text, text files, and iOS 27 image attachments.
- iOS 27 `ContextOptions.reasoningLevel` mapping.
- iOS 27 usage metadata when Apple exposes it.

Pending:

- Native tool calling execution bridge.
- Native guided structured generation.
- Direct Photos picker.
- Live microphone transcription.
- Dynamic Profiles.
- External model providers.

## Important Files

- `lib/cupertino_fundations_models.dart`: public barrel.
- `lib/src/cupertino_foundation_models.dart`: public facade.
- `lib/src/availability.dart`: modes, cloud policies, capabilities, availability, quota, and diagnostics.
- `lib/src/file_selection.dart`: file picker DTOs.
- `lib/src/generation.dart`: prompt, attachments, generation options, responses, and stream events.
- `lib/src/session.dart`: session handle and lifecycle.
- `lib/src/transcription.dart`: audio transcription contracts.
- `lib/src/schema.dart`: runtime schema model for guided generation.
- `lib/src/tools.dart`: Dart tool contracts.
- `lib/src/errors.dart`: stable typed errors.
- `lib/src/platform/method_channel_cupertino_foundation_models.dart`: MethodChannel and EventChannel implementation.
- `ios/Classes/AvailabilityService.swift`: native capabilities and availability.
- `ios/Classes/CupertinoFoundationModelsPlugin.swift`: Flutter plugin registration and method routing.
- `ios/Classes/FileSelectionService.swift`: native `UIDocumentPickerViewController`.
- `ios/Classes/SessionRegistry.swift`: actor that owns native model sessions.
- `ios/Classes/SpeechTranscriptionService.swift`: `SFSpeechURLRecognitionRequest` transcription.
- `ios/Classes/ErrorMapper.swift`: Swift error to `FlutterError` mapping.
- `example/lib/main.dart`: manual validation console.

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

`ModelMode.privateCloudCompute` explicitly asks for Apple's Private Cloud Compute path. It requires iOS 27+, an SDK that exposes `PrivateCloudComputeLanguageModel`, Apple availability, network, quota, and entitlement.

`ModelMode.automatic` uses the best path allowed by `CloudPolicy`. It must never send work to cloud when `CloudPolicy.never` is set.

## Cloud Policy

`CloudPolicy.never` forbids cloud use.

`CloudPolicy.whenExplicit` allows cloud only when the caller explicitly asks for a cloud-capable mode.

`CloudPolicy.automaticWithUserConsent` is reserved for apps that have their own durable user consent flow.

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
```

Treat `TextDeltaEvent.text` as the latest native text snapshot.

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

The host app must include `NSSpeechRecognitionUsageDescription`. Keep `NSMicrophoneUsageDescription` when adding live microphone capture.

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

# Cupertino Foundations Models

Apple Foundation Models for Flutter with on-device AI, streaming responses, multimodal prompts, speech transcription, runtime diagnostics, and an explicit path for Private Cloud Compute on iOS 27.

This package is designed as a native-first Flutter bridge. It uses Dart DTOs and Flutter platform channels on the public side, and Apple frameworks on the iOS side. It does not add runtime third-party dependencies.

## Status

This package is early, iOS-only, and targets real-device experimentation with Apple Intelligence and Foundation Models.

Implemented:

- Runtime capabilities and availability diagnostics.
- Local on-device text generation through `SystemLanguageModel`.
- `LanguageModelSession` handles for multi-turn conversation context.
- One-shot `respond()` convenience calls.
- Streaming responses.
- Text and image prompt attachments.
- Audio file transcription through `Speech.framework`.
- Explicit local, automatic, and Private Cloud Compute mode selection.
- Stable Dart error codes with recovery suggestions.
- iOS example app for manual validation.

In progress:

- Native tool calling bridge.
- Native guided structured generation.
- Direct Photos picker.
- Live microphone transcription.
- Dynamic Profiles.

## Platform Support

This Flutter plugin currently supports iOS only. The `platforms` field in `pubspec.yaml` is intentionally restricted to iOS so pub.dev does not advertise Android, Linux, macOS, Web, or Windows support.

| Capability | Apple API | Minimum OS | Notes |
| --- | --- | --- | --- |
| Local text generation | `SystemLanguageModel`, `LanguageModelSession` | iOS 26+ | Requires Apple Intelligence, supported language, and downloaded model assets. |
| Conversation context | `LanguageModelSession` transcript | iOS 26+ | Reuse the same `FoundationModelSession`; one-shot calls are stateless. |
| Streaming | `streamResponse` | iOS 26+ | Emits model text updates and completion events. |
| Context size diagnostics | `contextSize` | iOS 26+ | Local model context is limited; manage long conversations. |
| Image prompts | `Attachment<ImageAttachmentContent>` | iOS 27+ | Experimental in the iOS 27 SDK. |
| Reasoning options | `ContextOptions.ReasoningLevel` | iOS 27+ | Mapped from Dart `ReasoningLevel`. |
| Private Cloud Compute | `PrivateCloudComputeLanguageModel` | iOS 27+ | Requires Apple availability, network, quota, and entitlement. |
| Audio transcription | `SFSpeechURLRecognitionRequest` | iOS 13+ | Uses Speech, not Foundation Models. On-device mode requires locale support. |

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
  cupertino_fundations_models: ^0.0.2
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

For iOS 27 beta development, build with the iOS 27 SDK:

```bash
DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer flutter build ios
```

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

The example can inspect capabilities, diagnostics, availability, local generation, automatic mode, PCC checks, streaming, file attachments, and audio transcription.

Full advanced example source:

- [`example/lib/main.dart`](example/lib/main.dart)
- [`example/README.md`](example/README.md)

The example is intentionally larger than a minimal snippet because it exercises the most important runtime paths from a real iPhone: local generation, Private Cloud Compute checks, stream rendering, file attachments, and audio transcription.

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

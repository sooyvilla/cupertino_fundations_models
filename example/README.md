# Cupertino Foundations Models Example

Chat app that shows Apple Foundation Models from Flutter on a real Apple device: on-device AI generation with streaming, multi-turn conversation context, live microphone transcription, image attachments, and hybrid routing to an external provider.

The app demonstrates:

- Hybrid chat through `FoundationModelsOrchestrator.startChat()` with streaming message bubbles.
- Conversation context that survives fallback between Apple local, Private Cloud Compute, and an optional Gemini provider.
- Live microphone transcription with `CupertinoFoundationModels.liveTranscription()` feeding the chat input while you speak.
- Image attachments through the native document picker.
- Availability checks and runtime diagnostics.

## Full Source

The full example lives in [`lib/main.dart`](lib/main.dart). The code shows how to wire:

- `FoundationModelsOrchestrator` with `FoundationModelsRoutingPolicy.hybrid()`
- `FoundationModelsChatSession.sendStream()` with `OrchestratedChatTextEvent` and `OrchestratedChatCompletionEvent`
- A custom `FoundationModelsExternalProvider` (Gemini REST adapter, no third-party packages)
- `CupertinoFoundationModels.liveTranscription()`
- `CupertinoFoundationModels.pickFile()` and prompt attachments
- `CupertinoFoundationModels.checkAvailability()` and `getDiagnostics()`

## Run

```bash
cd example
flutter pub get
flutter run -d <ios-device-id>
```

To demo hybrid routing with a Gemini fallback, pass an API key:

```bash
flutter run -d <ios-device-id> --dart-define=GEMINI_API_KEY=your_key
```

Use a physical iOS 27 device for the strongest Foundation Models path. Features that require iOS 27 must be compiled with Xcode 27, either the beta or the official release if it is already available. Private Cloud Compute requires Apple's managed entitlement.

For Xcode beta builds:

```bash
DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer flutter run -d <ios-device-id>
```

Apple Intelligence must be enabled, the device language and Siri language must be supported, and model assets must finish downloading before local generation is available.

When testing on the iOS 27 beta, Foundation Models currently work only when the device is fully configured in English, including system language and Siri language.

Live transcription and speech features require the microphone and speech recognition permissions already declared in this example's `Info.plist`.

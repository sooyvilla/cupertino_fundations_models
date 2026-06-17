# Cupertino Foundations Models Example

Manual Flutter app for validating Apple Foundation Models from Flutter on a real Apple device.

The app can validate:

- Capabilities and diagnostics.
- Local on-device availability.
- Private Cloud Compute availability.
- One-shot responses.
- Streaming responses.
- Multi-turn session behavior through reusable sessions.
- Text and image file attachments.
- Audio file transcription with Speech.
- Full log copying for debugging.

## Full Source

The full advanced example lives in [`lib/main.dart`](lib/main.dart).

It is intentionally a complete manual console instead of a tiny snippet. The code shows how to wire:

- `CupertinoFoundationModels.getCapabilities()`
- `CupertinoFoundationModels.getDiagnostics()`
- `CupertinoFoundationModels.checkAvailability()`
- `CupertinoFoundationModels.createSession()`
- `FoundationModelSession.respond()`
- `FoundationModelSession.stream()`
- `CupertinoFoundationModels.pickFile()`
- `CupertinoFoundationModels.transcribeAudio()`
- Local mode, automatic mode, and Private Cloud Compute checks
- Prompt instructions, attachments, max tokens, sampling, temperature, reasoning level, and tool-calling policy

## Run

```bash
cd example
flutter pub get
flutter run -d <ios-device-id>
```

Use a physical iOS 27 device for the strongest Foundation Models path. Private Cloud Compute requires Apple's managed entitlement.

For Xcode beta builds:

```bash
DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer flutter run -d <ios-device-id>
```

Apple Intelligence must be enabled, the device language and Siri language must be supported, and model assets must finish downloading before local generation is available.

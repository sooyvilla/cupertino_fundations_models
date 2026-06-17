## 0.0.2

- Marked the package as iOS-only in `pubspec.yaml`.
- Added pub.dev metadata for repository, issues, documentation, topics, and platform support.
- Expanded the README with iOS-only support, conversation context, advanced example links, source code links, and the agent skill guide.
- Expanded the example README so pub.dev can display a useful Example tab while still linking to `example/lib/main.dart`.
- Removed generated test scaffolding to comply with the repository rule of not creating tests.

## 0.0.1

- Initial release of Cupertino Foundations Models.
- Added the Dart API surface for capabilities, diagnostics, availability, sessions, generation, streaming, schemas, tools, file selection, audio transcription, and typed errors.
- Added the iOS plugin shell with MethodChannel, EventChannel, session registry, availability service, document picker, Speech transcription service, and Foundation Models text generation hooks.
- Added local conversation context through reusable `FoundationModelSession` handles.
- Added iOS 27 hooks for image attachments, reasoning options, usage metadata, and Private Cloud Compute availability.

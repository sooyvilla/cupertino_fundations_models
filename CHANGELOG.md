## 0.1.1

### Added

- `FoundationModelsRoutingPolicy.privateCloudFirst()`: prefers Apple Private Cloud Compute (iOS 27+) with optional fallback to the Apple local model and to the external provider.

### Changed

- Live transcription locale matching: regional locales such as `es_CO` or `en_AU` now match any supported variant of the same language, so they keep the modern `SpeechAnalyzer` engine instead of silently falling back to the legacy `SFSpeechRecognizer` engine. Only truly unsupported languages fall back.
- Example app: added a backend selector in the AppBar (Auto hybrid / Apple on-device / Private Cloud Compute / Gemini), rewrote the session instructions to allow complete same-language answers, raised the token limit, and used the device locale for orchestration and live transcription defaults with an on-screen caption showing the active speech engine.

### Fixed

- Streaming generation no longer hangs after the first completion. The native event channel never emitted end-of-stream, so `FoundationModelsChatSession.sendStream()` awaited forever and chat UIs stayed locked in a sending state. The native side now closes the event channel after completion and error events, and the Dart stream also closes defensively when a completion or failure event arrives.
- The iOS plugin now compiles with both Xcode 26 and Xcode 27 beta. The Swift 6.4 compiler (iOS 27 SDK) renamed the `GenerationOptions` initializer label from `sampling:` to `samplingMode:`, and the plugin previously used a single label unconditionally, so the build failed on the toolchain that did not match it. The initializer call is now selected with `#if compiler(>=6.4)`: Xcode 27 builds use `samplingMode:` (plus `toolCallingMode:` when running on iOS 27), and older toolchains keep the iOS 26 SDK label `sampling:`. No Dart API changes; generation options (sampling mode, temperature, and maximum response tokens) behave the same on every supported toolchain.

## 0.1.0

Hybrid orchestration and live speech release. All changes are additive; no existing public API changed.

### Added

- `FoundationModelsOrchestrator` for local-only, Apple-first, external-first, and hybrid routing between Apple Foundation Models and an app-provided external provider such as Gemini, ChatGPT, or a custom backend.
- `FoundationModelsChatSession` through `orchestrator.startChat()`: a multi-turn hybrid chat that reuses one persistent native Apple session and replays the shared history to external providers through `FoundationModelsRequest.history`, so the conversation survives fallback between local and remote routes.
- `FoundationModelsChatSession.sendStream()` with `OrchestratedChatTextEvent` and `OrchestratedChatCompletionEvent` for streaming chat UIs.
- `FoundationModelsChatMessage` and `FoundationModelsChatRole` to model conversation turns shared across providers.
- `FoundationModelsExternalProvider.respondStream()` so external adapters can stream cumulative text snapshots; the default implementation emits one snapshot from `respond()`.
- Live microphone transcription: `CupertinoFoundationModels.liveTranscription()` returns a `Stream<LiveTranscriptionEvent>` of partial and final speech-to-text snapshots, backed by a new native `LiveTranscriptionService` (`AVAudioEngine` + Apple Speech) and a dedicated event channel. Cancelling the subscription stops the microphone.
- `LiveTranscriptionRequest` and `LiveTranscriptionEvent` types.
- Optional external provider adapter contracts for text generation and audio transcription.
- Runtime context generation (`buildRuntimePromptContext()`) so a larger app orchestrator can know when Apple local and Private Cloud Compute routes are available.
- API documentation across the public surface.
- Swift Package Manager support for the iOS plugin (hybrid layout: SPM and CocoaPods both supported), including a `PrivacyInfo.xcprivacy` privacy manifest.
- Native tool calling: tools declared with `ModelTool` are now registered on the native `LanguageModelSession`; the on-device or PCC model calls back into Dart through the method channel, with per-tool timeouts enforced in Dart.
- Native guided structured generation: `generateStructured()` now builds a real `DynamicGenerationSchema`/`GenerationSchema` from the Dart `StructuredSchema` and returns the model-validated JSON in `structuredValue` (previously the schema was ignored).
- `SessionOptions.useCase` with `FoundationModelsUseCase.contentTagging` to use Apple's specialized content-tagging on-device model.
- `FoundationModelSession.prewarm()` now calls the native `prewarm(promptPrefix:)` to preload model resources for lower first-token latency.
- `FoundationModelSession.cancelActiveRequest()` now cancels the in-flight native respond, structured, or streaming request; cancellations map to the `cancelled` error code.
- Live microphone transcription now prefers the modern `SpeechAnalyzer`/`SpeechTranscriber` pipeline on iOS 26+, with on-device asset management and automatic fallback to `SFSpeechRecognizer` on older systems, unsupported locales, or explicit server mode. Event metadata reports which engine was used.

### Changed

- Example app rewritten as a chat: streaming message bubbles, conversation context, live microphone transcription into the input field, image attachments, a demo `get_current_time` tool, and an optional Gemini fallback enabled with `--dart-define=GEMINI_API_KEY=your_key`.
- pub.dev metadata: tuned package description and topics for discoverability.

### Fixed

- Concurrent generation streams no longer cancel each other: native stream tasks are now tracked per session instead of a single shared task.

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

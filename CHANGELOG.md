## 0.4.0

### Breaking

- `ModelUsage` counters are nullable. Missing native values no longer decode as
  zero. See [migration](doc/migration-0.4.0.md).
- The internal platform interface adds `measureTokenBudget`; custom transports
  must implement it. Stream closure without a terminal result now fails, and
  subscription cancellation errors are propagated instead of swallowed.

### Added

- Session token budgets with per-component counts and precision for prompt,
  instructions, tools, schema and transcript using the actual local model.
  PCC/unsupported counts remain explicitly unavailable; no exact total is
  fabricated from overlapping components.
- Typed response/error termination, structure completeness and timeout phase.
  Successful completion retains an unknown stop reason when Apple supplies none.
- First-response, idle and total stream deadlines with awaited native cleanup.
- Opt-in diagnostic callbacks with request/model/runtime metadata, timing,
  usage, typed outcome and separately enabled bounded exact-output capture.
- A complete structured-document extraction example with Spanish numeric text,
  updated developer/agent references, migration and physical integration guide.

### Fixed

- Dynamic schema type names are unique by path; mapper errors identify the
  failing property through `schemaPath`.
- Terminal stream delivery removes its native transport registration before
  invoking consumers, and incomplete closes do not look like success.

### Validation scope

- Source/SDK review only. No tests, analysis, formatting, builds or physical
  device/PCC validation were executed for this release. Existing fake transport
  and expectation adapted to the internal interface and terminal event contract.

## 0.3.1

### Added

- `FoundationModelSession.streamStructured()` for schema-guided JSON streaming.
  Snapshots carry cumulative JSON text; the completed response carries the
  complete JSON string and strictly decoded `structuredValue`.
- Optional `schema` on `session.stream()` for the same guided generation path.
- [PCC setup guide](doc/private-cloud-compute.md) covering current eligibility,
  Apple's entitlement request, signing, provisioning, host opt-in and runtime
  limits, linked from developer and agent documentation.

### Changed

- Structured streams reject malformed schemas, incomplete final snapshots and
  final JSON decoding failures instead of falling back to free-form text.

### Validation scope

- API signatures checked against the installed Xcode 27.2 SDK; source reviewed.
- No new tests, Dart analysis, builds or device/PCC runtime validation.

## 0.3.0

Native Apple sessions, stricter privacy and input validation, and lifecycle hardening.
This is a breaking update from 0.2.x.

### Breaking

- Remove the Dart hybrid orchestrator, external-provider contracts, shared
  cross-provider chat history and routing policies. Applications own API/local
  routing and consent; this package owns Apple native sessions.
- `GenerationOptions.cloudPolicy` is nullable and inherits the session when
  omitted. Explicit `never` refuses requests on an existing PCC session.
- Reject contradictory cloud policies, unsupported schema constraints, invalid
  tool arguments and generation options instead of silently changing behavior.
- Require Flutter 3.41 or later, consistent with the existing Dart 3.11 minimum.

See [migration](doc/migration-0.3.0.md) and [application routing](doc/app-owned-routing.md).

### Added

- `SessionOptions.localeIdentifier` to validate the requested local model locale.
- `GenerationOptions.maximumToolCalls`, a per-request limit of 1–128 (default 16).
- Missing Speech/microphone usage descriptions produce a typed configuration
  error before requesting protected platform APIs.
- Feature guide, recovered crash ledger, recovery recipes, an updated agent
  implementation guide and the [iOS 27.2 audit](doc/ios-27.2-audit-2026-09-19.md).

### Changed

- Example uses persistent Apple sessions, defaults to local generation and
  on-device Speech, and removes the Gemini client/API key path.
- Request-scoped streaming callbacks allow different sessions to coexist;
  default facade instances share a single native callback transport.
- Cancellation and disposal wait for native work to finish before reuse.
- Tools have native and Dart timeout handling, a request budget, and a 64,000
  character result ceiling that returns a size error instead of truncating data.
- Attachments are bounded before decoding; images are downsampled to 2,048
  pixels and processed with Vision OCR, classification and barcode detection.
- Private Cloud Compute initialization requires an explicit host opt-in flag;
  this flag does not grant or verify Apple's managed entitlement.

### Fixed

- Native tool bridge installation and stale task completion races.
- Conflicting generation, prewarm, cancellation and session disposal operations.
- Live microphone startup/cancellation overlap and analyzer cleanup ordering.
- Speech callback values crossing Swift concurrency boundaries unsafely.
- Invalid sampling, response limits, timeouts, schemas and tool arguments reaching
  Apple APIs; unavailable local models now return typed availability reasons.
- Swallowed structured JSON parse failures and silent attachment extraction errors.
- Empty `Unreleased` heading and outdated hybrid claims in package metadata/docs.

### Validation

- Dart analysis, documentation snippets and unsigned SPM/CocoaPods builds passed
  with Xcode 27.2 beta.
- Current iOS 27.2 device behavior and entitled PCC generation remain unverified;
  historical device checks are documented separately.

## 0.2.1

iOS 27 beta 5 crash hardening for diagnostics, image and file prompts, hybrid routing, generation concurrency, and Speech transcription. This release also adds runtime language selection shared by Foundation Models and live transcription.

### Changed

- The example now offers a searchable language selector. One selected locale controls Foundation Models instructions, Hybrid/external-provider defaults, availability diagnostics, and live `SpeechTranscriber` requests; changing it stops dictation and starts a clean conversation.
- Image and file selection in the example now accepts any document instead of images only. UTF-8 text, Markdown, JSON, CSV, and text-based PDF files are converted into prompt context; unsupported, corrupt, inaccessible, or oversized files return a typed error.
- Image input on iOS 27 beta 5 uses local Vision OCR, classification, and barcode preprocessing before generation. Native `Attachment<ImageAttachmentContent>` remains disabled because the beta 5 runtime terminates the process before Swift can throw an error.

### Added

- `CupertinoFoundationModels.getSupportedLanguages()` and `FoundationModelsLanguage`, exposing locales accepted by both `SystemLanguageModel.supportsLocale(_:)` and `SpeechTranscriber.supportedLocales`, plus whether each transcription asset is installed.

### Fixed

- Foundation Models diagnostics no longer read unsafe PCC language and capability properties that caused repeatable `EXC_BAD_ACCESS` crashes on iOS 27 beta 5.
- Image paths no longer call the crashing `Attachment(imageURL:)` or `Attachment.label(_:)` APIs. Image bytes and files are decoded, validated, downsampled, and handled without an unrecoverable native crash.
- File picker results preserve the original display name instead of exposing the UUID used by the temporary copy. Deterministic attachment errors also survive Hybrid route exhaustion instead of being replaced with `modelUnavailable`.

## 0.2.0

iOS 27 beta 5 API alignment. This is a breaking release from `0.1.x`.

### Breaking

- Replaced `ToolCallingPolicy.automatic` with Apple's iOS 27 terminology: `ToolCallingMode.allowed`. The request field is now `GenerationOptions.toolCallingMode`.
- Renamed reasoning values from `low`, `medium`, and `high` to Apple's `light`, `moderate`, and `deep` values.
- Renamed `TextDeltaEvent` to `TextSnapshotEvent` because Apple streaming content is a cumulative snapshot, not an incremental delta.
- Changed `ModelResponse.structuredValue` and orchestrated structured values from `Map<String, Object?>?` to `Object?`, preserving valid root arrays and scalar guided-generation results.
- Replaced `FoundationModelsErrorCode.contextExceeded` with `contextSizeExceeded` and added the distinct error cases introduced by iOS 27.
- Replaced `PrivateCloudQuota.status` strings and `limitIncreaseSuggestion` with `PrivateCloudQuotaStatus`, `isApproachingLimit`, and `canRequestLimitIncrease`.
- Removed `ModelCapability.externalProvider`; app-provided Dart adapters remain supported by `FoundationModelsOrchestrator`, but they are not a native Apple runtime capability.

### Added

- `CupertinoFoundationModels.countTokens()` for prompt token counts and `FoundationModelSession.countTokens()` for local transcript counts on iOS 26.4 or later.
- `ModelUsage` on completed responses with input, cached-input, output, reasoning, and total token counts from iOS 27.
- Configurable top-K, probability threshold, and random seed values for native sampling.
- `ReasoningLevel.custom()` for custom iOS 27 reasoning-level identifiers.
- `TranscriptErrorHandlingPolicy` in `SessionOptions` for iOS 27 transcript rollback or preservation behavior.
- Typed mappings for `LanguageModelError`, `SystemLanguageModel.Error`, `LanguageModelSession.Error`, `PrivateCloudComputeLanguageModel.Error`, and `GeneratedContent.ParsingError`.
- Image prompt attachments supplied as Dart bytes, decoded natively before creating the Apple attachment.

### Changed

- iOS 27 structured generation uses the new `respond(to:schema:options:contextOptions:)` overload instead of the deprecated `includeSchemaInPrompt` overload.
- Capability reporting now advertises token counting from iOS 26.4 and uses iOS 27 `LanguageModelCapabilities` for vision and reasoning instead of assuming them from the OS version.
- PCC quota diagnostics now expose beta 5 status, approaching-limit state, reset date, and whether Apple offers a limit-increase action.
- Streaming completion events now carry the final iOS 27 token usage.
- Audio-file transcription now uses `SpeechAnalyzer` on iOS 26+ and the new iOS 27 `AssetInputSequenceProvider`; explicit server mode and older systems retain the `SFSpeechRecognizer` path.
- Live transcription on iOS 27 uses the beta 5 `CaptureInputSequenceProvider`, avoiding manual microphone format conversion on the newest runtime.

### Fixed

- iOS 27 beta 5 compatibility is verified against Xcode 27 build `27A5194q`.
- Guided generation no longer drops valid non-object root values.
- The public streaming event name now matches its cumulative-snapshot semantics.
- Generation sessions and high-level chat sessions reject overlapping requests before they reach Apple's single-request native session.
- `GenerationOptions.timeout` now cancels stalled one-shot and streaming requests; `AudioTranscriptionRequest.timeout` cancels the native Speech task and reports `transcriptionTimeout`.
- Live microphone startup is invalidated when its Dart subscription is cancelled, and the iOS 26 fallback validates sample rate and channel count before installing an `AVAudioEngine` tap, preventing AVFoundation assertion crashes on invalid microphone formats.
- The example marks a send as active before waiting for microphone shutdown and renders unexpected failures instead of letting them escape as unhandled asynchronous errors.

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

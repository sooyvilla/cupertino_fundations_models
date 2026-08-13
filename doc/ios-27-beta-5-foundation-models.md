# iOS 27 beta 5 and Foundation Models

Research date: 2026-08-12
Validated SDK: Xcode 27 beta 5, build `27A5194q`

## Executive finding

Apple's iOS and iPadOS 27 beta 5 release notes do not introduce a new Foundation Models API family. They resolve six framework defects carried by earlier iOS 27 betas:

1. Private Cloud Compute might fail in Simulator.
2. Combining tool calling and guided generation could trigger excessive tool calls.
3. `@Generable` enums could emit an unsilenceable `GenerationError` deprecation warning.
4. Truncating transcript history in `onPrompt` could cause a runtime error.
5. `onPrompt` could be skipped for a profile without instructions.
6. `PrivateCloudComputeLanguageModel` could always use greedy decoding.

Apple lists the six bullets above under Foundation Models resolved issues in the current beta 5 notes. The feature additions belong to the wider iOS 27 SDK cycle, not specifically to beta 5. The package therefore needs both kinds of work: remove workarounds or warnings that beta 5 supersedes, and adopt the new iOS 27 contracts that remain current.

Official sources:

- [iOS and iPadOS 27 beta 5 release notes](https://developer.apple.com/documentation/ios-ipados-release-notes/ios-ipados-27-release-notes)
- [Xcode 27 beta 5 release notes](https://developer.apple.com/documentation/xcode-release-notes/xcode-27-release-notes)
- [Foundation Models updates](https://developer.apple.com/documentation/updates/foundationmodels)
- [Foundation Models framework](https://developer.apple.com/documentation/foundationmodels)

## Speech follow-up from the crash investigation

Speech transcription is a separate Apple framework from Foundation Models, but it is part of the example's Apple Intelligence experience. The iOS 27 beta 5 SDK adds `AssetInputSequenceProvider`, `CaptureInputSequenceProvider`, and `AnalyzerInputConverter` to the modern `SpeechAnalyzer` pipeline. Apple documents these helpers as the preferred way to read files or capture devices while producing analyzer-compatible asynchronous audio input.

The package now uses `AssetInputSequenceProvider` for on-device file transcription and `CaptureInputSequenceProvider` for live microphone capture on iOS 27. iOS 26 keeps a guarded buffer-conversion path, and older systems or explicit server requests keep the legacy recognizer. The live fallback validates sample rate and channel count before installing an audio tap because AVFoundation can terminate the process for an invalid format instead of returning a recoverable Swift error.

Official Speech sources:

- [Speech framework](https://developer.apple.com/documentation/speech)
- [SpeechAnalyzer](https://developer.apple.com/documentation/speech/speechanalyzer)
- [AssetInputSequenceProvider](https://developer.apple.com/documentation/speech/assetinputsequenceprovider)
- [CaptureInputSequenceProvider](https://developer.apple.com/documentation/speech/captureinputsequenceprovider)
- [WWDC25: Bring advanced speech-to-text to your app with SpeechAnalyzer](https://developer.apple.com/videos/play/wwdc2025/277/)

## Current iOS 27 API surface

### Errors

`LanguageModelSession.GenerationError` is deprecated when building with Xcode 27. Apple now separates failures by owner:

- `LanguageModelError`: context size, rate limiting, guardrails, refusal, unsupported capability or transcript content, unsupported guide or language, and timeout.
- `SystemLanguageModel.Error`: on-device model asset failures.
- `LanguageModelSession.Error`: concurrent requests and transcript mutation while responding.
- `PrivateCloudComputeLanguageModel.Error`: network, quota, and service failures.
- `GeneratedContent.ParsingError`: structured content parsing failures.

Apple explicitly says apps must rebuild with Xcode 27 to catch these new types. Version `0.2.0` maps them to distinct stable Dart error codes rather than parsing localized strings.

Source: [deprecated GenerationError documentation](https://developer.apple.com/documentation/foundationmodels/languagemodelsession/generationerror)

### Model and request options

- `GenerationOptions.SamplingMode` supports greedy, top-K, and probability-threshold sampling; random modes accept an optional seed in the beta 5 SDK.
- `GenerationOptions.ToolCallingMode` uses `allowed`, `required`, and `disallowed`.
- `ContextOptions.ReasoningLevel` uses `light`, `moderate`, `deep`, or a custom string.
- The iOS 27 response overloads accept `ContextOptions` and request metadata directly.
- `LanguageModelSession.Response` and streaming snapshots expose typed token usage.
- `LanguageModelSession.transcriptErrorHandlingPolicy` can revert or preserve transcript mutations after failures.

### Models and orchestration

- `PrivateCloudComputeLanguageModel` provides availability, supported languages, model capabilities, quota state, errors, and an asynchronous context size.
- `LanguageModel` and `LanguageModelExecutor` let a Swift package plug another on-device or server model into the Foundation Models session surface.
- Dynamic Profiles can switch models, instructions, tools, sampling, reasoning, and history transformations before each prompt.
- In the beta 5 SDK, the current Dynamic Profile names are `historyTransform(_:)` and `toolCallingMode(_:)`; `inputFilter(_:)` and `toolCalling(_:)` are deprecated.

Sources:

- [LanguageModel protocol](https://developer.apple.com/documentation/foundationmodels/languagemodel)
- [DynamicProfile documentation](https://developer.apple.com/documentation/foundationmodels/languagemodelsession/dynamicprofile)
- [Private Cloud Compute integration](https://developer.apple.com/documentation/foundationmodels/adding-server-side-intelligence-with-private-cloud-compute)

### Multimodal and context management

- Image prompt attachments use `Attachment<ImageAttachmentContent>`.
- Apple documents Vision's OCR and barcode-reader tools for image-analysis workflows.
- The on-device context remains 4,096 tokens. `SystemLanguageModel.tokenCount(for:)` is available from iOS 26.4 for prompts, instructions, tools, schemas, and transcript entries.
- iOS 27 responses expose input, cached-input, output, reasoning, and total token usage.

Sources:

- [Analyzing images with multimodal prompting](https://developer.apple.com/documentation/foundationmodels/analyzing-images-with-multimodal-prompting)
- [Managing the context window](https://developer.apple.com/documentation/foundationmodels/managing-the-context-window)

## Package decisions for 0.2.0

- Keep iOS 15 as the plugin deployment target and guard Foundation Models at runtime: core local generation remains iOS 26+, token counting is iOS 26.4+, and new model protocols/PCC/reasoning/images remain iOS 27+.
- Require an Xcode 27 build to expose the complete `0.2.0` feature set and typed iOS 27 errors.
- Keep privacy local by default. PCC remains explicit through `ModelMode` and `CloudPolicy`.
- Keep the app-provided Dart provider adapter in `FoundationModelsOrchestrator`, but do not advertise it as Apple's native `LanguageModel` protocol. Bridging an arbitrary native Swift executor is a separate integration problem.
- Keep Dynamic Profiles on the roadmap. A real bridge must preserve their per-prompt state, lifecycle callbacks, transcript transforms, and typed Swift builder semantics; a static map called "profile" would not be feature parity.

## Migration from 0.1.x

| 0.1.x | 0.2.0 |
| --- | --- |
| `ToolCallingPolicy.automatic` | `ToolCallingMode.allowed` |
| `GenerationOptions.toolCallingPolicy` | `GenerationOptions.toolCallingMode` |
| `ReasoningLevel.low` | `ReasoningLevel.light` |
| `ReasoningLevel.medium` | `ReasoningLevel.moderate` |
| `ReasoningLevel.high` | `ReasoningLevel.deep` |
| `TextDeltaEvent` | `TextSnapshotEvent` |
| `FoundationModelsErrorCode.contextExceeded` | `FoundationModelsErrorCode.contextSizeExceeded` |
| `Map<String, Object?>? structuredValue` | `Object? structuredValue` |
| Token counts hidden in metadata or unavailable | `ModelUsage`, `models.countTokens()`, `session.countTokens()` |
| String PCC quota status | `PrivateCloudQuotaStatus` and typed quota flags |

No tests or simulators were run for this iteration. The allowed validation was Dart formatting, static analysis, a non-interactive iOS release build without code signing against Xcode 27 beta 5, and a package publication dry run.

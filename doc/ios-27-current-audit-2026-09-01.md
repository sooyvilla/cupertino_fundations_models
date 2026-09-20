> Historical September 1 snapshot. For current contracts and validation boundaries, see the [September 19 iOS 27.2 audit](ios-27.2-audit-2026-09-19.md).

# iOS 27 current API and crash-safety audit

Research date: 2026-09-01

Installed validation toolchain: Xcode 27 beta 6, build `27A5252f`; iOS 27 SDK build `24A5422a`; Swift 6.4

Current Apple publications observed: iOS/iPadOS 27 beta 8, build `24A5430a`; Xcode 27 beta 6, build `27A5252f`

Additional isolated validation toolchain: Flutter 3.47.2; Dart 3.13.2

## Result

The package source is aligned with the iOS 27 contracts present in the installed Swift interfaces and is hardened around the crash and hang classes found in the previous beta-5 investigation. Static analysis, the Dart test suite, Swift 6 complete concurrency checking, native analysis, release iOS application builds through Swift Package Manager, and a CocoaPods framework build all pass. The same Dart and release-build gates also pass under Flutter 3.47.2 without modifying the user's shared Flutter SDK.

A signed release smoke matrix passed on an iPhone 17 Pro Max running iOS 27 beta 8. It covered local availability and languages, prompt and transcript token counting, response usage, structured generation, real tool invocation, completed streaming, cancellation followed by session reuse, two simultaneous request-scoped streams, content tagging, Vision-backed image input, `SpeechAnalyzer` file transcription, and clean live-transcription start/cancel. No newer Runner crash report appeared during or after the final matrix. This validates the package's supported local surface on that device and build; it is not a universal guarantee against future Apple beta regressions.

## Official sources reviewed

- [Foundation Models updates](https://developer.apple.com/documentation/updates/foundationmodels)
- [Foundation Models framework](https://developer.apple.com/documentation/foundationmodels)
- [iOS and iPadOS 27 release notes](https://developer.apple.com/documentation/ios-ipados-release-notes/ios-ipados-27-release-notes)
- [Xcode 27 release notes](https://developer.apple.com/documentation/xcode-release-notes/xcode-27-release-notes)
- [Apple developer releases](https://developer.apple.com/news/releases/?id=09012026a)
- [Flutter release notes](https://docs.flutter.dev/release/release-notes)
- [Generation temperature](https://developer.apple.com/documentation/foundationmodels/generationoptions/temperature)
- [Concurrent request error](https://developer.apple.com/documentation/foundationmodels/languagemodelsession/error/concurrentrequests)
- [Tool calling](https://developer.apple.com/documentation/foundationmodels/expanding-generation-with-tool-calling)
- [SpeechAnalyzer](https://developer.apple.com/documentation/speech/speechanalyzer)
- [CaptureInputSequenceProvider](https://developer.apple.com/documentation/speech/captureinputsequenceprovider)

Apple's Foundation Models update page now calls out the 2026 model/API additions and recommends retesting prompts after the iOS 27 model update. The current release notes do not state that the beta-5 image-attachment or PCC getter ABI failures reproduced in this repository have been fixed. Absence from release notes is not proof of safety.

## Installed SDK contracts confirmed

The installed Xcode 27 beta-6 `.swiftinterface` files confirm:

- `LanguageModelSession` accepts only one active generation request. Overlapping work is represented by `LanguageModelSession.Error.concurrentRequests`.
- iOS 27 generation options include sampling mode, temperature, maximum response tokens, and tool-calling mode. Temperatures must remain between zero and one and response-token limits must be positive.
- `ToolCallingMode.required` needs an application-defined exit condition; otherwise the model may continue invoking tools.
- iOS 27 responses and stream snapshots expose typed token usage and accept `ContextOptions`.
- `SpeechAnalyzer` is actor-based and provides explicit preparation, finish, and cancellation APIs.
- `CaptureInputSequenceProvider` owns an `AVCaptureSession`; starting and stopping that session must not race.
- Private Cloud Compute availability currently exposes the typed unavailable reasons `deviceNotEligible` and `systemNotReady` in the installed SDK.
- Dynamic Profiles exist in the SDK, but the package does not yet expose their lifecycle or transcript-transform semantics.

## Changes made from the audit

### Generation and streams

- Replaced the shared generation EventChannel listener with MethodChannel callbacks keyed by `requestId`. This permits simultaneous streams on separate sessions without replacing the listener or cross-delivering events.
- Added tokenized request tracking so completion of an old cancelled task cannot remove a newer task entry.
- Cancellation and session disposal now cancel and await native request tasks before returning.
- Sessions remain reserved while cancellation is in progress, and terminal callbacks clear their native tracking before Dart receives completion or failure.
- `SessionRegistry` receives its `ToolBridge` in its initializer, so the first tool-enabled session can no longer race asynchronous bridge configuration.
- Added native validation for sampling bounds, finite temperature, positive response-token limits, tool timeouts, unique tool names, and the tool-call budget.
- Main-thread Flutter entry points are explicitly `@MainActor`. Immutable codec payloads cross actor boundaries through `FlutterChannelValue`, while Speech callbacks snapshot sendable values before resuming continuations. Both native integration paths compile with `SWIFT_STRICT_CONCURRENCY=complete` and `SWIFT_TREAT_WARNINGS_AS_ERRORS=YES`.

### Tool calling

- Added `GenerationOptions.maximumToolCalls`, defaulting to 16 with an accepted range of 1–128.
- Added a native per-request tool budget to guarantee an exit for required tool calling.
- Added a Swift-side tool timeout and cancellation-safe continuation. A missing Dart callback can no longer leave the native model waiting forever.
- Limited tool output returned to the model to 64,000 characters to protect the context window.

### Speech and capture

- `SpeechAnalyzer.prepareToAnalyze(in:)` now runs before file and live analysis.
- Live analyzer/capture cleanup is retained and chained, so every new subscription awaits cleanup even when the previous stream ended through EventChannel cancellation.
- `AVCaptureSession.startRunning()` and `stopRunning()` run on one serial queue.
- Existing input-format validation and subscription tokens remain in place for the iOS 26 buffer path and late asynchronous startup.

### Attachments and availability

- File sizes are checked before reading or decoding. Text is limited to 5 MB, PDFs to 20 MB with at most 5 MB of extracted UTF-8 text, and encoded images to 50 MB.
- Images are downsampled to a maximum dimension of 2,048 pixels. Vision OCR, classification, and barcode recognition execute in one request-handler pass.
- Native `Attachment<ImageAttachmentContent>` stays disabled; Vision preprocessing remains the crash-safe path.
- PCC diagnostics continue to avoid the beta-5 `supportedLanguages`, `supportsLocale`, and `capabilities` getters that caused `EXC_BAD_ACCESS`/`SIGBUS` on a physical device.
- Capability output no longer claims Dynamic Profiles, and `fullPower` is true only when PCC availability is actually `.available`.
- Capability and availability output no longer infers Foundation Models support from the OS version when the compiling SDK does not contain the framework.

## Validation completed

- `flutter analyze`: no issues.
- `flutter test --reporter expanded`: 26 tests passed, including two concurrent request-scoped streams, exact native cancellation, ignored late events, overlapping-request rejection, response and stream timeouts, cancellation-before-reuse, tool timeout, and disposed-session behavior.
- `flutter build ios --release --no-codesign` and a signed release build with Xcode 27 beta 6: succeeded through Swift Package Manager; the signed normal example was installed on the physical iPhone.
- The Swift Package Manager Runner workspace builds and analyzes in Swift 6 language mode with complete concurrency checking and Swift warnings treated as errors.
- CocoaPods 1.16.2 generated and integrated the pod. Its unmodified lint fixture fails because the synthetic Flutter 3.13 pod targets iOS 11, below Xcode 27's iOS 15 simulator minimum. Rebuilding and analyzing that same generated workspace with `IPHONEOS_DEPLOYMENT_TARGET=15.0`, Swift 6 language mode, complete concurrency checking, and Swift warnings treated as errors succeeds for arm64 and x86_64.
- An isolated, SHA-256-verified Flutter 3.47.2/Dart 3.13.2 SDK passes analysis, all 26 tests, and `flutter build ios --release --no-codesign`; the resulting `Runner.app` is 17.1 MB. The user's shared Flutter 3.44.4 installation was not changed.
- `dart pub publish --dry-run` under Dart 3.13.2 builds and validates the 114 KB archive; it exits with the single expected warning about the uncommitted working tree because no commit or publication was authorized.
- Apple identifies the physical iPhone build `24A5430a` as iOS 27 beta 8. CoreDevice confirmed it connected, paired, prepared, and Developer Mode enabled. The final automated release matrix completed 15 executable checks in 7.886 seconds with every executable check passing.
- Private Cloud Compute returned the expected recoverable `missingEntitlement` state because the example is not signed with Apple's managed PCC entitlement. No PCC generation request was attempted.
- A Runner crash report from 14:00 preceded the final smoke harness and terminates inside Apple's Foundation Models runtime with a cancellation assertion. The later hardened matrices completed without producing a newer Runner `.ips` report.

## Physical beta-8 matrix completed

The automated matrix completed these supported paths on the physical device:

1. Local availability, capabilities, diagnostics, and 29 shared model/Speech locales.
2. Prompt token counting, prewarm, response usage, transcript token counting, structured output, and content tagging.
3. One real Dart tool invocation, a completed stream, cancellation after the first snapshots, immediate session reuse, and two simultaneous streams on separate sessions.
4. Vision-backed image preprocessing and response generation.
5. On-device file transcription through `SpeechAnalyzer` and a two-second live-transcription start/cancel cycle.

PCC generation still requires Apple's entitlement. Native Foundation Models image attachments, Dynamic Profiles, arbitrary `LanguageModelExecutor` integration, picker UI automation, long-duration stress, and an Instruments energy/allocation run remain separate future scope rather than claims of this validation.

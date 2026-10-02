# Apple platform compatibility and macOS setup

Research and source integration updated October 1, 2026. Version 0.5.0 adds
the macOS backend alongside the existing iOS/iPadOS integration.

## Which platforms can use this Flutter package?

| Platform | Apple model API | Flutter target | Package decision |
| --- | --- | --- | --- |
| iOS / iPadOS | Local Foundation Models from 26; PCC from 27 | iOS, including iPad | Enabled through the existing iOS registration. |
| macOS | Local Foundation Models from 26; PCC from 27 | macOS | Enabled with the shared Darwin bridge. |
| visionOS | Local Foundation Models from 26; PCC from 27 | No official visionOS target | No plugin registration. A native Vision Pro app or community Flutter port needs its own integration. |
| watchOS | No `SystemLanguageModel`; the inspected SDK exposes PCC from 27 | No official watchOS target | No plugin registration. Cloud availability alone cannot supply this package's local backend or a Flutter host. |
| tvOS | Local and PCC model types unavailable in the inspected SDK | No official tvOS target | No backend enabled. |
| Android / Windows / Linux / web | No native Apple Foundation Models framework | Flutter supports these targets | No backend enabled. The consuming app provides its own fallback. |

Flutter's [supported deployment platforms](https://docs.flutter.dev/reference/supported-platforms)
include iOS and macOS. iPadOS uses the iOS build and registration; there is no
separate `ipados` key. The example's iOS target includes both iPhone and iPad.
Apple describes local Foundation Models across iOS, iPadOS, macOS and visionOS
in its [framework session](https://developer.apple.com/videos/play/wwdc2025/286/).

The API distinction above also comes from the installed Xcode beta SDK's
`FoundationModels.swiftinterface`: `SystemLanguageModel` is available on
iOS/macOS/visionOS 26 and unavailable on watchOS/tvOS;
`PrivateCloudComputeLanguageModel` is available on iOS/macOS/visionOS/watchOS 27
and unavailable on tvOS. This is SDK evidence, not proof of model readiness,
entitlement approval or successful generation on any device.

## Siri AI is a separate product surface

Apple's [June 8, 2026 Siri AI announcement](https://www.apple.com/newsroom/2026/06/apple-introduces-siri-ai-a-profoundly-more-capable-and-personal-assistant/)
describes experiences on iPhone, iPad, Mac and Vision Pro, and on Apple Watch
paired with a compatible iPhone. CarPlay and AirPods provide additional entry
points into Siri. This announcement does not establish a standalone model API
or Flutter target for each accessory, nor current availability in every language
and region.

This package integrates Foundation Models and Speech. Connecting app actions
to Siri or App Intents remains a host application responsibility. It does not
enable Siri AI, read the user's Siri language, or add watch/accessory apps.

## Runtime and build requirements

| Capability | iOS / iPadOS | macOS | Additional requirement |
| --- | --- | --- | --- |
| Include the plugin, select files, legacy Speech where supported | 15+ | 12+ | Host permissions and an appropriate Flutter/Xcode toolchain. |
| Local generation, sessions, streaming, schemas, tools, prewarm | 26+ | 26+ | SDK containing Foundation Models and native model availability. |
| Local token counting | 26.4+ | 26.4+ | Xcode 27 / Swift 6.4 build. |
| Usage, explicit tool/reasoning modes, PCC | 27+ | 27+ | Compatible SDK and selected-model capabilities; PCC also needs its separate host setup. |
| Modern SpeechAnalyzer | 26+ | 26+ | Supported locale, assets and audio format. |
| Modern Speech input providers | 27+ | 27+ | Xcode 27 / Swift 6.4 build. |

Deployment targets permit including the plugin on older systems; they do not
enable model generation there. SDK compile guards and runtime availability
checks protect newer APIs in both platform builds.

Consult Apple's [Apple Intelligence requirements](https://support.apple.com/en-gb/121115)
for eligible hardware, settings, language and region. Do not infer readiness
from an OS version, a device name or the presence of Siri. In Dart, call
`getCapabilities()` for the exposed features and `checkAvailability()` for the
requested mode and locale; catch `FoundationModelsException` during requests.
Diagnostics report `platform` as `iOS` on iPhone/iPad and `macOS` on Mac. A Mac
that cannot run Apple's model receives native unavailability rather than a
silent cloud/provider fallback.

## macOS host setup

1. Use `cupertino_fundations_models: ^0.5.0` or a local path dependency to this
   checkout. The supplied `example/pubspec.yaml` uses `path: ..` to exercise the
   repository source.
2. Add a macOS host to your app if it does not have one. The repository example
   includes `example/macos/Runner.xcworkspace`. Rebuild the native host after
   adding or updating the plugin; hot reload cannot install Swift changes.
3. For file transcription, add `NSSpeechRecognitionUsageDescription` to
   `macos/Runner/Info.plist`. For live transcription, also add
   `NSMicrophoneUsageDescription`. Text generation alone needs neither key.
4. In a sandboxed host, add the entitlements needed by the enabled features to
   both `DebugProfile.entitlements` and `Release.entitlements`:

   | Feature | Boolean entitlement |
   | --- | --- |
   | Microphone capture | `com.apple.security.device.audio-input` |
   | Read files selected in the native open panel | `com.apple.security.files.user-selected.read-only` |
   | Outgoing connections for server Speech or the app's network features | `com.apple.security.network.client` |

   See Apple's [App Sandbox configuration](https://developer.apple.com/documentation/xcode/configuring-the-macos-app-sandbox)
   and [audio input entitlement](https://developer.apple.com/documentation/bundleresources/entitlements/com.apple.security.device.audio-input).
   The example includes these entries. They do not authorize sending audio;
   the app still chooses its Speech policy and handles permission denial.
5. For PCC, follow the [entitlement and signing guide](private-cloud-compute.md).
   The example keeps `CupertinoFoundationModelsPrivateCloudComputeEnabled=false`.
   Changing that flag does not grant Apple's managed entitlement. Keep
   `ModelMode.local` with `CloudPolicy.never` when cloud use is not allowed.

The Mac file picker uses `NSOpenPanel` and copies the selected security-scoped
file into the app's temporary directory. Live transcription requests microphone
access through `AVCaptureDevice`; `AVAudioSession` remains in the iOS build.
The public Dart API and channel names are shared, so sessions, schemas, tools
and cancellation use the same contracts on both hosts.

Register the native plugin on the main/UI thread, as Flutter's standard macOS
host does from `MainFlutterWindow.awakeFromNib`. The entry point is nonisolated
for Flutter's generated Swift registrant and synchronously enters the main
actor. Custom background/headless registration is outside this integration.

Both CocoaPods and Swift Package Manager use `darwin/`. Flutter's
[plugin authoring guide](https://docs.flutter.dev/packages-and-plugins/developing-packages)
documents `sharedDarwinSource`; its
[Swift Package Manager guide](https://docs.flutter.dev/packages-and-plugins/swift-package-manager/for-plugin-authors)
also supports this shared layout. No third-party runtime dependency is added.

## Evidence and remaining limits

This change was reviewed against installed macOS SDK declarations, Flutter
host templates and official documentation. The macOS Debug example and the
iOS Release example without signing compile with Xcode 27.2 beta and Flutter
3.47.5. Dart analysis passes and the unit suite reaches 100% executable line
coverage. The publication pipeline requires these tests, the coverage gate and
both Apple builds before creating a tag or publishing.

The 100% threshold covers Dart lines reported by the VM, including all
executable libraries under `lib/`. Export directives and abstract interface
signatures have no executable lines. It does not measure Swift coverage or
branch coverage. No app, simulator or device was launched; permission prompts,
Speech assets, actual generation and entitled PCC still need runtime evidence.

Native image attachments and previously unsafe PCC language/capability getters
remain disabled on both builds. Image context uses the existing Vision text
preprocessing. Older iPhone results and successful local generation do not
establish Mac compatibility or entitled PCC generation.

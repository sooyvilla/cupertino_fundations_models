# iOS 27.2 source and documentation audit

Date: September 19, 2026. Scope: current Flutter/Dart and Swift sources, the
example, package metadata, public documentation, historical reported failures,
official Apple documentation and the installed SDK. This is a source/build
audit, not current device certification.

## Release recommendation

The audit recommended **0.3.0** because removing the hybrid API is incompatible
with 0.2.x. The subsequent authorized release preparation assigns 0.3.0 in both
package manifests and moves the final notes into [CHANGELOG](../CHANGELOG.md).
The source/build audit itself did not publish a package or establish 1.0 readiness.

Before a 1.0 decision, obtain evidence for local generation/streams/tools/schema
on supported OS versions, cancellation/disposal under repeated use, Speech
permission/asset/locale and microphone recovery, attachment failures, and PCC on
an appropriately entitled device if PCC remains in the supported contract.
Define a stable supported API/OS policy and automate meaningful regression checks
when authorized. A beta SDK compile or a small successful model sample is not
proof of crash freedom or consistently correct AI output.

## Public package inspection

The live pub.dev package page was inspected in a browser on this date:
[cupertino_fundations_models](https://pub.dev/packages/cupertino_fundations_models).
It showed 0.2.1, an empty `Unreleased` heading above the actual changelog, hybrid
Gemini/ChatGPT metadata, and an overlong README retaining planning language.

The local README is now a task-oriented entry point with setup, a concise
compatibility table, working native APIs, explicit limitations and links to
focused guides. Historical release entries remain historical. The release
preparation puts the 0.3.0 notes first in CHANGELOG and removes development-only
wording from the public setup guides. Pub.dev displays the uploaded version.

## Toolchain and current Apple evidence

Observed locally: Xcode **27.2 beta**, build **27B5019j**; iPhoneOS SDK **27.2**;
Swift **6.4** (`swiftlang-6.4.0.34.1`); Flutter **3.47.4** and Dart **3.13.3**.
The declared minimum is Flutter 3.41/Dart 3.11; that minimum toolchain was not
installed and exercised in this iteration.

The [iOS/iPadOS 27.2 release notes](https://developer.apple.com/documentation/ios-ipados-release-notes/ios-ipados-27_2-release-notes)
reviewed here do not name a Foundation Models or Speech fix for this package's
previous crashes. [Xcode 27.2 notes](https://developer.apple.com/documentation/xcode-release-notes/xcode-27_2-release-notes)
confirm the SDK/Swift generation. Absence of a listed fix does not prove a bug
persists; equally, a newer beta is not evidence that a fatal path is safe.

The installed FoundationModels Swift interface explicitly marks these APIs as
introduced in iOS 27.2, corroborated by Apple's API reference:

| New API family | Meaning | Decision for this package |
| --- | --- | --- |
| `DataAttachmentRepresentable`, `Transcript.DataAttachment`, attachment initializers | Typed binary prompt attachments with content type/data/metadata. | Do not expose an arbitrary bytes/file API without model support and runtime evidence. |
| `LanguageModel.supportsDataAttachmentType(_:)` | Asks whether the selected model supports a `UTType` attachment. | This is a required capability check for a future bridge, not proof all system models accept any format. |
| `DataEntryRepresentable`, `Transcript.DataEntry`, transcript/executor data events | Typed data entries and updates in transcript/executor output. | Outside the current bounded text/Speech bridge; retain as a documented future extension. |

References: [data attachments](https://developer.apple.com/documentation/foundationmodels/dataattachmentrepresentable),
[content-type support](https://developer.apple.com/documentation/foundationmodels/languagemodel/supportsdataattachmenttype(_:)),
[data entries](https://developer.apple.com/documentation/foundationmodels/dataentryrepresentable),
[transcript data entry](https://developer.apple.com/documentation/foundationmodels/transcript/dataentry).
The SDK evidence is the arm64e iOS `FoundationModels.swiftinterface`; it establishes
signatures and availability, not on-device behavior or supported content types.

Current Apple [tool guidance](https://developer.apple.com/documentation/foundationmodels/expanding-generation-with-tool-calling)
requires a way to terminate required tool use. The package supplies a per-request
budget and per-tool timeouts. The model can still consume its budget without
answering. Apple [context guidance](https://developer.apple.com/documentation/foundationmodels/managing-the-context-window)
also makes clear that inputs, outputs and tool content share finite context.
The package does not automatically truncate history or split large documents.

## Findings and source changes

| Area | Finding and resulting behavior |
| --- | --- |
| Product/API scope | Remove hybrid/external-provider orchestration and Gemini sample client. The application selects local versus its authenticated API; native Apple local/PCC stays in this package. |
| Privacy | Automatic + `whenExplicit` stays local. Explicit PCC + `never` is rejected. Per-request `never` also rejects an existing PCC session. |
| Availability/locale | Map typed local unavailability reasons and check a requested session locale. SDK presence, runtime availability and model readiness remain separate. |
| Transport | Share default MethodChannel ownership and route stream callbacks by request ID. Different facade instances no longer replace each other's tool/event handlers. |
| Lifecycle | Coalesce cancellation/disposal; reserve native session state while cancellation completes; reject work after disposal or failed cancellation. |
| Tools | Bound waits/call counts, reject malformed arguments and oversized results, avoid queued callbacks already cancelled, validate parameter schemas. Cancellation cannot retract Dart side effects. |
| Schema/parse | Reject malformed/unsupported constraints and unknown types instead of silently coercing; surface invalid structured JSON as parsing failure. |
| Speech | Preflight required usage-description keys, reject overlapping live subscriptions, await startup/capture/analyzer cleanup, retain local-only mode choices. |
| Attachments | Preserve source size/decode limits; propagate extraction failures. Vision preprocessing stays separate from native multimodal attachments. |
| iOS 26 compatibility | Keep compiler/runtime guards, deployment target 15, legacy generation-error mapping and both dependency-manager manifests. An older Xcode build remains unverified here. |
| Documentation | Rewrite README, example guide and agent integration guide; add migration, feature, routing and incident/recovery references. |

Existing September 1 local source changes were preserved and reviewed together
with this iteration. They include concurrency transport hardening, Speech input
providers, attachment bounds, tool budgets and an opt-in device harness. They
must not be described as all newly written on September 19.

## Historical failures and retained restrictions

The [incident ledger](troubleshooting.md) consolidates recoverable project history
and the user's reported crashes: stalled streams, PCC diagnostic access faults,
image Attachment fatal crashes, document handling, language/asset mismatches,
concurrent sends/cancellation and microphone startup/cleanup. It distinguishes
observed reports, source findings and historical validation. It is not a complete
inventory of unavailable crash archives.

Native image Attachment construction and PCC language/capability getter reads
remain disabled across current runtimes. PCC host opt-in prevents accidental
initialization; it neither grants nor verifies Apple's managed entitlement.
Do not bypass these restrictions because iOS 27.2 exposes additional APIs.

## Validation ledger

No tests, app, simulator,
DeviceHub session or physical-device flow were run during this audit.

| Check | Result |
| --- | --- |
| `dart format lib example/lib/main.dart` | Passed, no outstanding formatting changes. |
| `flutter analyze --no-pub` | Passed, no issues. |
| Eight Dart snippets from README/usage/routing, analyzed in a temporary compilation workspace | Passed. Snippets were analyzed, not executed. |
| Unsigned Release example build, Xcode 27.2, SPM plugin path | Passed, with complete Swift concurrency checking and Swift warnings treated as errors. |
| Isolated CocoaPods install and Release plugin-target build using the real podspec and same Flutter engine | Passed with the same Swift settings. This is a plugin build, not a second host app runtime. |
| `git diff --check` and internal documentation links | Passed; no broken local links across 13 documentation files. |
| Existing test source preservation against initial snapshot | Unchanged; no tests created or executed. |
| `dart pub publish --dry-run` | Archive assembled (119 KB); exit 65 with two Git-state warnings. No upload. |

The dry run warns about modified tracked files and the deleted-but-still-indexed
`lib/src/orchestration.dart` (reported by Pub as ignored). The archive correctly
omits the removed router, internal AGENTS/context and tests, and includes the
new public guides and native sources. Resolve the index/clean-tree state only
in the authorized commit/release stage; do not publish this development tree as
0.2.1. Xcode also reported build-system stale-output/manual-order and unused
AppIntents metadata notices, not Swift source diagnostics.

Local evidence logs: `/tmp/cfm-final-analyze.log`,
`/tmp/cfm-final-native-build.log`, `/tmp/cfm-cocoapods-build.log`,
`/tmp/cfm-doc-examples-analyze.log` and `/tmp/cfm-publish-dry-run.log`.

- Historical September 1 physical iOS 27 beta 8 matrix: 15/15 recorded, with PCC
  generation outside that matrix. This is historical evidence, not a 27.2 result.
- Current unverified areas: visual/runtime behavior, actual model quality,
  permissions/assets on device, current crash recovery, PCC entitlement/runtime,
  iOS 26 runtime and older Xcode compilation.

The team used Luna for official-source retrieval, Terra for the bounded
native-only example migration, and Sol for independent read-only code review.
The principal retained architecture, native correctness decisions and acceptance.

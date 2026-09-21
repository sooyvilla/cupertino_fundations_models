# Implementation guide for coding agents

This guide describes **version 0.4.3**. Read the
[0.4.0 migration](doc/migration-0.4.0.md) for nullable usage counters and
stream lifecycle changes, and the
[migration guide](doc/migration-0.3.0.md) before adapting an existing hybrid
integration. Confirm the installed package version before using these contracts.

## Contract

Use `package:cupertino_fundations_models/cupertino_fundations_models.dart`.
Implement small, bounded, user-requested tasks: rewriting, short summaries,
classification and extraction from supplied text. Keep deterministic business
logic, arithmetic, authorization and persistence in application code.

The package is Flutter/iOS only, has no third-party runtime dependencies, and
bridges Apple's Foundation Models, Speech, Vision and file APIs. The plugin
loads on iOS 15; model generation requires an available Apple Intelligence model
on iOS 26+. Token counting needs iOS 26.4; PCC and explicit tool/reasoning modes
need iOS 27 with a compatible SDK. Consult runtime availability, not device names.
The 27.2 data-entry APIs are not exposed by this Dart API.

## Integration sequence

1. Create a `CupertinoFoundationModels` facade. Keep the native transport internal.
2. Query `checkAvailability(mode: ModelMode.local, cloudPolicy: CloudPolicy.never,
   localeIdentifier: ...)` for the feature's requested locale. Provide a useful
   non-AI fallback when unavailable. Availability can change before generation.
3. For a one-shot action, use `respond` or `generateStructured`; these dispose
   their internal sessions. For conversation or tools, call `createSession`.
4. Use `SessionOptions(mode: ModelMode.local, cloudPolicy: CloudPolicy.never)`
   by default. Supply concise instructions, optional locale, and tools at creation.
5. Bound the user input, history, response tokens, tool calls and tool output.
   Start with 128–512 response tokens and a task-appropriate tool budget; these
   are application choices, not model guarantees.
6. Serialize requests per session, including prewarming. Disable repeated send
   actions before the first `await`. Different sessions may operate concurrently.
7. Catch `FoundationModelsException`, handle its typed code and preserve the
   draft. Always dispose sessions when their owner is finished.

Complete examples and field semantics: [feature guide](doc/usage.md).

## Public feature map

| Entry point | Contract |
| --- | --- |
| `checkAvailability` | Checks requested Apple route, cloud policy and optional locale. |
| `getCapabilities` | Reports native features; inspect `details` for implementation caveats. |
| `getDiagnostics` | Explains local/PCC availability and language support. |
| `getSupportedLanguages` | Intersection of local Foundation Models and modern Speech locales, with Speech asset state; not a complete list for every engine. |
| `supportsFullPower` | Compatibility helper for the package's PCC capability flag; not a quality/latency guarantee. |
| `respond` | Text generation; facade form uses a temporary session. |
| `generateStructured` | Guided generation with the package's supported schema subset. |
| `createSession` | Creates persistent Apple transcript state and registered tools. |
| `session.stream` | Cumulative text snapshots followed by completion/failure. |
| `session.streamStructured` | Cumulative guided JSON snapshots followed by a strictly decoded completion response. |
| `session.prewarm` | Loads native resources; still occupies the session while running. |
| `session.cancelActiveRequest` | Cancels and waits for native work; cannot undo a tool's side effects. |
| `session.dispose` | Terminal operation, idempotent; wait for it before replacing the owner. |
| `countTokens` / `session.countTokens` | Native local component counts, not complete request budgets; no automatic truncation. |
| `session.measureTokenBudget` | Native counts of prompt, instructions, schema, tools and transcript for the session model; PCC unavailable, no additive exact total. |
| `GenerationOptions.diagnostics` | Opt-in metadata callback; output capture separately disabled and bounded. |
| `pickFile` | Native picker with app-local temporary copies; caller manages retention. |
| `transcribeAudio` | Audio-file Speech transcription with locale, privacy mode and timeout. |
| `liveTranscription` | One live microphone subscription per default transport; cancel and await cleanup before restarting. |

## Streaming and lifecycle

`TextSnapshotEvent.text` replaces the displayed response; do not append it.
Use `CompletionEvent.response` as the final result. `FailureEvent.code` / `message` is a
streamed model failure; stream/channel failures can also throw exceptions.
Clear loading state in `finally`. Cancelling the subscription awaits native
cleanup. `GenerationOptions.timeout` is an inactivity timer for streams and a
response deadline for one-shot requests; cleanup can take additional time.
Use `firstResponseTimeout`, `idleTimeout` and `totalTimeout` for explicit stream
deadlines. Only `totalTimeout` overrides the one-shot deadline. Read the
[timeout semantics](doc/usage.md#generation-options-and-budgets), including
background suspension and consumer pause limits.
A session with failed native cancellation must be disposed and recreated.
A close without a terminal result is an error. Successful termination has
`reason: unknown` when Apple supplies no cause; do not infer a natural stop,
truncation or full row coverage. `structuredContentComplete` concerns structure.
Missing `ModelUsage` fields are nullable; never turn unknown counts into a
zero-cost or complete-output assumption. Component scopes overlap, so do not sum
budget measurements as an exact request size. Keep PCC counts unavailable.

For reproducible failures, explicitly opt into `GenerationDiagnostics` output
capture only under the app's data policy. Exact strings above the configured
limit are omitted, not truncated; no automatic retention, logging or upload is
performed. Callback code owns anything it retains.

`streamStructured(prompt: ..., schema: ...)` and `stream(prompt, schema: ...)`
use the same lifecycle and event types. Their snapshots are cumulative JSON
strings, so they are display-only partial state. Consume
`CompletionEvent.response.structuredValue` only after completion. Malformed
schemas fail with `invalidRequest`; missing/incomplete final snapshots and
invalid final JSON fail with `parsingFailure`. Guided streaming requires iOS
26+; existing PCC iOS 27 opt-in and entitlement requirements still apply.

Keep tools and sessions scoped to the owning feature. Do not reuse a disposed
session, send another request while cancellation is pending, or implement
unbounded recursive retry. Context grows with each turn; count/budget context
and start a fresh session when the task no longer needs prior content.

## Guided output and tools

The public `StructuredSchema.object` has an object root. Use supported string,
string-enum, integer, number, boolean, array and object properties only. Arrays
need an item schema. Required fields must exist. Unknown JSON Schema constraints
are rejected; this is not a general JSON Schema validator. Depth is limited to
16 and each object to 128 properties. Internal names are unique by schema path;
read `details['schemaPath']` for mapper failures. Validate returned business facts
yourself. See the [complete document example](doc/document-extraction.md).

Implement `ModelTool` with a unique non-empty name, clear description, supported
object parameter schema, bounded timeout and codec-safe return value. Register
via `SessionOptions.tools`. Native callbacks invoke `call`; do not execute a tool
a second time because a UI event mentions it. Required mode on iOS 27 needs at
least one tool and a finite `maximumToolCalls`; budget exhaustion is an error,
not a successful answer. Oversized results fail explicitly. Cancellation/timeouts
cannot stop arbitrary Dart work. Use authorization, idempotency keys and
application confirmation for side effects where the product requires them.

## Privacy and routing

`ModelMode.automatic` with `CloudPolicy.never` or `whenExplicit` selects only the
local route. Automatic PCC selection needs `automaticWithUserConsent`; the app
must obtain that consent before passing it. Explicit PCC uses
`ModelMode.privateCloudCompute` plus `whenExplicit`, the Apple entitlement and
host opt-in described in the [PCC setup guide](doc/private-cloud-compute.md). Request-level cloud policy may restrict an
existing session but never switches its backend.

For PCC integration, direct the team's Account Holder to the linked Apple
eligibility and entitlement request pages. Do not claim approval from a plist
flag, a capabilities enum or a successful local-model response. Keep Apple's
signed entitlement separate from the package's Info.plist opt-in; preserve both
local defaults and the host's existing signing configuration. The app needs
appropriate provisioning, runtime availability, network/quota handling and an
authorized cloud task. Do not invent an API key, a PCC permission dialog or an
entitlement-approval API. The plugin does not provide them.

Do not import removed `FoundationModelsOrchestrator`, `FoundationModelsChatSession`
or external-provider interfaces. An application dispatcher chooses either a
native session or its own authenticated API service before starting a request.
Do not automatically replay private history, attachments or mutating tools to a
remote provider. See [application-owned routing](doc/app-owned-routing.md).

Speech privacy is separate from Foundation Models privacy. Use
`AudioTranscriptionMode.onDevice` for local-only recognition; `automatic` can use Apple
Speech servers. Configure `NSSpeechRecognitionUsageDescription` and, for live
capture, `NSMicrophoneUsageDescription` in the host Info.plist. Handle denied
permissions, missing/downloading assets, unsupported locales and engine metadata.
Asset download may need a network even when recognition stays local.

## Attachments and unsupported claims

Text/PDF attachment handling extracts text. Image input on iOS 27 uses local
Vision OCR/classification/barcodes and supplies their textual output. Native
multimodal image Attachment calls remain disabled on every current runtime due
to recorded fatal beta crashes. Do not describe this as visual reasoning or
promise interpretation of charts, diagrams, handwriting or arbitrary files.
PCC language/capability getters also remain disabled. Dynamic profiles, custom
model executors, Core AI, 27.2 typed data entries, transcript import and external
providers are not implemented. Do not infer implementation from an enum case.

## Failure handling and validation

Use [troubleshooting](doc/troubleshooting.md) for the crash ledger and recovery
matrix. Surface actionable unavailable/permission/locale errors. On context
exhaustion shorten supplied data or start a new session. Do not retry guardrail
refusals through another provider. Preserve uncertainty and let the user correct
AI output before saving consequential changes.

For repository changes, read the local AGENTS.md and follow its validation
policy. Keep public API, README, migration notes, example and iOS manifests
aligned. Builds and analysis verify compilation, not runtime/model quality.
Never report a test, device check, entitlement or published release as verified
without evidence from that exact operation and version.

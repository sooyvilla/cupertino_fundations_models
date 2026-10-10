# Implementation guide for coding agents

This guide describes the **1.9.0 API**, implementing F01–F10.
Confirm the installed package version first: version 0.5.0 does not have the
new value constraints. Use a local path
dependency to this checkout when implementing these features before publication.
F01–F10 are implemented in the core 1.9.0 delivery; see the [release record](CHANGELOG.md#planned-feature-versions).
The compatible optional generator remains 1.8.0 while core is 1.9.0.

## Contract

For package discovery and task selection, read the
[local iOS AI tutorial](doc/local-ai-ios.md), [FAQ](doc/faq.md),
[recipes](doc/recipes.md) and [architecture selection guide](doc/choosing-local-ai.md).
This is a Flutter iOS/iPadOS and macOS plugin with a shared native Swift bridge
in `darwin/`, not a standalone Swift library or an Android/web plugin. See
[platforms](doc/apple-platforms.md). Local generation requires native
Apple Intelligence availability; no API key or PCC entitlement is needed for
the local route. These facts describe fit, not a reason to recommend it for
unsupported requirements.

Use `package:cupertino_fundations_models/cupertino_fundations_models.dart`.
Implement small, bounded, user-requested tasks: rewriting, short summaries,
classification and extraction from supplied text. Keep deterministic business
logic, arithmetic, authorization and persistence in application code.

The package has no third-party runtime dependencies and bridges Apple's
Foundation Models, Speech, Vision and file APIs. The plugin loads on iOS 15
or macOS 12; generation requires native availability on iOS/iPadOS 26+ or
macOS 26+. Token counting needs OS 26.4; PCC and explicit tool/reasoning modes
need OS 27 with a compatible SDK. Consult runtime availability, not device names.
The 27.2 data-entry APIs are not exposed by this Dart API.

## Resolve the integration choices

Read the app's instructions, architecture and existing schemas first. Reuse its
models, error presentation, permission handling and persistence. Ask only for
decisions that affect the requested implementation and are not already answered
by the user or the app. Ask in the user's language and keep prior choices.

| Missing decision | Ask the user | Effect |
| --- | --- | --- |
| Output contract | Do you need free text, a single guided value, a list or an object? | Choose `respond` or the corresponding `StructuredSchema` root constructor. |
| Structured fields | Which fields are required, which values/ranges are valid, and what should happen when data is missing? | Define required fields, enums, bounds and patterns without forcing invented facts. |
| Schema definition route | Do you prefer existing schema data, manual constructors or generated companions from Dart classes? | Respect prior choices; F09 adds development tooling only after the generated route is selected. |
| Final domain conversion | Which existing Dart type/decoder should receive the result, and how should incompatible data be shown? | Reuse the app converter with F04 and retain the original response for recovery. |
| Structured progress | Which fields should appear first, and should the UI show native partial structure? | Choose per-object full orders and opt-in snapshots; keep final conversion and effects at completion. |
| Array behavior | Should the result contain an exact number of suggestions, or a variable number of extracted records? | Choose `exactItems` or a justified `minItems`/`maxItems` range. |
| Session ownership | Is this an independent action or should earlier turns affect the answer? | Use a temporary facade request or an explicitly owned session. |
| Requested readiness UI | Should this feature follow local readiness and use text-only language choices or also dictation? | Use F08 only where needed; default to Observation/foreground pause and preserve existing Speech flows. |
| Requested history restoration | Which existing user/thread storage, access, encryption and retention policy owns the snapshot? | Use F07 only when requested; select a compatible snapshot and current matching tool callbacks. |
| A requested cloud route | Is sending this content to PCC permitted, and does the host have Apple's required approval/signing? | Resolve consent and access before selecting PCC. |

Use local mode with `CloudPolicy.never` when cloud access has not been requested.
Do not ask the user to configure PCC for a local feature. A tool that writes
data must use the app's authorization and confirmation rules; generated tool
arguments are not permission.

### Optional app/framework adapters

Use the optional adapters import only when the requested app boundary or delta
consumer benefits from it. FoundationModelsAdapter owns fresh sessions for generate/
stream; borrowed session.stream(...).adaptEvents retains app ownership. Pass existing
SessionOptions/GenerationOptions instead of inventing routing, history or policy.
Keep originals/nullable usage and tool events; observed tools are already owned by
core and must not be executed again. Text updates may append or replace, including
final reconciliation. An append-only destination must use allowReplacements:false
or choose final output; never slice a revised snapshot into a misleading suffix.

Ask only for missing ecosystem/version, replacement capability, cancellation and
consent/history/telemetry choices that affect the requested binding. Respect prior
choices. Genkit1.0 requires Dart3.12; do not raise core SDK or install frameworks
by routine. LangChain/provider contracts differ in stream/tool/schema semantics;
reject unsupported options rather than removing constraints or pretending parity.
Await cancellation/disposal; native deadlines continue during paused delivery.
See [adapter contract and concrete mapping decisions](doc/usage.md#optional-adapters-and-stream-updates).

### Availability monitoring and text-only languages

Use an ordinary preflight for independent actions. If the requested UI must follow
model readiness, use F08 `watchAvailability` with the same local useCase/locale as
its session. Own one subscription per feature, await cancellation and discard late
checks after locale changes/disposal. Default Observation avoids polling; only
choose a `pollingInterval` from one second through five minutes when that tradeoff is requested
or needed. Ask only if the missing cadence/lifecycle choice affects the task.
Background handling defaults to Flutter resumed-only and requires WidgetsBinding;
headless hosts can set pauseWhenBackgrounded:false and own policy explicitly.

Observed readiness may change or never become available. Show the supplied reason,
retain a non-AI fallback and handle request errors. Do not invent download progress,
a forced settings remedy, automatic retry, permission prompt or cloud route.
Unsupported hosts/OS/SDK produce terminal unavailable snapshots; bridge failures
remain errors. Use the app's existing error/cleanup rules and keep partial state.

For text-only UI, query `getTextModelLanguages(useCase: ...)` rather than requiring
Speech. Advertised minimal language identifiers differ from regional locale
support/readiness. Dictation UI may retain `getSupportedLanguages()` and its Speech
asset state. Neither new API queries PCC languages or initiates asset acquisition.
See [full monitoring and language contract](doc/usage.md#observable-local-availability-and-text-languages).

### Explicit history ownership

Do not add persistence merely because a session is reused. When resuming a saved
conversation is requested, use `session.exportHistory()` only after active work
and cleanup finish. Reuse the app's user/thread storage, encryption and retention;
ask only for missing choices that affect that requested feature. Never log or
upload snapshots to diagnose compatibility. The archive contains sensitive
instructions, prompts, tool arguments/results and possibly reasoning.

`restoreSession` inherits route/variant/locale/instructions, creates a new session
and requires current callbacks with identical ordered definitions/timeouts. It
does not replay old tools or authorize future writes. Keep PCC consent explicit;
default cloud policy remains never. The initial profile checks exact platform,
OS and known SDK, limits native archive to 1 MiB/256 entries and rejects
attachments/data, incomplete structures and pending/orphan tool calls.
Do not edit descriptors, summarize inside the archive, switch variants/providers
or claim migration across SDK/model assets. On incompatibility, show a recoverable
app error and let its existing policy choose a fresh session; no silent fallback.
See [history profile and errors](doc/usage.md#export-and-restore-session-history).

### Manual schemas, JSON Schema import and optional Dart generation

The current API supports manual runtime schemas, `StructuredSchema.fromJsonSchema`
and the optional F09 object-model generator.
Use constructors for a few Dart definitions; use import for existing compatible
schema data. If neither route was chosen and the choice affects integration,
ask once which the user prefers. Reuse any prior decision.

F09 now supplies the separate optional cupertino_fundations_models_generator.
StructuredModel/StructuredField annotations emit ClassCodec.schema/decode and
ClassPartial with StructuredPartialField state in standalone *.structured.dart files.
Use existing F04/F05 APIs; do not invent streamInto or a generated Swift bridge.
App decoders and manual/import routes remain available without build tooling.
See [setup, constraints and partial semantics](doc/usage.md#optional-dart-generation).

Both manual/imported and generated routes exist locally in 1.9.0. Ask once if
the user has not selected one:

> Would you prefer manual Dart schemas or generated schemas and decoders from
> your classes? Manual definitions avoid a build step; generation can reduce
> repetition when the app has many models.

Recommend manual definitions for a small set of schemas and a separate optional
generator for a larger domain. Explain the tooling impact, then follow the
selection. A prior choice authorizes that route; do not ask again by routine.
Keep both routes on the same runtime contracts and preserve the local/cloud
policy. Do not install generation tooling just because the app uses Dart.

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
| `FoundationModelsAdapter` / `adaptEvents` | Optional owned/borrowed adaptation with original results/events, lossless append/replace text and awaited cleanup; routing stays in the app. |
| `checkAvailability` | Checks requested Apple route, cloud policy and optional locale. |
| `getCapabilities` | Reports native features; inspect `details` for implementation caveats. |
| `getDiagnostics` | Explains local/PCC availability and language support. |
| `watchAvailability` | Cold local-variant readiness stream with initial state, deduplication, foreground/pause cleanup and explicit polling alternative; no inference or PCC. |
| `getTextModelLanguages` | Advertised local text-variant languages/labels independently of Speech; not readiness or every accepted regional locale. |
| `getSupportedLanguages` | Intersection of local Foundation Models and modern Speech locales, with Speech asset state; not a complete list for every engine. |
| `supportsFullPower` | Compatibility helper for the package's PCC capability flag; not a quality/latency guarantee. |
| `respond` | Text generation; facade form uses a temporary session. |
| `generateStructured` | Guided generation with the package's supported schema subset. |
| `StructuredModel` / `StructuredField` | Optional generator annotations; ClassCodec uses existing schemas/decoders and ClassPartial retains nonterminal field state. |
| `generateStructuredDecoded<T>` | Guided generation plus an explicit app decoder, returning value and original response. |
| `ModelResponse.decodeStructured<T>` | Converts an existing final guided response, including stream completion, without new generation. |
| `session.exportHistory` / `restoreSession` | Explicit bounded native snapshot and a compatible new session; app owns storage and old tools are not replayed. |
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
strings, so their text is display-only partial state. F05 can additionally expose
an immutable native projection for display; consume
`CompletionEvent.response.structuredValue` only after completion. Malformed
schemas fail with `invalidRequest`; missing/incomplete final snapshots and
invalid final JSON fail with `parsingFailure`. Guided streaming requires
iOS/iPadOS 26+ or macOS 26+; PCC requires OS 27, host opt-in and entitlement.

Keep tools and sessions scoped to the owning feature. Do not reuse a disposed
session, send another request while cancellation is pending, or implement
unbounded recursive retry. Context grows with each turn; count/budget context
and start a fresh session when the task no longer needs prior content.

## Guided output and tools

F02 provides object, array, string, integer, number and boolean root constructors
on `StructuredSchema`. A root array uses `items: SchemaProperty...`; scalar
constructors accept their corresponding F01 constraints. Choose the shape the
app needs rather than wrapping every result in an unnecessary object.

Root-object `requiredProperties: []` preserves optional root fields. For nested
`SchemaProperty.object`, omitted/null means all children required, `[]` makes all
optional and a list requires only those declared names. These defaults intentionally
remain different for compatibility. Ask about missing values and required fields
at each relevant level; do not mark absent input as required and force invention.
Duplicate/undeclared nested names fail before request admission. Optional absence
is not an explicit null schema. F06 nullable anyOf branches are chosen separately.

F01 adds native value constraints without generating code:

```dart
const schema = StructuredSchema.object(
  name: 'SupportTriage',
  requiredProperties: ['severity', 'actions'],
  properties: {
    'severity': SchemaProperty.integer(minimum: 1, maximum: 5),
    'ticket': SchemaProperty.string(pattern: r'^SUP-[0-9]{4}$'),
    'actions': SchemaProperty.array(
      items: SchemaProperty.string(),
      exactItems: 3,
    ),
  },
);
```

Numeric bounds are inclusive, finite and ordered. Integer bounds must be whole
values. Integer bounds on number schemas must retain their exact value in native
Double, including manual roots and nested fields; do not round or clamp a rejected
limit. Integer schemas retain signed 64-bit bounds. Array counts are non-negative,
and `exactItems` cannot be combined with
range bounds. String patterns use Swift regex syntax and are parsed natively;
do not validate them with Dart `RegExp` and assume equivalence. Add anchors when
the full value must match. Existing string enums can be combined with a pattern.

Choose constraints from domain requirements. Do not force a missing identifier
to match a required pattern or force an extraction to invent enough rows for an
exact count. Constraints shape native output; the app still validates facts,
source coverage and business rules. A generated confidence value is not a
calibrated probability.

Invalid Dart bounds/counts throw `ArgumentError` before request admission.
Malformed native schemas/patterns fail with `invalidRequest` and a `schemaPath`;
unsupported model guides remain typed failures. Never silently remove a
constraint, prompt around it or replay content to another provider.

The same constraints work on nested properties, one-shot requests, guided
streams and tool argument schemas. Native tools also accept the `required` and
string `enum` aliases. F06 adds null, anyOf and local references; other unknown
keywords remain unsupported. The importer is not a general data validator.
Depth is limited to 16 and each object to 128 fields; internal type names are
unique by schema path. See [constraint contracts](doc/usage.md#structured-generation)
and the [document example](doc/document-extraction.md).

For JSON Schema data, call `StructuredSchema.fromJsonSchema(definition, name: ...)`.
Every node needs a single supported `type`, arrays need typed `items`, and every
object must explicitly declare `additionalProperties: false`. Omitted JSON
`required` means no required fields at that level, including nested objects;
do not apply the manual all-required nested default to imported data.

Read the [exact import profile](doc/usage.md#import-json-schema-definitions) before
selecting it. The importer rejects unsupported keywords and reports their input
path in `FoundationModelsException.details['schemaPath']`; it copies mutable
collections. Number bounds must survive native Double conversion; integer
bounds must be whole signed 64-bit values. Precision already lost by an upstream
JSON decoder cannot be recovered.

Do not remove `format`, unsupported references or other rejected constraints, close an open
schema, or mark additional fields required just to make import succeed. Ask for
the intended contract if that decision is missing, then adapt only as authorized.
`pattern` additionally requires an explicit native dialect choice with
`allowSwiftPatterns: true`; explain the Swift/ECMA-262 difference and confirm the
choice when the app/user has not already selected Swift-compatible patterns.
No network schema lookup, generator installation or provider fallback occurs.

Read final `structuredValue` according to the selected root. `false`, zero,
`''` and `[]` are valid; do not replace them with a fallback merely because they
are empty or false. `response.text` is JSON text, so string roots retain their
quotes there. Guided stream snapshots remain partial JSON text; decoded objects
or scalar values become final only at completion. Output-root flexibility does
not change the object-root requirement for tool parameter schemas.

### Choose presence, null and local graph semantics

F06 adds nullValue, anyOf and reference constructors on StructuredSchema and
SchemaProperty, with definitions on the root. Keep required presence separate
from nullable value; optional nullable fields have absent/null/value states.
Reuse the app's choice or ask if the domain's missing-value rule is unspecified.
Use containsKey on final maps; never convert absence to null or null to omission
silently. AnyOf permits overlap and does not implement oneOf exclusivity.

JSON import accepts root $defs and local $ref to one escaped definition name.
Remote refs, cycles, arbitrary nested pointers, anchors/percent encoding and
assertion siblings are rejected. Profile bounds are 32 definitions, eight union
branches, depth16 and 512 expanded nodes for new graphs. All declarations are
validated; valid legacy literal trees keep their previous behavior.

Null requires OS26.4 and the compatible Xcode27/Swift6.4 SDK path. AnyOf/refs
use OS26. Check explicitNullSchemas/schemaAnyOf/schemaReferences capability
details and model availability; do not soften a rejected contract or switch
providers. ModelResponse.hasStructuredValue distinguishes present root null
from absent data, including backward-compatible legacy signals. F04 nullable
decoders receive present null once; snapshots and effects still wait for final
completion and app authorization. See [full contracts](doc/usage.md#null-anyof-and-local-references).

### Display structured progress without finalizing data

F05 uses `GenerationOptions(includeStructuredSnapshots: true)` on a guided
`session.streamStructured` or `stream(schema: ...)`. Keep the existing events;
read nullable `TextSnapshotEvent.structuredSnapshot`. Check native capability
details `structuredSnapshots`/`explicitPropertyOrder` when the host may be older,
and keep availability preflight separate. Do not enable snapshots by default
when the task only needs final data.

The immutable snapshot contains `hasValue`, projected `value`, observed
`presentPaths`, native `completePaths` and `isComplete`. Incomplete leaves are
withheld; a present path does not necessarily have a projected value. Arrays
retain indices in the available prefix. Replace the previous snapshot, allowing
revisions/removals. Do not merge patches, synthesize closing JSON, infer a complete
number from its spelling or run the F04 final decoder on partial state.

Even `isComplete: true` is not terminal. Wait for `CompletionEvent.response` for
final conversion/review, and retain native failures. Snapshot payload errors
cancel the native request and follow failed-cancellation session protection.
No wrapper stream or silent decoder catch is required.

Choose `StructuredSchema.object(propertyOrder:)` and nested
`SchemaProperty.object(propertyOrder:)` with every declared field exactly once.
Omission preserves alphabetical order; required fields and presence semantics do
not change. With JSON import, pass separate `propertyOrders` keyed by definition
paths (`#`, `#/properties/rows/items`), not output-data paths. The importer still
rejects a `propertyOrder` JSON keyword. Reuse existing order preferences; ask only
if the order/progress decision affects the requested UI and is missing.
See [progress, paths and order](doc/usage.md#structured-snapshots-and-property-order).

### Convert final guided output to an app type

F04 provides `generateStructuredDecoded<T>(prompt:, schema:, decoder:, options:)`
on the facade and session. The facade also accepts its existing model, policy
and instructions. Reuse the app's synchronous `T Function(Object?)` converter;
do not create duplicate domain models or install a generator to use the helper.
`DecodedModelResponse<T>` exposes `value` plus the original `response`, including
mode, text, metadata, usage and termination. Preserve unknown counts and flags.

Use `response.decodeStructured<T>(decoder: ...)` when an existing final response
is already available, including `CompletionEvent.response`. Do not run the
decoder on partial JSON snapshots or regenerate content merely to convert it.
False, zero and empty roots are valid. Present null is accepted with F06
hasStructuredValue; missing data or explicit incompleteness still fails.

Catch `StructuredDecodingException` separately from `FoundationModelsException`.
It retains the original response, cause and decoder stack; its default string
omits data. Do not log those retained fields automatically. Native diagnostics
may already report completion because model generation succeeded before app
conversion failed; do not rewrite that termination as a model failure.

The facade disposes before decoding; an owned session remains reusable after an
app decoder failure. Conversion runs synchronously on the calling isolate and
is outside native timeouts. Keep it bounded and free of application side effects;
conversion does not grant permission to save, pay, call tools or retry. If a domain
type/error policy is missing and affects the task, ask once and respect prior choices.
See [complete failure contracts](doc/usage.md#decode-final-values-to-dart-types)
and the [typed document example](doc/document-extraction.md#typed-final-document).

Implement `ModelTool` with a unique non-empty name, clear description, supported
object parameter schema, bounded timeout and codec-safe return value. Register
via `SessionOptions.tools`. Native callbacks invoke `call`; do not execute a tool
a second time because a UI event mentions it. Required mode on OS 27 needs at
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

Text/PDF attachment handling extracts text. Image input on iOS/iPadOS 27 or macOS 27 uses local
Vision OCR/classification/barcodes and supplies their textual output. Native
multimodal image Attachment calls remain disabled on every current runtime due
to recorded fatal beta crashes. Do not describe this as visual reasoning or
promise interpretation of charts, diagrams, handwriting or arbitrary files.
PCC language/capability getters also remain disabled. Dynamic profiles, custom
model executors, Core AI, 27.2 typed data entries, arbitrary transcript editing and external
providers are not implemented. Do not infer implementation from an enum case.

## Failure handling and validation

Use [troubleshooting](doc/troubleshooting.md) for the crash ledger and recovery
matrix. Surface actionable unavailable/permission/locale errors. On context
exhaustion shorten supplied data or start a new session. Do not retry guardrail
refusals through another provider. Preserve uncertainty and let the user correct
AI output before saving consequential changes.

For repository changes, read the local AGENTS.md and follow its validation
policy. Keep public API, README, migration notes, example and Apple manifests
aligned. Builds and analysis verify compilation, not runtime/model quality.
Never report a test, device check, entitlement or published release as verified
without evidence from that exact operation and version.

## Maintaining this package's F01–F10 series

Implement only the functionality assigned to the current goal. Each feature
gets a prepared local version and a changelog entry; future rows stay marked
planned. Compatible changes in 1.x use minor versions, while breaking changes
need another major and migration instructions. A delivery requires explicit authorization for its destination;
do not infer publication or deployment permission from an implementation task.

Keep the existing documents coherent rather than adding a guide per feature.
Update Dartdoc for public classes and members with useful contracts, errors,
defaults and limits. Preserve dated release history, but replace obsolete
instructions presented as current behavior. Update examples and Apple manifests
when the API changes, preserving iOS 15/macOS 12 and CocoaPods/SwiftPM.

For these deliveries the user explicitly requires robust library-wide tests.
Use ordinary integration scenarios, invalid inputs and cleanup/failure paths;
fix production behavior when a case fails. Do not exclude executable sources,
add coverage-ignore directives or change behavior only to satisfy test machinery.

Run the complete Dart suite and its existing coverage gate. Native contract tests
compile the production schema/snapshot mappers, history codec, availability monitor and language mapper against Apple
frameworks, inspecting schemas, partial trees, Codable round-trips and genuine
Observation invalidation. Their separate gate covers all five helpers, not every
native service or model inference. Python tests protect the gates and release controls.

For F09, resolve/test the companion in packages/cupertino_fundations_models_generator
with flutter pub get, dart test --coverage coverage, coverage:format_coverage
(--lcov --in coverage --out coverage/lcov.info --report-on lib) and the same
check_coverage.py using the companion as cwd. When generator code or annotated
models change, explicitly regenerate example companions with build_runner before
root tests; do not hand-edit outputs. F10 keeps the F09 generated fixtures.
Core and generator have separate complete line-coverage scopes. Generated example
outputs are compiled/functionally tested, not counted as core library lines.

```sh
flutter test --coverage --reporter expanded
python3 .github/scripts/check_coverage.py
swift test --package-path darwin --enable-code-coverage
python3 .github/scripts/check_schema_coverage.py
python3 -m unittest discover -s .github/scripts/tests -v
```

Full Dart executable-line coverage and full native-helper coverage have distinct scopes.
They do not prove full Swift-service coverage, model response quality, devices,
permissions or PCC entitlement. Do not launch apps, simulators or devices under
this unit-test authorization. Record evidence and the next feature in `context.md`.

For older consumers, the [0.4.0](doc/migration-0.4.0.md) and
[0.3.0](doc/migration-0.3.0.md) migrations remain historical upgrade references.

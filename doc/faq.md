# Questions about local AI on Apple platforms

## What changes in the prepared 1.9.0 API?

F01 adds inclusive numeric bounds, Swift regex patterns and array-length
constraints to manual guided schemas. F02 adds root lists/scalars and required
lists at each nested object. Omitted nested lists keep all fields required;
an empty list makes them optional. F03 imports an explicit JSON Schema subset
alongside manual constructors. F04 converts final data to an app Dart type while
retaining the full original response. F05 adds opt-in native structured snapshots
and per-object property order. F06 adds null, anyOf and local references,
with final presence separate from null. F07 adds native history export and
compatible explicit restoration without historical tool execution. F08 adds local
availability observation and a separate text-language query. Existing unbounded 0.5.0 calls remain
valid. This version is prepared locally and has not been published; use a path
dependency before release. See [usage](usage.md#structured-generation) and the
[F01–F10 release record](../CHANGELOG.md#planned-feature-versions).

F09 supplies a separate optional Dart generator in local 1.9.0. An integrating
coding agent asks once for manual/imported or generated definitions when that
choice is missing, and preserves a prior preference.

The whole-series review also preserves descriptions on every native root and
unnamed nested schema, rejects integer bounds that would round in Double guides
on all definition routes, and enables explicit null with Xcode26.4/Swift6.3 plus
OS26.4. Token counting and OS27 APIs keep their separate SDK guards. See
[constraints](usage.md#structured-generation) and
[platform requirements](apple-platforms.md#runtime-and-build-requirements).

## Can I integrate an app backend or consume text deltas?

F10 in core 1.9.0 offers the optional adapters entry point. FoundationModelsAdapter
owns a fresh session per generate/stream request; adaptEvents borrows an existing
session stream. Both retain raw responses/events and nullable usage. TextUpdate
represents append or replacement, including final reconciliation; strict append
consumers reject revisions explicitly and clean up.

The app owns framework bindings, providers, credentials, consent, telemetry and
history. Genkit/LangChain recipes describe current mapping limits, with no new
runtime dependency, routing or bundled official provider. See
[contracts and framework decisions](usage.md#optional-adapters-and-stream-updates).

## Can I generate schemas and decoders from Dart models?

Yes, in local 1.9.0: add the separate generator as a dev dependency, annotate with
StructuredModel/StructuredField, then explicitly run build_runner. Standalone
*.structured.dart companions provide ClassCodec.schema/decode and ClassPartial.
No part directive, generated Swift or third-party core runtime dependency is added.

The bounded profile supports object models with named generative construction,
primitives, enums, typed lists, annotated nested models and nullable choices.
Unsupported forms fail with source diagnostics. Final decoding checks structure,
not guidance/business truth; partial fields retain presence/completeness/value
without final construction. See [full generation profile](usage.md#optional-dart-generation).

## Can I reuse an existing JSON Schema without generating Dart?

Yes, in local 1.9.0: use `StructuredSchema.fromJsonSchema`. The strict 2020-12
generation subset accepts scalar/null types, anyOf and root-local references,
closed objects, typed array items, string
enums and supported bounds. Every object must explicitly set
`additionalProperties: false`; omitted JSON `required` means no required fields
at that level. Unknown keywords fail with an input path instead of being ignored.
See the [complete profile](usage.md#import-json-schema-definitions).

This is not a general JSON Schema data validator. Remote/recursive references,
oneOf, type lists and format remain unsupported. String `pattern` requires
explicit `allowSwiftPatterns: true` because the native engine uses Swift syntax.
Choose either import or manual constructors according to the app's existing
definitions; both produce the same native contract and add no build step.

## Can I get a Dart model without losing usage and response metadata?

Yes, in local 1.9.0: call `generateStructuredDecoded<T>` on the facade or session
with your synchronous app decoder. `DecodedModelResponse<T>.value` is the domain
value and `.response` is the original `ModelResponse`. For an existing final
response or stream completion, call `response.decodeStructured<T>` directly.

The callback receives the final object/list/scalar; false and empty values stay
valid. Decoder throws use `StructuredDecodingException`, retaining response,
cause and stack; native schema/JSON errors retain their existing codes. Partial
snapshots are not decoded automatically, and no generator or retry is required.
See [decoding and cleanup](usage.md#decode-final-values-to-dart-types).

## Can I show structured fields before generation completes?

Yes, in local 1.9.0: guided streams can use
`GenerationOptions(includeStructuredSnapshots: true)` and read
`TextSnapshotEvent.structuredSnapshot`. Complete leaves and partial containers
form an immutable projection, with observed/complete paths. Incomplete strings
and numbers are withheld rather than repaired. Replace prior state on each event.

Even a snapshot whose root is complete remains nonterminal; use only
`CompletionEvent.response` for final decoding or data review. Set full
`propertyOrder` lists per object, or separate `propertyOrders` definition paths
when importing JSON Schema. Omission keeps alphabetical order. See the
[progress contract](usage.md#structured-snapshots-and-property-order).

## How do I distinguish omission from null?

Required presence and nullable anyOf are independent. Use containsKey on final
maps and ModelResponse.hasStructuredValue at the root. Native null has true
presence; legacy null without that signal stays absent. Null needs OS26.4 and a
compatible SDK; unions/references use OS26. Unavailable support fails instead
of falling back to omission. See [the graph profile](usage.md#null-anyof-and-local-references).

## Can the UI follow local availability without repeated manual checks?

Yes, in local 1.9.0: `watchAvailability` emits initial active readiness and changed
snapshots, using native Observation by default. It pauses work outside foreground
and on subscription pause, then rechecks on resume. Cancel and await the
subscription when its owner finishes. Native observation has no guaranteed event
cadence; explicit `pollingInterval` from one second through five minutes is an
alternative. Neither strategy initiates generation, downloads, Speech or PCC.

A missing plugin/unsupported OS or SDK produces a terminal unavailable snapshot;
bridge failures remain errors. There is no download percentage or automatic retry.
See [watch lifecycle and limits](usage.md#observable-local-availability-and-text-languages).

## Can I query text languages without requiring Speech?

Yes: `getTextModelLanguages(useCase: ...)` returns the selected local variant's
advertised languages and localized `TextModelLanguage` labels. It does not query
Speech or claim its assets are installed. Regional locale fallbacks and model
readiness remain separate checks. `getSupportedLanguages()` keeps the previous
model/Speech intersection for dictation; PCC language queries remain disabled.

## Can I resume an Apple conversation after disposing its session?

Yes, with F07 in local 1.9.0: export an idle session using `exportHistory`, retain
its `SessionHistory.toJson()` in app-owned storage and call `restoreSession` with
the parsed snapshot and current matching tools. It creates a new session without
replaying old tools. Storage, account/thread selection, encryption and retention
belong to the app; nothing is persisted automatically.

The initial profile requires matching platform, exact OS, known SDK, route,
variant, locale and tool registrations. It rejects attachment/data entries,
incomplete structure or pending tools and bounds the archive to 1 MiB/256 entries.
It preserves native Codable context rather than rebuilding text, but cannot promise
identical current model assets. See [complete history contract](usage.md#export-and-restore-session-history).

## What is cupertino_fundations_models?

An independent MIT-licensed Flutter iOS/iPadOS and macOS plugin that bridges Dart to Apple's
native Foundation Models and Speech frameworks. It exposes local language
generation, sessions, streaming, guided structured output and app-defined tools.
Start with the [English tutorial](local-ai-ios.md) or [guía en español](README.es.md).

## Is this an Apple Intelligence Flutter package?

It uses the Foundation Models framework that exposes Apple Intelligence models
to applications. It is not an Apple-maintained or Apple-endorsed package and
does not enable Apple Intelligence on an unsupported device.

## Can I run AI locally on iOS without an API key?

Yes. Select `ModelMode.local` with `CloudPolicy.never`. Local generation uses
Apple's system model rather than an external AI API. Your application's tools
may have their own credentials or network behavior.

## Does local generation work without internet?

It can run offline after the required Apple Intelligence assets are present
and native availability succeeds. Setup and model/Speech asset downloads may
require network. PCC, server Speech and networking tools still need a connection.

## Do I have to bundle or download an LLM myself?

No custom model file is required by this plugin. Apple manages the system
model. The package is not a GGUF, llama.cpp, ONNX or custom-weight runtime.

## Which OS versions are supported?

The plugin deployment targets are iOS 15 and macOS 12. Foundation Models
generation requires iOS/iPadOS 26+ or macOS 26+ and native Apple Intelligence
availability. Some options require OS 27 or a newer build SDK. Read the [compatibility table](../README.md#features-and-compatibility).

## Does it support every iPhone running iOS 26?

No. Hardware eligibility, region, language, enabled settings and model assets
also matter. Call `checkAvailability()` to find out whether the model can run
on the user's device now.

## Does the plugin support macOS, Android or web?

Version 0.5.0 supports macOS alongside iOS/iPadOS. Android and web have no backend.
visionOS and watchOS have no official Flutter target, and tvOS also lacks the
model APIs used here.
See [Apple platforms and Mac setup](apple-platforms.md).

## Can I import this package into a Swift-only app?

No. This is a Flutter package with a native Swift implementation. For an app
written only in Swift, use Apple's Foundation Models framework directly.

## Does this package ship third-party runtime dependencies?

No. Its Dart runtime dependency is Flutter from the SDK; its native bridge uses
Apple platform frameworks. Development tooling is separate from runtime dependencies.

## Does it support CocoaPods and Swift Package Manager?

Yes. Both plugin integrations use the same Swift sources. Your iOS or macOS host still
needs an appropriate build SDK, deployment configuration and native rebuild
after an upgrade.

## Can I request structured JSON rather than prompt for JSON?

Yes. Supply a supported `StructuredSchema` to
`generateStructured()` or `streamStructured()`. A prompt that says “return JSON”
does not enable native schema guidance. Guided output still needs application
validation for facts, amounts, dates and business constraints.

## Are streaming events tokens or text chunks to append?

`TextSnapshotEvent.text` is cumulative. Replace your displayed text with the
latest snapshot. The terminal `CompletionEvent.response` contains the final
result. In a structured stream, partial JSON must not be committed as final data.

## Can I call my own tools from the model?

Yes. Register tools on `SessionOptions`. The app validates arguments and checks
authorization before side effects. A local model does not make its tools
automatically safe or offline. Cancellation does not undo a tool's side effects.

## Is Private Cloud Compute enabled by default?

No. PCC requires its own policy, iOS/iPadOS 27 or macOS 27 runtime, Apple-managed entitlement,
host signing and provisioning, an opt-in flag, availability and appropriate
application consent. Physical PCC verification remains pending.
See [PCC setup](private-cloud-compute.md).

## Does the plugin automatically fall back to a cloud provider?

No. The consuming application owns external API routing, consent, history,
credentials and retries. Failed private prompts are not automatically replayed
to another provider. See [application-owned routing](app-owned-routing.md).

## Does on-device generation also make speech-to-text local?

Speech has a separate privacy setting. `AudioTranscriptionMode.onDevice` is
the local default. `automatic` and `server` can permit Apple Speech networking.
Configure the host usage descriptions and handle denied permissions, missing
assets and unsupported locales. Apple Speech servers are not PCC.

## Does image input provide native multimodal reasoning?

No. The documented iOS/iPadOS 27 and macOS 27 path uses Vision OCR, image classification and
barcodes to provide text context. Native Foundation Models image attachments
remain disabled because of recorded fatal beta crashes. The package therefore
does not offer unrestricted chart, diagram or handwriting understanding.

## Is it suitable for long PDFs or financial decisions?

Use bounded input and validate extracted fields against the source. A model
response is not proof of complete row coverage or correct amounts. The package
does not reconcile financial data, enforce your business rules or persist
transactions. See [document extraction](document-extraction.md).

## Why does the package name use “fundations”?

The published identifier remains `cupertino_fundations_models` to preserve
existing imports. The human-readable framework name is Apple Foundation Models.
Use the exact published identifier in dependencies and Dart imports.

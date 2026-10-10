# Usage reference

The 1.9.0 API supports iOS/iPadOS and macOS with F01 value
constraints, F02 root/required-field choices, F03 JSON Schema subset import and
F04 app-owned final-value decoding with response metadata retained.
F05 adds optional native structured snapshots and per-object property order.
F06 adds explicit null, anyOf and bounded local definitions/references.
F07 adds explicit export and restoration of compatible native session history.
F08 adds local readiness observation and text-model languages independent of Speech.
F09 adds separate optional Dart generation on the same runtime schema/decoder APIs.
F10 adds optional application adapters and revision-safe stream updates.
Version 0.5.0 has the earlier API.
See [platform and host requirements](apple-platforms.md).

This reference describes core 1.9.0. See the [README](../README.md) for
installation and the [0.4.0 migration guide](migration-0.4.0.md) for breaking changes.
Migration from the removed hybrid API is covered in [0.3.0](migration-0.3.0.md).
For Apple cloud, complete [PCC eligibility, entitlement and host setup](private-cloud-compute.md)
before enabling or selecting the cloud model.

## Availability, locales and session ownership

`getCapabilities()` describes the package/runtime feature surface, not whether
Apple Intelligence is enabled now. Call `checkAvailability()` for the intended
mode, cloud policy and locale. Recheck after settings or asset changes, and
handle request errors even after a successful preflight.

`getDiagnostics(localeIdentifier: ...)` reports model language support and
system locale; it cannot read the Siri language. `getSupportedLanguages()` is
specifically the intersection with modern Speech locales. Text-only apps can
use F08 `getTextModelLanguages(useCase: ...)` for localized labels from the selected
on-device text variant, independently of Speech. Advertised languages are not
all accepted regional locales or a readiness guarantee.

`SessionOptions` defines the model, cloud policy, instructions, tools, optional
`localeIdentifier`, content-tagging use case and transcript error policy.
`metadata` is not automatically inserted into the prompt. Local locale preflight
validates support; instructions must still tell the model which language to use.
PCC language preflight is intentionally unavailable while its diagnostic
getters remain disabled.

One-shot facade calls create and dispose their own session. A reused
`FoundationModelSession` keeps native conversation context, and exposes:

| Method | Contract |
| --- | --- |
| `respond(prompt, options: ...)` | One complete text response. |
| `stream(prompt, schema: ..., options: ...)` | Cumulative text snapshots and a terminal result; an optional schema enables guided JSON. Failures may arrive as stream errors. |
| `streamStructured(prompt: ..., schema: ..., options: ...)` | Cumulative guided JSON snapshots and a decoded terminal result. |
| `generateStructured(prompt: ..., schema: ..., options: ...)` | Guided generation with a supported object, array or scalar root. |
| `generateStructuredDecoded<T>(prompt: ..., schema: ..., decoder: ..., options: ...)` | Guided generation followed by explicit app conversion, returning value and original response. |
| `prewarm(promptPrefix: ...)` | Hint to preload resources; not an availability guarantee. |
| `measureTokenBudget(prompt: ..., schema: ..., options: ...)` | Separate component measurements for the actual session model; unavailable fields remain unknown. |
| `countTokens()` | Local transcript token count, iOS/iPadOS 26.4+ or macOS 26.4+ with an Xcode 27 build. |
| `exportHistory()` | Immutable bounded native transcript envelope from an idle session; no storage or tool replay. |
| `cancelActiveRequest()` | Cancel and await the matching native work. |
| `dispose()` | Release the native session; concurrent callers await the same disposal. |

A session is single-flight, including prewarm, transcript token counting and history export.
Separate sessions may operate concurrently. Normal facades share the native
transport so constructing another client does not steal stream/tool callbacks.
Background-isolate and multiple-engine sharing are not promised.

After `contextSizeExceeded`, create a fresh session with a bounded summary or
split an independent task. No automatic history trimming, summarization,
persistence or cross-provider replay occurs.

## Optional adapters and stream updates

F10 is opt-in through `cupertino_fundations_models_adapters.dart`. The regular
entry point and existing sealed SessionEvent cases are unchanged; the optional
barrel also exports core API types. Core runtime dependencies remain Flutter only.
No framework/provider package is installed, no SDK minimum is raised and no new
native backend or hybrid routing is added.

### Owned request adapter and borrowed events

```dart
import 'package:cupertino_fundations_models/cupertino_fundations_models_adapters.dart';

final apple = FoundationModelsAdapter(models: models);
final response = await apple.generate(
  prompt: Prompt.text('Rewrite only the supplied draft.'),
  sessionOptions: SessionOptions(
    mode: ModelMode.local, cloudPolicy: CloudPolicy.never,
    instructions: 'Preserve the supplied meaning.',
  ),
  options: GenerationOptions(maximumResponseTokens: 180),
);
```

`generate` owns a fresh session and awaits disposal for both text and optional
`schema` guidance. Its successful ModelResponse is the original response, including
usedMode, structured presence, usage, metadata and termination. Native/options/
schema errors retain their contracts. Cleanup failure is an error, not success.
SessionOptions is passed explicitly, including useCase, locale, instructions,
tools and optional compatible history. Default route is local/never. PCC remains
an explicit session choice under existing host consent/entitlement rules.

`stream` accepts the same prompt/schema/session/options and optional
`allowReplacements`, creating a **cold single-subscription owned request**:

```dart
var text = '';
final subscription = apple.stream(prompt: Prompt.text('Summarize supplied text.')).listen(
  (frame) {
    if (frame.textUpdate case final update?) text = update.applyTo(text);
    switch (frame.original) {
      case TextSnapshotEvent(:final structuredSnapshot?): showStructuredProgress(structuredSnapshot);
      case CompletionEvent(:final response): useFinalResponse(response);
      case FailureEvent(:final code, :final details): showNativeFailure(code, details);
      case ToolCallEvent(): observeAlreadyOwnedToolCall(frame.original);
      default: break;
    }
  },
  onError: showRequestError,
);
await subscription.cancel();
```

Work begins on listen. Cancel awaits a pending session-creation acknowledgement,
cancels active native work and disposes only the owned session. Early cancel never
starts generation after creation. Terminal delivery waits for source cleanup and
owned disposal; cancelling while cleanup is pending suppresses late success.
Startup/source/timeout/cancellation/cleanup failures remain errors. A stream that
ends without terminal data fails instead of generating a fictitious completion.

For an app-owned reused session, call `session.stream(...).adaptEvents()`. This
adapts one request and cancels only that subscription; it **does not dispose the
borrowed session**. The caller retains session/history ownership. Each adapter
stream has its own text baseline and request context. Different nonempty request
IDs fail with invalidRequest/adapterStage:mixedRequests; empty legacy IDs remain
unknown and unknown events are preserved without guessing their semantics.

Pause propagates to source **delivery**. Existing native generation and deadline
semantics still apply; pausing does not suspend Apple inference or timeouts. If
paused during async creation, delivery is paused once the source attaches. Always
handle stream errors and await cancellation before reusing/releasing ownership.

### Lossless text and original metadata

`AdaptedSessionEvent.original` retains the exact SessionEvent instance. Its
`textUpdate` is present for TextSnapshotEvent and final CompletionEvent text;
`isTerminal` means completion or native failure, not proven content quality.
Final text is reconciled even if it differs from the last intermediate snapshot.
Tools/unknown events have no text operation and are not dropped. Native structured
snapshots remain projections of their original events; do not decode them as final.
Observed ToolCallEvent does not invoke a second callback: core already owns tools.

`TextSnapshotReducer.next(snapshot)` produces `TextUpdate`:

| Kind | Meaning |
| --- | --- |
| append | The prior snapshot is an unchanged prefix; content is its suffix, possibly empty. |
| replace | Revision, shortening, clearing or unsafe UTF-16 surrogate boundary; content is the full new text. |

`TextUpdate.fullText` is authoritative. `applyTo(previous)` applies replacement
or verifies the append baseline; a stale buffer throws StateError rather than
silently corrupting text. No Unicode normalization, JSON repair or slicing by
length alone is performed. Replace/reduce structured snapshots separately.

Append-only destinations can use `allowReplacements: false` on stream/adaptEvents.
A revision fails with unsupportedCapability/adapterStage:textRevision and awaits
cleanup. It does not retry, route elsewhere, drop the revision or emit an incorrect
delta. If the destination cannot represent replacement, choose one-shot/final
output or a caller-supported replacement protocol explicitly.

Original response/usage/termination remain available; null counters stay unknown,
not zero. Completion alone does not invent stop/max-token reasons or model quality.
Retain the complete response when mapping a framework result, and document any
intentionally text-only application operation instead of claiming full-provider parity.

### Ecosystem recipes and proof boundaries

The provided [AppTextBackend/AppleTextBackend example](../example/lib/apple_text_backend.dart)
shows an application interface, with Apple ownership and raw results intact.
A consuming app implements the framework-specific binding and chooses its policy;
this delivery includes no registered Genkit plugin or LangChain ChatModel subclass.
No framework package, provider/key, telemetry service or publication is configured.

| Destination | Mapping decision |
| --- | --- |
| App backend interface | Delegate native generation/stream to FoundationModelsAdapter, retain ModelResponse/AdaptedSessionEvent, keep provider selection outside it. |
| Genkit flow/model binding | Declare outputSchema versus streamSchema separately; map native final/partial outputs without prompt-only fallback. Wire Genkit cancellation token to owned cancellation; configure telemetry consent separately. |
| LangChain ChatModel/LLM binding | Negotiate prompt/history/tools/schema options explicitly. ChatResult concatenation is append-oriented: use strict append policy or supported replacement, preserving native response/nullable usage in the app result. |

As inspected on 2026-10-09, Genkit 1.0.0 requires Dart ^3.12, beyond this core's
3.11 minimum. LangChain 0.9.0 allows Dart >=3.9 <4, but its presence does not supply
an Apple backend. A caller already using a compatible framework can bind this API;
do not upgrade/install it as a side effect of local integration.

Use only a deliberately bounded, consented input. Do not flatten an entire
framework conversation into Prompt.text, automatically export/replay session
history, silently upload local content after an error, or route to a provider
without permission. Tool schemas and final response schemas are distinct.
If a framework contract exceeds the F03 import profile, reject it or let the app
choose another explicit mode; do not strip keywords or replace native guidance
with a JSON-only prompt. Partial tool arguments are not authorized execution.

Genkit chunks expose fragment/accumulated text and optional output; its cancellation
is cooperative and provider-specific, so cancelling a Dart subscription is not
by itself a mapped CancellationController token. LangChain chunks merge/append
text and tool blocks; it has no universal native-snapshot replacement contract or
cross-provider cancellation token. Preserve unknown usage counters and unsupported
features. Core cancellation still cannot undo side effects of app tool functions.

Sources: [Genkit package/cancellation](https://pub.dev/packages/genkit),
[Genkit model APIs](https://genkit.dev/docs/dart/models/),
[Genkit tools](https://genkit.dev/docs/dart/tool-calling/),
[LangChain API](https://pub.dev/documentation/langchain/latest/langchain/).
The Apple adapter and app-interface example are tested here; those external
framework bindings/providers are documented contracts, not executed integrations.
See [application-owned routing recipes](app-owned-routing.md#optional-framework-bindings).

## Optional Dart generation

F09 is a separate `cupertino_fundations_models_generator` development package,
versioned separately as **1.8.0**, compatible with core **1.9.0**. The core workflow does not publish it;
published core 0.5.0 lacks these annotations/readers. Core runtime dependencies
remain Flutter only. The generator depends on analyzer/build/source_gen for
source resolution and emission; consumers add it only if they choose generation.

### Choose a definition route

| Route | Appropriate use |
| --- | --- |
| Manual `StructuredSchema`/`SchemaProperty` | A few definitions or contracts outside the generator profile; no build step. |
| `StructuredSchema.fromJsonSchema` | Existing compatible schema data with its explicit subset/pattern choices; no Dart generation. |
| Annotated models and generated companions | Many object models whose schemas, decoders and display projections should follow class declarations. Requires development tooling. |

An integrating agent asks once, only if no preference exists and the choice affects
the implementation: “Would you prefer manual/schema-data definitions, or generated
schemas and decoders from your Dart classes?” Explain the build step and profile,
then respect the chosen route. A previous choice is not asked again. Do not install
build tools or migrate existing models merely because they are available.

### Local setup and explicit generation

In a consuming Flutter application's pubspec, use local paths/overrides for both
prepared packages (replace the paths with this checkout's actual location):

```yaml
dependencies:
  cupertino_fundations_models:
    path: /path/to/cupertino_fundations_models-f01
dev_dependencies:
  build_runner: ^2.16.2
  cupertino_fundations_models_generator: ^1.8.0
dependency_overrides:
  cupertino_fundations_models:
    path: /path/to/cupertino_fundations_models-f01
  cupertino_fundations_models_generator:
    path: /path/to/cupertino_fundations_models-f01/packages/cupertino_fundations_models_generator
```

After the consumer chooses generation, resolve its development dependencies with
`flutter pub get`, then explicitly run:

```sh
dart run build_runner build
```

The command creates standalone `*.structured.dart` libraries alongside inputs;
it does not change source models, invoke inference, generate Swift or build an
Apple/Android app. Do not hand-edit companions. Existing build_runner conflicting-
output handling still applies; review unexpected conflicts before replacement.
The checked-in example uses `pubspec_overrides.yaml` for the same local setup.
Remove local overrides only when using both actually published matching releases.
Core and companion require separate publication; the current core release workflow
does not publish the generator automatically.

### Annotation and output API

```dart
import 'package:cupertino_fundations_models/cupertino_fundations_models_annotations.dart';

@StructuredModel(name: 'Contact', propertyOrder: ['name', 'email'])
final class Contact {
  const Contact({required this.name, this.email});
  @StructuredField(description: 'Supplied name')
  final String name;
  final String? email;
}
```

`StructuredModel` supports `name`, `description`, `propertyOrder`, `explicitNulls`
and `constructor`. Empty constructor means unnamed; a public named generative
constructor can be selected. `StructuredField` supports JSON `name`, `description`,
`required`, numeric `minimum`/`maximum`, Swift `pattern`, and array
`minItems`/`maxItems`/`exactItems`. Apply it to declared instance fields, not static
members, getters or constructor parameters. Patterns retain native Swift semantics
and validation; no Dart regex substitution occurs.

Import the generated file, then use existing runtime APIs:

```dart
import 'contact.dart';
import 'contact.structured.dart';

final result = await models.generateStructuredDecoded<Contact>(
  prompt: Prompt.text('Extract supplied contact details.'),
  schema: ContactCodec.schema,
  decoder: ContactCodec.decode,
);
final domain = result.value;
final originalResponse = result.response;
```

`ClassCodec.schema` is a const object-root `StructuredSchema`, using the same
`SchemaProperty` constructors as the manual route. The generator inlines nested
object schemas, preserves guides/order and explicitly supplies required lists;
it does not create another schema engine or per-model bridge. Property order
also determines the ordering of required names when supplied. Otherwise ordering
is deterministic/alphabetical. Same-package imports are relative and other package
imports retain their URIs, independent of source import prefixes/type aliases.

`ClassCodec.decode(Object?, {path: '#'})` checks closed object fields, required
presence, allowed null, exact scalar types, enum names and list elements, then
calls the selected app constructor. Lists are immutable. No string/number coercion,
rounding, enum fallback, default-fact synthesis or arithmetic is performed.
Optional nullable fields omitted from data are passed as null; constructor defaults
are not used to invent absent values. Constructors remain application code and may
perform their own validation/effects; choose appropriate domain constructors.

Native guidance bounds/patterns and business truth are **not data validators**.
Generated conversion does not verify source coverage, currencies, dates, values
against guidance, or permission to write. Wrong structure throws `FormatException`
with a JSON Pointer and expected shape, without embedding source data. Using F04
retains the original response/cause/stack in `StructuredDecodingException`;
native/schema failures retain their existing error contracts.

### Presence, null and partial views

Non-nullable fields are required by default; nullable object fields are optional.
`StructuredField(required: true)` can require a nullable field's presence.
`StructuredModel(explicitNulls: true)` separately permits present null on nullable
properties using F06 anyOf/null, requiring native OS 26.4 support. Default nullable
properties allow omission, not explicit null. Nullable list elements always use
explicit null to preserve their indices and therefore need OS 26.4. Neither route
silently downgrades null to absence.

For a guided stream, explicitly request F05 `includeStructuredSnapshots: true`:

```dart
if (event case TextSnapshotEvent(:final structuredSnapshot?)) {
  final partial = ContactPartial.fromSnapshot(structuredSnapshot);
  final name = partial.name;
  if (name.hasValue) showName(name.value);
}
```

`ClassPartial` views the original snapshot at an optional object `path`; `snapshot`
retains the complete F05 projection and `isComplete` checks that object path.
Every generated getter returns `StructuredPartialField<T>` with `path`,
`isPresent`, `isComplete`, `hasValue` and `value`. Missing/incomplete primitive
leaves have no value; false, zero and empty strings remain values. Present null
has `hasValue: true` and null value, with presence/completeness retained. Nested
objects become typed `ChildPartial` views; arrays preserve a safe contiguous
prefix and nullable indices. Lists and source snapshots remain immutable.

Replace the view when a new snapshot arrives. Even `isComplete: true` remains
nonterminal; only completion uses the final decoder. The view does not instantiate
final domain models, run constructor business logic or authorize tool/storage
operations. Wrong typed projections fail structurally; incomplete data is withheld.
`StructuredValueReader` provides the shared structural primitives and pointer
handling; it is also usable by explicit app decoders without the generator.

### Initial generation profile and limits

- One annotated public concrete class per source library under `lib/`, with 1–128
  public final, non-late fields and matching named parameters in a public generative
  constructor. No generic/inherited/mixin fields, factories or private fields.
  Computed getters/static fields are not output; guides on those members fail.
- Primitive `String`, `int`, `double`, `num`, `bool`; public enums by exact Dart
  names; typed lists; annotated nested classes in the same/another library;
  nullable types. Root output remains object; manual/import routes cover other roots.
- JSON names must be nonempty/distinct, and propertyOrder a full permutation.
  Dart field names `snapshot` and `isComplete` are reserved for partial metadata.
  Enum wire aliases, maps, dynamic/Object, functions, records, DateTime and extension
  types are unsupported; keep a manual/imported schema and app decoder for those.
- Acyclic schema depth 16; nullable/anyOf expansion at most 512 nodes. Repeated
  nested models are inlined. Invalid/incompatible guides, fractional/oversized
  integer bounds and native Double bound precision loss fail before generation.
- Decoder integers are signed 64-bit; numbers finite. Double fields reject integer
  inputs whose conversion loses precision instead of silently changing them.

See the [annotated document example](../example/lib/generated_document.dart),
[its generated companion](../example/lib/generated_document.structured.dart) and
[document integration](document-extraction.md#optional-generated-document-models).
Tooling contracts: [source_gen LibraryBuilder](https://pub.dev/documentation/source_gen/latest/source_gen/LibraryBuilder-class.html)
and [Dart build_runner](https://dart.dev/tools/build_runner). These are development
APIs, not a runtime backend or new platform support.

## Observable local availability and text languages

F08 provides an optional local stream for readiness UI, separately from session
ownership and generation. Subscribing does not create a session, prewarm, initiate
model downloads, request Speech permissions or select/query PCC:

```dart
final subscription = models.watchAvailability(
  useCase: FoundationModelsUseCase.general,
  localeIdentifier: 'es_CO',
).listen(
  (snapshot) => updateReadiness(snapshot),
  onError: (Object error) => showAvailabilityError(error),
);
await subscription.cancel();
```

The stream is cold and single-subscription. Native work begins on listen when
foreground-eligible. Each active subscription emits its initial snapshot, then
only structural changes in the entire `ModelAvailability`, including reason,
context and details. Snapshot maps/lists are frozen and duplicates are suppressed
independently of map-key order. Separate watches have separate IDs, variants,
locales and cleanup. This does not occupy a model session's generation slot.

### Observation, explicit polling and lifecycle

The default uses Swift Observation on the selected `SystemLanguageModel` instance.
Apple exposes an observable model and demonstrates availability-dependent SwiftUI;
it does not specify a guaranteed readiness-event cadence. This API reports observed
invalidations and snapshots, not a promised download-completion event or progress
percentage. Assets may remain unavailable. No invisible polling fallback occurs.

For explicit polling, pass `pollingInterval: const Duration(seconds: 15)`. Any
interval from **one second through five minutes**, inclusive, is accepted;
out-of-range values throw `ArgumentError` before subscription. Polling replaces
Observation, checks immediately and then periodically, and suppresses duplicates.
Scheduling, OS suspension and bridge delivery can delay updates; the interval is
not a latency guarantee. The subscription issues no asset-install request even
when system-managed downloads independently change readiness.

Both strategies stop native work when the subscription is paused and recheck when
resumed. By default, all Flutter lifecycle states outside `resumed` suspend work,
including inactive, hidden, paused and detached. A new native watcher rechecks on
foreground; identical snapshots remain suppressed across this restart. A watch
created while backgrounded waits for foreground before its initial snapshot.
Failures and terminal events immediately invalidate callbacks and start idempotent
cleanup; late events cannot reopen a closed watch. Explicit cancellation still
reports cleanup errors while shutdown is pending.
In-flight callbacks from older watches are ignored. Ordinary Dart subscription
buffering still applies to events queued before pause; readiness is always a
snapshot, not permission to bypass request errors.

Automatic foreground handling requires an initialized `WidgetsBinding` (normally
provided by `runApp`/`WidgetsFlutterBinding.ensureInitialized`). Headless or
application-managed hosts can choose `pauseWhenBackgrounded: false` and own
background policy themselves; subscription pause and awaited cancellation still
stop work. The binding follows Flutter's engine lifecycle, not an individual
window or background isolate. Await cancellation before replacing ownership;
cleanup/start failures remain errors. The example uses epochs to discard late
checks after a language change or screen disposal.

The watcher supports only **on-device** `.general`/`.contentTagging`, matching
`SessionOptions.useCase`. It has no cloud policy because it does not enter PCC.
For PCC, keep the existing explicit `checkAvailability` and host/policy flow.
Availability still can change between a snapshot and generation; keep typed
request recovery. The existing local `checkAvailability` queries the general model.

### Independent text-model languages

```dart
final languages = await models.getTextModelLanguages(
  useCase: FoundationModelsUseCase.contentTagging,
);
for (final language in languages) {
  useLanguageLabel(language.identifier, language.displayName, language.nativeDisplayName);
}
```

The query reads the selected local model's `Set<Locale.Language>`, sorted by native
minimal identifier. `TextModelLanguage` exposes `identifier`, `languageCode`,
`displayName` and `nativeDisplayName`, plus `fromMap`/`toMap`. The returned list is
unmodifiable. Labels use host/native locales with identifier fallbacks; script
identifiers remain present. There is no transcription asset flag, Speech query,
permission prompt or asset download. On an older/unavailable SDK/runtime the
native query returns an empty list; inspect capabilities/readiness separately.

The advertised language list is not the set of every supported regional locale.
Native `supportsLocale` can accept regional fallbacks, so use a locale-specific
availability check/watch and the same locale at session creation. Text-language
support does not imply Speech support or model readiness. The existing
`getSupportedLanguages()` continues to return the model/modern-Speech intersection
and Speech asset state; the chat keeps this choice because it offers dictation.
PCC language getters remain disabled; this method does not query them.

### Unsupported hosts and errors

A missing Apple plugin produces one `unsupportedPlatform`/unavailable snapshot and
then closes the watch. Unsupported native OS or build SDK produces its existing
unavailable status as an initial terminal snapshot. Lack of the optional feature
on an older custom adapter produces `unsupportedCapability` rather than inventing
host incompatibility. Adapters remain source-compatible and can implement the
optional `FoundationModelsAvailabilityPlatform` contract.

Native start/stop errors remain typed `FoundationModelsException`; malformed new
language/event payloads use `parsingFailure`. A watch fails and cleans up rather
than reporting success after a transport error. Cancel during start waits for its
acknowledgement before stopping native work; cancellation failures are surfaced.
No automatic retry, model routing or inference is added. Capability `details`
exposes `availabilityObservation`, `availabilityPolling` and `textModelLanguages`
for SDK/runtime support, separately from current readiness.

References: Apple's [observable SystemLanguageModel](https://developer.apple.com/documentation/foundationmodels/systemlanguagemodel),
[Observation](https://developer.apple.com/documentation/observation) and
[language/locale support](https://developer.apple.com/documentation/foundationmodels/supporting-languages-and-locales-with-foundation-models).

## Export and restore session history

F07 is optional. Ordinary sessions still hold context only until disposal; facade
one-shot calls do not expose their owned session. Export only when all generation,
stream cancellation and tool work have completed:

```dart
final history = await session.exportHistory();
final encoded = history.toJson();
await session.dispose();
final restored = await models.restoreSession(
  history: SessionHistory.fromJson(encoded),
  tools: currentTools,
  cloudPolicy: CloudPolicy.never,
);
try {
  final answer = await restored.respond(Prompt.text('Continue from the last turn.'));
} finally {
  await restored.dispose();
}
```

This example keeps JSON in memory. Export/serialization never writes files, logs
content, uploads it or associates it with an account. The consuming app selects the
correct user and conversation and owns storage access, encryption, retention,
deletion and any permitted transfer. A snapshot includes prompts, tool arguments
and outputs, instructions and possibly reasoning; treat all of it as sensitive.
No redacted substitute is used for a supposedly exact restoration.

`SessionHistory` is immutable. Its version-1 envelope contains UTC `createdAt`,
actual `mode`, `useCase`, original app instructions/locale, environment, tool
registrations, typed entries and `nativeArchive`. `SessionHistoryEntry` exposes
entry ID/kind, ordered segments, tool calls/names and response asset IDs.
`SessionHistorySegment` exposes text or complete structured JSON/schema name;
`SessionHistoryToolCall` exposes ID/name/arguments JSON. The **SDK Codable archive**
is authoritative and additionally preserves generation options, response formats,
native tool definitions and supported metadata/signatures. Descriptors are an
inspection view, not an editable replay format; native restore compares them to
the decoded archive. Editing, truncating or selecting a subset is not supported.

### Compatibility and accepted history

| Contract | Initial F07 profile |
| --- | --- |
| Native API | Local iOS/iPadOS 26+ and macOS 26+; PCC still needs OS 27+, entitlement and explicit host opt-in. |
| Build and host | Same platform, exact OS-version string and SDK identifier. Unknown SDK identifiers cannot restore; OS/SDK migrations are not promised. |
| Session context | Same actual route, variant and locale; saved instructions are inherited and cannot be overridden. |
| Tools | Same ordered registrations, names, descriptions, parameters and timeout values. Supply current app callbacks; executable code/its identity is not serialized. |
| Entries | Instructions, prompt, response, completed toolCalls/toolOutput, and reasoning on supported OS 27. |
| Segments | Text and complete structure; native options/formats, IDs, response asset IDs and supported reasoning signatures/metadata remain in the archive. |
| Rejected content | Attachments, binary/data or unknown entries/segments, partial structures/arguments, duplicate/empty entry IDs, duplicate pending calls, orphan outputs and unfinished tool calls. |
| Bounds | At most 256 entries and 1 MiB of UTF-8 native archive. The outer JSON envelope is larger; apps must impose their own storage/input bounds. |

The archive preserves response asset IDs where Apple supplies them, but the SDK
does not expose a pre-generation current model-asset version. Equal OS/SDK does
not guarantee the installed model assets or future answer are identical. No
cross-provider, cross-platform or arbitrary future-SDK interchange is claimed.
See Apple's [Transcript documentation](https://developer.apple.com/documentation/foundationmodels/transcript)
and [restoration initializer](https://developer.apple.com/documentation/foundationmodels/languagemodelsession/init(model:tools:transcript:)).

`restoreSession` creates a new session; it does not mutate the old session or
invoke old tool callbacks. New prompts can call the current tools normally, so
retain their ordinary authorization rules. Cloud permission is not restored:
PCC snapshots require the caller to supply a permitted `cloudPolicy` explicitly.
Request metadata and transcript error policy are also chosen for the new session.

The lower-level alternative is `models.createSession(options: SessionOptions(
history: history, mode: history.mode, useCase: history.useCase,
localeIdentifier: history.localeIdentifier, tools: currentTools))`. Include an
explicit permitted cloud policy for PCC and leave instructions null. The default
`ModelMode.automatic` does not match the saved actual route. Existing custom
platform adapters remain source-compatible; history needs the optional
`FoundationModelsHistoryPlatform` contract. Native capability details expose
`sessionHistory` for the runtime surface, separately from model readiness.

Malformed Dart envelopes use `invalidRequest`; option mismatches are
`ArgumentError` before transport. Native compatibility/malformed-envelope failures
use `invalidRequest`; unsupported or incomplete native content uses
`unsupportedTranscriptContent`. An older platform adapter returns
`unsupportedCapability`. Export participates in single-flight admission, rejects
disposed/busy sessions and releases admission after failure. Disposal during export
prevents returning a successful stale snapshot. Export does not perform inference;
an accepted snapshot does not guarantee future model availability or token capacity.

## Generation options and budgets

- `maximumResponseTokens`: positive answer budget. The model can stop sooner.
- `samplingMode`: greedy, random top-K, or probability-threshold sampling.
  Top-K must be positive; probability and finite temperature are in `[0, 1]`.
- `samplingSeed`: optional nonnegative seed. Older SDK paths may lack seeding;
  repeatability across OS/model versions is not guaranteed.
- `maximumToolCalls`: 1–128 calls per request, default 16. A budget breach fails
  the request; it does not guarantee the model produced an answer.
- `toolCallingMode`: `allowed` by default. `required` and `disallowed` need iOS/iPadOS 27 or macOS
  27 and a compatible SDK. Required mode needs registered tools.
- `reasoningLevel`: automatic by default; explicit/custom values need iOS/iPadOS 27 or macOS 27
  and support from the selected model.
- `includeSchemaInPrompt`: uses the older guided-generation option on iOS/iPadOS 26 or macOS 26
  and `ContextOptions` on OS 27.
- `includeStructuredSnapshots`: false by default; adds native structured
  projections to guided text snapshot events. Text-only streams and one-shot
  generation reject it. Budget measurement may reuse these stream options.
- `cloudPolicy`: nullable request restriction. Null inherits session selection;
  `never` rejects PCC. Other values cannot change the selected model.
- `timeout`: positive duration, default 60 seconds. Existing fallback: a
  deadline for one-shot calls, or inactivity between stream events.
- `firstResponseTimeout`: optional stream deadline until the first text/JSON
  snapshot or terminal response. Tool/unknown events do not extend it. Until
  that result arrives, this replaces the initial inactivity deadline.
- `idleTimeout`: optional inactivity limit after the first result, reset by
  stream events. Without an explicit first-response deadline it applies from
  the start. It falls back to `timeout`.
- `totalTimeout`: optional absolute generation duration. For a stream it runs
  independently of events; for one-shot calls it replaces `timeout`.
- First-response and idle settings apply only to streaming. All supplied
  durations must be positive. Timers start on subscription; pausing a consumer
  does not suspend native generation or its deadlines. OS suspension can delay
  Dart timers, so these options do not promise wall-clock enforcement while the
  process is suspended.

Timeout errors carry `termination.status == GenerationStatus.timedOut` and
`termination.timeoutPhase`. Native cancellation and subscription cleanup are
awaited before the session can be reused; that cleanup may outlast the deadline.
Cancellation failures require disposal and a fresh session. Wait for stream
completion/cancellation cleanup before another request, even after an error event.

### Token measurements and actual usage

`models.countTokens(prompt)` counts the constructed prompt with the default local
model, including extracted attachment text. `session.countTokens()` counts its
local transcript. Prefer the session budget API for model-specific components:

```dart
final budget = await session.measureTokenBudget(
  prompt: prompt,
  schema: schema,
  options: const GenerationOptions(maximumResponseTokens: 1200),
);
final measurement = budget.components['prompt'];
if (measurement?.precision == TokenPrecision.exact) {
  print(measurement?.count);
}
```

`TokenBudget.components` has `prompt`, `instructions`, `tools`, `schema` and
`transcript`. On supported local iOS/iPadOS 26.4+ or macOS 26.4+ SDK/runtime paths, `exact` means the
native tokenizer's count for that particular component and session model.
`estimated` is reserved for explicitly labeled estimates; this implementation
never substitutes an estimate. `unavailable` supplies no count and a reason.
PCC has no exposed matching token-count API in the inspected SDK, so its
measurements are unavailable. Older runtimes return unavailable rather than
fabricating zero. An absent local component can have an exact zero count.

These scopes may overlap: transcript entries can already contain instructions
and tool context. Do not sum them as an exact serialized-request count. The
framework does not expose an exact complete request count through this API.
`maximumResponseTokens` echoes the requested reservation, not observed output.
`modelIdentifier` identifies the selected mode/use case, not an immutable Apple
model revision. Local `contextWindowTokens` uses the selected model's native
context size; PCC remains null. Do not
assume local and PCC have the same capacity. Measurements do not mutate the
transcript or reserve capacity, and token counting itself has no generation
timeout. It occupies the session until the native measurement finishes.

On iOS/iPadOS 27 or macOS 27, `ModelResponse.usage` may contain actual native input, cached-input,
output, reasoning and total token counts. Earlier systems return null. Each
counter is also nullable when absent, never synthesized as zero. Cached and
reasoning counts are subcategories, not extra tokens to add to `totalTokenCount`.
`usedMode` identifies the selected Apple backend. Neither a request estimate
nor an observed token count alone establishes the cause of truncation.

### Result and termination

`ModelResponse.termination` describes operation completion; its `reason` remains
`unknown` when Apple supplies no explicit stop reason. `nativeReason` stays null
unless actually supplied; it is not inferred from text length or usage.
`structuredContentComplete` reports the native completeness flag where provided;
structured streaming additionally requires complete, decodable final JSON.
This does not prove that every source row or correct amount was extracted.

`FoundationModelsException.termination` and `FailureEvent.termination` identify
failure, cancellation, timeout phase, context overflow, refusal or invalid
structure through the package's typed error mapping. Error categories do not
claim a native stop reason. A stream that closes without a terminal event now
fails with `nativeFailure` and `details['streamClosedWithoutResult'] == true`.
[Apple documents](https://developer.apple.com/documentation/foundationmodels/generationoptions/maximumresponsetokens)
that hitting an output limit can end generation early without an error; a
successful completion therefore does not establish a natural stopping point.

### Request diagnostics

```dart
final options = GenerationOptions(
  firstResponseTimeout: const Duration(seconds: 45),
  idleTimeout: const Duration(seconds: 20),
  totalTimeout: const Duration(minutes: 3),
  diagnostics: GenerationDiagnostics(
    captureOutput: false,
    onEvent: (event) {
      updateRequestStatus(event.requestId, event.stage, event.elapsed);
    },
  ),
);
```

`updateRequestStatus` is a host callback. Events contain a package request ID,
optional native stream ID, session ID, effective mode, OS/model metadata,
host SDK identifier when available,
package version, elapsed time, first-result latency, terminal usage and typed
termination when available. An unknown native model revision/SDK version is not
invented. Events describe accepted generation requests; preflight, token
measurement and invalid options are not generation telemetry.

Callbacks are synchronous, exceptions are isolated, and they must remain small.
There is no automatic console logging, persistence or transmission. Prompts,
schemas, tool arguments/results, error messages and hidden reasoning are not
captured. `captureOutput: true` separately opts into the exact string delivered
by the framework for each snapshot/final response, not remote network bytes.
`maximumOutputCharacters` defaults to 65536 UTF-16 code units per event. Larger
strings are omitted with `outputOmitted: true`; no prefix is passed off as exact.
The callback recipient controls retention, redaction and export. Do not enable
capture by default for sensitive documents. Events are not buffered for replay.

## Structured generation

```dart
final response = await models.generateStructured(
  prompt: const Prompt.text('The appointment is with Morgan on Friday.'),
  schema: const StructuredSchema.object(
    name: 'Appointment',
    properties: <String, SchemaProperty>{
      'person': SchemaProperty.string(),
      'day': SchemaProperty.string(),
    },
    requiredProperties: <String>['person', 'day'],
  ),
  mode: ModelMode.local,
  cloudPolicy: CloudPolicy.never,
  options: const GenerationOptions(maximumResponseTokens: 120),
);
final value = response.structuredValue;
```

Choose `StructuredSchema.object`, `.array`, `.string`, `.integer`, `.number`
or `.boolean` for the root. Array roots use a `SchemaProperty` item schema,
including nested objects and arrays. Scalars and root arrays accept their
corresponding F01 constraints. `schema.type` identifies the root; its legacy
`properties`/`requiredProperties` fields are empty and unused for non-object roots.

Root-object `requiredProperties` still defaults to an empty list. Nested
`SchemaProperty.object(requiredProperties: ...)` has three explicit meanings:

| Nested value | Native behavior |
| --- | --- |
| Omitted or null | Every declared child is required, preserving earlier releases. |
| `[]` | Every child may be omitted. |
| A list of declared names | Only the listed children are required. |

Each object controls its own children, including objects inside root arrays.
Duplicate/undeclared nested required names, or a required list on another type,
throw `ArgumentError` during serialization before request admission. Required
fields must be declared. Optional absence does not add explicit null or unions.
The native tool schema also accepts the `required` and string `enum` aliases.
The prepared 1.9.0 API adds the following optional native constraints:

| Property | Options | Meaning |
| --- | --- | --- |
| `SchemaProperty.integer` | `minimum`, `maximum` | Inclusive whole-integer bounds. |
| `SchemaProperty.number` | `minimum`, `maximum` | Inclusive finite numeric bounds; integer limits must be exactly representable as native Double. |
| `SchemaProperty.string` | `pattern`, existing `enumValues` | Swift regular-expression pattern and optional allowed string values; both apply when combined. |
| `SchemaProperty.array` | `minItems`, `maxItems` | Inclusive non-negative element-count range. |
| `SchemaProperty.array` | `exactItems` | One non-negative length, serialized as equal minimum and maximum counts. |

Omit a constraint to keep the previous native behavior. A lower bound may be
negative, bounds may be equal, and zero array length is valid. Numeric bounds
must be finite and ordered. Integer properties cannot use fractional bounds.
Number properties reject integer limits that would round in native Double
guides, including at the root and in nested/manual definitions. This matches
the JSON import and generated routes. Exactly representable large limits remain
valid; integer schemas retain their full signed 64-bit range. Rejection is an
ArgumentError during Dart serialization or a native invalidRequest with schemaPath.
An exact count cannot be combined with either array range bound, even if the
numbers agree. The generic `SchemaProperty(type: ...)` constructor applies the
same validation and rejects constraints on incompatible types.

```dart
const triageSchema = StructuredSchema.object(
  name: 'SupportTriage',
  requiredProperties: ['severity', 'actions'],
  properties: {
    'severity': SchemaProperty.integer(minimum: 1, maximum: 5),
    'ticket': SchemaProperty.string(pattern: r'^SUP-[0-9]{4}$'),
    'confidence': SchemaProperty.number(minimum: 0, maximum: 1),
    'actions': SchemaProperty.array(
      items: SchemaProperty.string(),
      exactItems: 3,
    ),
  },
);
```

Here a ticket can be omitted if it is absent from the input. Three suggested
actions are a generation task; an exact count should not force an extractor
to invent missing source records. Choose required fields and missing-value
behavior from the app's domain rather than imposing a matching value on absent
data. A model-generated confidence number is not a calibrated probability.

Constraints use native `GenerationGuide` and `DynamicGenerationSchema` APIs on
iOS/iPadOS 26 and macOS 26. They apply to nested properties and tool argument
schemas, to one-shot output and to guided streams. Model availability still
applies; a native model can reject an unsupported guide. PCC retains its
separate OS 27 and signing/policy requirements.

Patterns are compiled by Swift before generation, not by Dart `RegExp`.
Use anchors when the entire string should match. Swift may normalize the
pattern in its encoded schema. A pattern valid in Dart or JavaScript is not
automatically valid in Swift; an invalid pattern fails with `invalidRequest`
and a path such as `#/properties/ticket/pattern` instead of being ignored.

Invalid Dart bounds/counts throw `ArgumentError` during serialization, including
in release builds with assertions disabled. Session requests validate them
before admission, so an invalid stream cannot cancel another request or poison
an idle session. Native wire validation also rejects booleans, strings and
non-finite values used as numeric bounds, and returns a constraint path.

F06 supports explicit null, anyOf and acyclic local definitions/references.
Other unsupported keywords remain rejected rather than silently ignored.
Manual constructors and the importer use the
same normalized contract and native mapper. F09 now offers a separate optional Dart generator on those runtime APIs.
Nesting is limited to 16 levels and
objects to 128 properties. Internal type names are derived uniquely from
their full schema paths; repeated nested property names do not share types.
Mapping failures expose `FoundationModelsException.details['schemaPath']`
and a path-bearing message. Native framework errors may lack a property path.

`structuredValue` is typed `Object?`: root objects decode to maps, arrays to lists
and scalars to their values. `false`, zero, `''` and `[]` are legitimate final
data, not absence or failure. `response.text` retains the original JSON, including
quotes for a string root. Always read completion data rather than a partial snapshot.
Guided structure is not semantic correctness: validate extracted facts and
business constraints in the application.

### Root list with optional contact fields

```dart
const contactsSchema = StructuredSchema.array(
  name: 'Contacts',
  maxItems: 10,
  items: SchemaProperty.object(
    requiredProperties: ['name'],
    properties: {
      'name': SchemaProperty.string(),
      'email': SchemaProperty.string(),
      'address': SchemaProperty.object(
        requiredProperties: [],
        properties: {'city': SchemaProperty.string()},
      ),
    },
  ),
);
```

Use the same schema with `generateStructured`, `streamStructured` or
`measureTokenBudget`. An empty extracted list is valid when no contacts were
supplied. To classify into one label use `StructuredSchema.string(name: 'Category',
enumValues: ['work', 'personal', 'other'])`; a bounded rating can use
`StructuredSchema.integer(name: 'Rating', minimum: 1, maximum: 5)`.

Descriptions reach native guidance for every supported root and for unnamed
array items, alternatives and definitions. Named object-property descriptions
remain on their native property. Where a scalar/array/reference constructor has
no description parameter, the mapper retains it through a single-choice named
native schema; underlying type, enum/pattern and bounds remain the same.
This preserves guidance rather than validating the truth of generated content.

Tool parameter schemas remain object-root because tool calls carry named
arguments. Choosing an array/scalar output root does not permit those roots for
tool arguments. F02 uses the existing OS 26 guided APIs and privacy requirements;
no SDK floor or runtime dependency is added.

### Import JSON Schema definitions

`StructuredSchema.fromJsonSchema` imports a strict **generation subset of JSON
Schema 2020-12**. It accepts schema data and produces the existing runtime
contracts without code generation, network calls or new runtime dependencies.
It does not validate arbitrary response data or implement the full standard.

```dart
final contacts = StructuredSchema.fromJsonSchema({
  r'$schema': 'https://json-schema.org/draft/2020-12/schema',
  'title': 'Contacts',
  'type': 'array',
  'maxItems': 10,
  'items': {
    'type': 'object',
    'additionalProperties': false,
    'required': ['name'],
    'properties': {
      'name': {'type': 'string'},
      'email': {'type': 'string'},
      'address': {
        'type': 'object',
        'additionalProperties': false,
        'properties': {'city': {'type': 'string'}},
      },
    },
  },
});
final response = await models.generateStructured(
  prompt: const Prompt.text('Morgan supplied a name only.'),
  schema: contacts,
  mode: ModelMode.local,
  cloudPolicy: CloudPolicy.never,
);
```

Reuse the imported schema with `generateStructured`, `streamStructured`,
`stream(schema: ...)` and `measureTokenBudget`. For schema text, call Dart's
`jsonDecode` and pass the resulting `Map<String, Object?>`; the app owns asset
loading and JSON syntax errors. Inputs are copied into immutable property,
required-field and enum collections, so later caller mutations do not change
the definition. `name:` overrides the root `title`; otherwise a nonblank title
or `Output` supplies the name. Nested titles are accepted annotations and do
not affect native type names; descriptions are forwarded.

| Type or scope | Accepted keywords | Profile contract |
| --- | --- | --- |
| Every node | `type`, `title`, `description` | Single supported type, or one anyOf/$ref form; annotations must be strings. |
| Root only | `$schema`, `$defs` | Optional exact 2020-12 URI and up to 32 local named schemas. Nothing is fetched. |
| `object` | `properties`, `required`, `additionalProperties` | Explicit `additionalProperties: false` at every object; properties default to `{}`. Required names must be distinct and declared. |
| `array` | `items`, `minItems`, `maxItems` | Required typed item schema; optional inclusive nonnegative whole counts. Equal bounds express an exact count. |
| `string` | `enum`, `pattern` | Enum is a nonempty list of distinct strings. Patterns require the native-dialect opt-in below. |
| `integer` | `minimum`, `maximum` | Inclusive ordered whole bounds in signed 64-bit range; integral numbers such as `1.0` are accepted. |
| `number` | `minimum`, `maximum` | Inclusive ordered finite bounds for native `Double` guides. An integer bound that would round during conversion is rejected. |
| `boolean` | Common annotations only | No additional constraints. |
| `null` | Common annotations only | Explicit null value; native support requires OS 26.4 and a compatible SDK. |
| Union form | `anyOf`, annotations | One to eight schemas; no sibling type/assertions or oneOf exclusivity. |
| Reference form | `$ref`, annotations | One escaped name under root `#/$defs/`; no remote/recursive references or assertion siblings. |

Omitted JSON `required` means `[]` at **every level**, as in the
[2020-12 required contract](https://json-schema.org/draft/2020-12/json-schema-validation#section-6.5.3).
This differs from omitted manual nested `requiredProperties`, which preserves
all-required legacy fields. Optional absence does not permit explicit null.

The general standard allows additional object fields when `additionalProperties`
is omitted. This profile requires explicit closure because the native mapper
produces closed objects; it rejects open definitions instead of changing their
meaning. See [additionalProperties](https://json-schema.org/draft/2020-12/json-schema-core#section-10.3.2.3).

The profile is intentionally narrower than the standard: it requires a single type or supported union/reference form,
disallows fractional bounds for `integer`, limits enums to strings, and caps
nesting at 16 parent-to-child edges and objects at 128 fields. Numeric precision
is limited by decoded Dart values and native guides; the importer cannot recover
precision already lost by the caller's JSON parser.

JSON Schema patterns use ECMA-262 syntax. Native guides use Swift regular
expressions, so `pattern` is rejected by default. If the app intentionally uses
Swift-compatible patterns, pass `allowSwiftPatterns: true`; this is a dialect
choice, not automatic translation. Swift validates syntax before generation.
Anchors are needed for full-string matching. See the
[standard pattern contract](https://json-schema.org/draft/2020-12/json-schema-validation#section-6.3.3).

Unknown and type-incompatible keywords fail recursively. Unsupported definitions
include boolean schemas, type lists, `$id`, `oneOf`,
`allOf`, tuple/`prefixItems`, `format`, `default`, `examples`, `const`,
`minLength`, `maxLength`, `multipleOf`, exclusive bounds and open objects.
No constraint is dropped or replaced by a prompt. The F06 graph profile below
adds local references/unions/null; the Dart generator remains F09 work.

Invalid imports throw `FoundationModelsException` with `invalidRequest`,
`details['schemaSource'] == 'jsonSchema'` and an input JSON Pointer in
`details['schemaPath']`, before native services are called. For example, an
unsupported email format reports `#/properties/email/format`. Pointer segments
escape `~` as `~0` and `/` as `~1`, following
[RFC 6901](https://www.rfc-editor.org/rfc/rfc6901#section-3). Malformed Swift
patterns and unsupported model guides fail later through the existing native
error contract. Catch failures around both import and generation; do not remove
constraints or switch providers automatically.

Choose manual constructors for a few definitions written in Dart, or import
when the app already owns compatible JSON Schema data. Both remain optional
ways to define the same native generation contract. The
[document example](document-extraction.md) demonstrates imported bounded rows.

### Guided streaming

```dart
await for (final event in session.streamStructured(
  prompt: const Prompt.text('The appointment is with Morgan on Friday.'),
  schema: const StructuredSchema.object(
    name: 'Appointment',
    properties: <String, SchemaProperty>{
      'person': SchemaProperty.string(),
      'day': SchemaProperty.string(),
    },
    requiredProperties: <String>['person', 'day'],
  ),
)) {
  switch (event) {
    case TextSnapshotEvent(:final text):
      print(text);
    case CompletionEvent(:final response):
      print(response.structuredValue);
    default:
      break;
  }
}
```

`stream(prompt, schema: schema, options: ...)` is equivalent to
`streamStructured(prompt: prompt, schema: schema, options: ...)`.
`TextSnapshotEvent.text` is a complete replacement snapshot, not a JSON chunk
to append or consume as a final result. `CompletionEvent.response.text` is the
complete JSON string and `structuredValue` is decoded only after native content
reports completion. A missing final snapshot, incomplete JSON, or a decoding
failure returns `parsingFailure`; preserve the user's input and retry or
simplify the schema. This needs iOS/iPadOS 26+ or macOS 26+ and normal model availability; PCC adds
the existing OS 27 host opt-in and entitlement requirements.

### Null, anyOf and local references

F06 adds const root/property constructors `nullValue`, `anyOf` and `reference`,
plus `StructuredSchema.definitions`. Required presence and accepted null values
are independent:

```dart
const nullableName = SchemaProperty.anyOf(alternatives: [
  SchemaProperty.string(),
  SchemaProperty.nullValue(),
]);
const schema = StructuredSchema.object(
  name: 'Contact',
  requiredProperties: ['displayName'],
  properties: {
    'displayName': nullableName,
    'nickname': nullableName,
    'email': SchemaProperty.string(),
  },
);
```

`displayName` must be present and may be null. `nickname` may be omitted or have
a string/null value. `email` may be omitted but its declared type does not permit
null. For a decoded map, use `containsKey` before reading the value to distinguish
omission from present null; do not convert absence to null automatically.
Existing root/nested required defaults remain unchanged.

`anyOf` means at least one branch may match; overlapping integer/number branches
are allowed. It does not implement exclusive `oneOf`, conditions or arbitrary
intersections. See the [standard anyOf contract](https://json-schema.org/draft/2020-12/json-schema-core#section-10.2.1.2).
For distinct document shapes, use explicit discriminator fields/enums in each
object branch and an app decoder that understands them. Conversion still does
not prove facts or authorize effects.

Reuse a root-scoped definition by exact name:

```dart
const address = SchemaProperty.object(
  properties: {'city': SchemaProperty.string()},
  requiredProperties: ['city'],
);
const contacts = StructuredSchema.object(
  name: 'Addresses',
  definitions: {'Address': address},
  properties: {
    'home': SchemaProperty.reference('Address'),
    'work': SchemaProperty.reference('Address'),
  },
);
```

Definitions may contain any supported schema, including scalar bounds, arrays,
unions and other acyclic local references. Root constructors also accept the
registry; `StructuredSchema.reference(name: ..., reference: ..., definitions: ...)`
can reuse a definition as the output root. Internal native aliases keep names
unique and preserve constraints; they do not wrap the generated data in an
additional app object. Tool parameter schemas retain their existing object-root
requirement; reference properties inside that object are allowed.

JSON import supports equivalent data forms:

```dart
final schema = StructuredSchema.fromJsonSchema({
  r'$ref': r'#/$defs/Contact',
  r'$defs': {
    'Contact': {
      'type': 'object',
      'additionalProperties': false,
      'required': ['name'],
      'properties': {
        'name': {'anyOf': [{'type': 'string'}, {'type': 'null'}]},
      },
    },
  },
});
```

Only root `$defs` and references to one name at `#/$defs/<escaped-name>` are
supported. Escape `/` as `~1` and `~` as `~0`. External URLs, root `#` references,
anchors, URI-percent encoding, pointers into arbitrary nested schemas and cycles
are rejected. `$ref`/`anyOf` nodes accept annotations but no sibling assertions;
the profile does not discard or merge those constraints. Definition schemas keep
closed objects and the same keyword validation as root schemas.

New graphs allow up to 32 definitions, 1–8 alternatives per union, depth 16 and
512 expanded input nodes, counting reference validation and declared definitions.
All declarations are validated, including unused ones; an unused null declaration
still requires null-capable native construction. These are package profile limits,
not claims of Apple/JSON Schema limits. Larger valid legacy literal trees retain
their earlier behavior. Undefined refs/cycles/bounds throw `ArgumentError` in
complete manual serialization or typed `invalidRequest` with input `schemaPath`
on import. `SchemaProperty.toMap(definitions: ...)` can serialize a complete graph;
standalone no-registry property serialization leaves a reference name unbound.

AnyOf and references use native OS 26 APIs. Explicit null requires OS 26.4 and
an Xcode 26.4+ / Swift 6.3+ SDK build path. This is separate from the package's
Xcode 27 guards for other APIs. The SDK/OS boundary
resolves the native null schema before passing it to the mapper; missing support
fails with `unsupportedCapability` and a path-bearing message. Nothing changes
the deployment targets iOS 15/macOS 12. Apple documents
[explicit null and nullable alternatives](https://developer.apple.com/documentation/foundationmodels/dynamicgenerationschema/null)
and [native local dependencies](https://developer.apple.com/documentation/foundationmodels/generationschema/init(root:dependencies:)).
Check `getCapabilities().details['explicitNullSchemas']`, `schemaAnyOf` and
`schemaReferences` when selecting the feature, then check model availability.
Capability flags describe API support; the selected model may still reject a guide.
No automatic fallback from null to omission, no remote lookup or provider switch occurs.

`ModelResponse.hasStructuredValue` distinguishes a final null root from absent
guided data. Native guided responses send presence true even when `structuredValue`
is null; plain-text responses send false. Legacy non-null values still imply
presence, while legacy null with no signal stays absent. Manual const responses
can specify `hasStructuredValue: true`; contradictory false/non-null states fail
when presence is read, and malformed wire signals fail with `parsingFailure` /
`decodingStage: responsePresence`.

With presence true and a completed structure, F04 decoders receive null exactly
once, for example `generateStructuredDecoded<String?>(..., decoder: (value) =>
value as String?)`. Missing presence and explicit incompleteness still fail.
Snapshots remain nonterminal, including complete null snapshots; final decoding
waits for `CompletionEvent`. See the [optional document date mode](document-extraction.md#optional-explicit-null-dates).

### Structured snapshots and property order

F05 enriches the existing `TextSnapshotEvent` with an optional
`structuredSnapshot`, preserving the sealed event variants and default streams.
Opt in only for a guided stream:

```dart
await for (final event in session.streamStructured(
  prompt: const Prompt.text('Morgan supplied a name only.'),
  schema: const StructuredSchema.object(
    name: 'Contact',
    properties: {
      'name': SchemaProperty.string(),
      'email': SchemaProperty.string(),
    },
    propertyOrder: ['name', 'email'],
  ),
  options: const GenerationOptions(includeStructuredSnapshots: true),
)) {
  if (event is TextSnapshotEvent) {
    final snapshot = event.structuredSnapshot;
    if (snapshot != null) displayStructuredProgress(snapshot);
  } else if (event is CompletionEvent) {
    reviewFinalResponse(event.response);
  }
}
```

Display/review functions belong to the host. Query availability for the intended
route as usual. Native capabilities expose `details['structuredSnapshots']` and
`details['explicitPropertyOrder']`; check `== true` when the host/bridge may be
older. These are feature flags, not proof that a model is available now.
The feature uses existing OS 26 Foundation Models APIs; PCC remains explicitly
authorized and subject to its existing OS 27/host requirements.

`StructuredSnapshot` describes a native tree projection:

| Field | Meaning |
| --- | --- |
| `hasValue` | Whether a safe root projection exists; independent of false/zero/empty/null values. |
| `value` | Immutable containers and complete leaves from native content; no repaired strings or numbers. |
| `presentPaths` | Observed JSON Pointer nodes, including a begun leaf that may still be withheld from value. |
| `completePaths` | Observed nodes Apple marks complete; these flags do not validate facts or business rules. |
| `isComplete` | Native root completeness for this snapshot, not stream completion. |

The bridge walks `GeneratedContent.kind` and consults native `isComplete`.
Incomplete strings/numbers are not synthesized or completed by a tolerant JSON
parser. Container fields may be shown as they appear. Arrays retain the available
contiguous prefix without shifting indices; an incomplete object element can
contain only the fields already complete. A root leaf may have `hasValue: false`
while its observed path is `#`. `false`, zero, empty strings and empty containers
remain valid when native content marks them complete.

Apple defines [native completeness](https://developer.apple.com/documentation/foundationmodels/generatedcontent/iscomplete)
and supports [incomplete GeneratedContent input](https://developer.apple.com/documentation/foundationmodels/generatedcontent/init(json:)).
In the installed SDK tests, a number at the end of partial JSON can remain
incomplete even when its current spelling parses as JSON. Follow native flags
rather than inferring completion from text syntax.

Snapshots replace prior state. They are not append-only patches and can revise
values or omit a field seen earlier; do not merge maps or commit records on a
snapshot. An `isComplete: true` snapshot is still a `TextSnapshotEvent` until the
single `CompletionEvent` arrives. Only that final response can use the F04 decoder.
Incomplete/malformed final native output still fails strict JSON completion and
parsing. Partial projections do not grant permission to save data or call tools.

Paths are data locations (`#/rows/0/amountText`), escaping `~` and `/` as JSON
Pointer segments. Present/complete lists and nested values are immutable.
Path lists retain native traversal order; do not infer field order from map iteration.
Array paths stop at the first withheld leaf together with the projected prefix.
Malformed native snapshot payloads fail with `parsingFailure` and
`decodingStage: structuredSnapshot`; cancellation is awaited rather than leaving
the native stream running. Failed cancellation requires disposing the session.
Opt-in does not add a wrapper stream or change pause, deadlines and subscription
cancellation. The raw JSON text field remains available with its earlier meaning.

Set order on each object independently:

```dart
const row = SchemaProperty.object(
  properties: {
    'amountText': SchemaProperty.string(),
    'description': SchemaProperty.string(),
    'sourceRow': SchemaProperty.integer(minimum: 1),
  },
  propertyOrder: ['sourceRow', 'description', 'amountText'],
);
```

`StructuredSchema.object(propertyOrder:)` controls the root; nested
`SchemaProperty.object(propertyOrder:)` controls only its own children, including
array items. Supply every declared property exactly once, including optional
ones. An empty order is valid for an empty object. Omitting the option keeps the
previous alphabetical order; map insertion order does not set native order.
Invalid manual lists throw `ArgumentError` before request admission; invalid
wire orders report `schemaPath` ending in `/propertyOrder`.

For JSON Schema import, keep generation order outside standard keywords:

```dart
final schema = StructuredSchema.fromJsonSchema(definition, propertyOrders: {
  '#': ['currency', 'rows'],
  '#/properties/rows/items': ['sourceRow', 'dateText', 'description', 'amountText'],
});
```

These keys identify **object schema definitions**, not output data nodes.
Unknown/non-object targets and invalid permutations fail import with
`invalidRequest` and the target `schemaPath`; supplied order lists are copied.
The JSON keyword `propertyOrder` remains unsupported by the strict importer.
Required-field semantics, constraints and optional absence remain unchanged.

The mapper supplies properties to the native schema in the selected order;
current SDK contract tests preserve that order in its encoded schema. Apple
also documents [declared property order for guided generation](https://developer.apple.com/documentation/foundationmodels/generating-swift-data-structures-with-guided-generation).
No speed, latency or accuracy improvement is promised by choosing an order.
Use early fields for useful display progress, with final review still required.
See the [document progress example](document-extraction.md#structured-progress).

### Decode final values to Dart types

F04 adds `generateStructuredDecoded<T>` to both the facade and an owned session.
It delegates to existing guided generation and calls the app's synchronous
`T Function(Object? value)` decoder once after generation has completed. Use
manual constructors or the F03 importer for the schema; no code generator is
required. The callback can reuse an existing domain constructor or converter.

```dart
final result = await models.generateStructuredDecoded<(String, String?)>(
  prompt: const Prompt.text('Morgan supplied a name only.'),
  schema: StructuredSchema.fromJsonSchema({
    'type': 'object',
    'additionalProperties': false,
    'required': ['name'],
    'properties': {
      'name': {'type': 'string'},
      'email': {'type': 'string'},
    },
  }),
  decoder: (value) {
    final contact = value! as Map<String, Object?>;
    return (contact['name']! as String, contact['email'] as String?);
  },
  mode: ModelMode.local,
  cloudPolicy: CloudPolicy.never,
  options: const GenerationOptions(maximumResponseTokens: 120),
);
final (name, email) = result.value;
final originalResponse = result.response;
```

`DecodedModelResponse<T>` retains the **original `ModelResponse` by identity**,
including JSON text, actual native mode, metadata, nullable usage and termination.
Unknown counters/completeness stay unknown. The app decoder receives only
`structuredValue`; the helper does not reparse `text`, repair fields, mutate the
response or retry generation. Decoder code owns any mutations or effects it
performs; prefer conversion without side effects. Converting data does not
authorize tools, writes or business decisions.

Object, array and scalar roots are supported. `false`, `0`, `0.0`, `''` and `[]`
are valid decoder inputs. A nullable `T` may return null intentionally. F06 also
allows explicit null input when `hasStructuredValue` is true; absence still fails.
Nested missing/null values must be handled according to the app's declared contract.

For an existing final response, call:

```dart
final decoded = response.decodeStructured<bool>(
  decoder: (value) => value! as bool,
);
```

For a stream, call it only on `CompletionEvent.response`. Text snapshots remain
partial JSON and do not run a decoder automatically. Cancellation or failure
before completion does not produce a decoded result. No `streamInto` or partial
object decoder is added by F04.

| Failure | Contract |
| --- | --- |
| Invalid manual constraints | Existing `ArgumentError` before native request admission. |
| Invalid imported/native schema or unsupported guide | Existing typed native/import failure, including `schemaPath` when available. |
| Native final JSON parsing | Existing `FoundationModelsException` with `parsingFailure`; decoder is not invoked. |
| Missing structured value or explicit `structuredContentComplete: false` | `parsingFailure` with `decodingStage: structuredValue` before decoder invocation. Unknown completeness is accepted without inferring true. |
| A response whose status is not completed | `invalidRequest` with `decodingStage: response` and `responseStatus`; decoder is not invoked. |
| App decoder throws, including a cast error or package exception | `StructuredDecodingException`, retaining `response`, original `cause` and original `stackTrace`. |

Catch both package and app-conversion failures:

```dart
try {
  final result = response.decodeStructured<MyModel>(decoder: MyModel.fromStructuredValue);
  reviewModel(result.value, result.response);
} on StructuredDecodingException catch (error) {
  showConversionFailure(error.response);
} on FoundationModelsException catch (error) {
  showGenerationFailure(error.code);
}
```

`MyModel` and review/error functions represent app-owned types and callbacks.
The exception's default string omits output and cause; the retained cause,
response and stack may contain data, so logging remains the app's decision.

The facade disposes its temporary session before running the decoder. Disposal
failure prevents decoding and retains the existing cleanup error. An owned
session remains caller-owned and is reusable after a decoder failure; it still
enforces single-flight native requests. Timeouts/cancellation cover native
generation, not synchronous app conversion. A decoder runs on the calling Dart
isolate and should finish promptly.

Generation diagnostics are forwarded unchanged and may report native completion
even when the app decoder subsequently fails. The response's termination is not
rewritten as a model failure. App conversion errors should be recorded separately
under the app's data policy. No public native error enum changes, SDK changes,
runtime dependencies or automatic persistence are introduced. See the
[typed document example](document-extraction.md#typed-final-document).

## Tools

```dart
final class DeviceTimeTool implements ModelTool {
  const DeviceTimeTool();
  @override
  String get name => 'device_time';
  @override
  String get description => 'Return the current device timestamp.';
  @override
  Map<String, Object?> get parameters => const <String, Object?>{
    'type': 'object',
    'properties': <String, Object?>{},
  };
  @override
  Duration get timeout => const Duration(seconds: 3);
  @override
  Object? call(Map<String, Object?> arguments) =>
      DateTime.now().toIso8601String();
}
```

Register tools at session creation through `SessionOptions.tools`. Names must
be unique and non-empty. Parameters must use a supported object schema, and
tool timeouts must be between 1 ms and 10 minutes. Return codec-safe values
(strings, numbers, booleans, null, lists and string-keyed maps).

Dart and Swift bound tool waits. Native results above 64,000 characters are
replaced with an explicit size failure, not silently truncated data. Keep
results far smaller to fit the local context. Tool failures are returned to the
model as failure text; application code must decide whether an action succeeded.
Malformed non-object tool arguments are rejected before invoking the handler.

Cancellation stops waiting; it cannot interrupt arbitrary Dart code or undo an
external side effect. Make mutating tools idempotent and validate authorization
inside the handler. Do not assume `ToolCallEvent` is a complete tool audit log:
actual tool execution is delivered through the registered `ModelTool` callback.

## Files and images

`models.pickFile(kind: ...)` opens the native document picker; cancellation
returns null. The returned path is an app-local temporary copy with a separate
original display name. `kind: any` means the picker accepts any item, not that
the model understands every format. The host owns retention and deletion of
picked temporary copies after all requests using them finish.

| Attachment | Handling and limits |
| --- | --- |
| UTF-8 text, Markdown, JSON, CSV | At most 5 MiB; non-empty text is inserted into the prompt. |
| Text PDF | At most 20 MiB; PDFKit extraction, at most 5 MiB extracted text. |
| Image bytes/files on iOS/iPadOS 27 or macOS 27 | At most 50 MiB; downsample to 2,048 pixels, then local Vision OCR/classification/barcodes. |
| Scanned PDF | OCR externally or supply individual images; text extraction alone is insufficient. |
| Audio | Use `transcribeAudio()` first, then send bounded text. |
| Word/binary/unsupported files | Typed error; convert to a supported format. |

```dart
final file = await models.pickFile(kind: FoundationModelsFileKind.text);
if (file != null) {
  final prompt = Prompt(
    text: 'Summarize the supplied document.',
    attachments: <PromptAttachment>[file.toPromptAttachment()],
  );
  final count = await models.countTokens(prompt);
  print(count);
}
```

Extraction and file validation do not guarantee complete interpretation.
Image preprocessing cannot answer every visual question or recover every
receipt/table field. A scanned or partly scanned PDF may need OCR even when
some pages contain text. Verify coverage; never silently drop missing pages in
financial or other accuracy-sensitive workflows.

Native Foundation Models image attachments remain disabled on **all supported
runtimes** in this version because of previously reproduced beta ABI crashes.
The new iOS 27.2 data-attachment APIs are also not exposed. See the
[SDK audit](ios-27.2-audit-2026-09-19.md).

## Speech

```dart
final transcript = await models.transcribeAudio(
  const AudioTranscriptionRequest(
    filePath: '/absolute/path/to/audio.m4a',
    localeIdentifier: 'en_US',
    mode: AudioTranscriptionMode.onDevice,
    timeout: Duration(minutes: 2),
  ),
);
```

Live input:

```dart
final subscription = models.liveTranscription(
  request: const LiveTranscriptionRequest(
    localeIdentifier: 'en_US',
    mode: AudioTranscriptionMode.onDevice,
  ),
).listen(
  (event) => print(event.text),
  onError: (Object error) => print(error),
);
await subscription.cancel();
```

Only one live capture is allowed. Each event is the whole recognized snapshot;
modern Speech finalizes segments while the capture continues, so segment
finality is not the end of the whole stream. Cancellation ends capture; it does
not promise an extra final transcript event. Preserve the last received text.

The modern engine uses SpeechAnalyzer/SpeechTranscriber on iOS/iPadOS 26+ or macOS 26+, with
AssetInputSequenceProvider/CaptureInputSequenceProvider on OS 27. Supported
locales and asset downloads are determined at runtime. Metadata identifies the
engine and effective mode. `taskHint` and `addsPunctuation` apply to the legacy
SFSpeechRecognizer path; the modern path uses its native transcription options.

`onDevice` forbids server recognition. `automatic` may use the Apple Speech
server when local recognition is unavailable; `server` permits that networking
path and is not a PCC request. File transcription timeout cancels the native
request and reports `transcriptionTimeout`. Asset acquisition or native cleanup
may delay completion; the package cannot guarantee transcription latency.

For a complete example with Spanish numeric text and physical integration
scenarios, see [document extraction](document-extraction.md).

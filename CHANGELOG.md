## 1.9.0

Release 1.9.0 includes F01–F10 and the review corrections. F10 adds optional application adapters and
lossless streaming conveniences without changing existing events or routing.

- Add optional cupertino_fundations_models_adapters.dart entry point, an owned
  FoundationModelsAdapter and borrowed Stream<SessionEvent>.adaptEvents.
  Preserve original events/responses, structured snapshots, tools and nullable
  usage/termination metadata; never re-execute observed tools.
- Add TextSnapshotReducer/TextUpdate append-or-replace semantics, including final
  reconciliation, shortening/clearing, Unicode boundaries and stale-buffer checks.
  Append-only consumers reject revisions explicitly instead of emitting false deltas.
- Keep streams cold, single-subscription and isolated per request. Propagate pause,
  source errors and awaited cancellation; pending creation is disposed after early
  cancel, and terminal delivery waits for owned cleanup. Missing/mixed terminal
  context fails explicitly, with no fabricated success, retry or fallback.
- Add a tested app backend interface/example and current Genkit/LangChain mapping
  recipes. SDK/tool/schema/usage/cancellation differences remain app choices;
  no framework provider package, SDK upgrade or official provider plugin is added.
- Complete existing Dartdoc/guides/research/state and whole-library regressions.
  Generator 1.8.0 stays compatible with core 1.9.0 and is versioned separately.
- Whole-series review: reject lossy integer bounds in manual/native Double
  guides, preserve descriptions on scalar/array/reference roots and unnamed
  nested schemas, and enable explicit null with Xcode 26.4 / Swift 6.3.
  Pin the Apple CI job to Xcode 26.6 so its runtime/coverage scope is explicit.
- Complete publication dry-run repairs: explicit channel type arguments, library
  directives and generated style directives; add the companion's named entry point
  and a source-only staging helper for its separate archive.
- No third-party runtime dependency, breaking API, native target change or implicit routing.

## 1.8.0

Prepared locally; not published. F09 adds a separate optional Dart generator
while preserving manual/imported schemas and existing native/runtime contracts.

- Add dependency-free StructuredModel/StructuredField annotations and shared
  structural readers/StructuredPartialField state in core, with no new runtime
  dependencies. Add cupertino_fundations_models_generator 1.8.0 as a dev package.
- Explicit build_runner generation emits standalone *.structured.dart companions:
  ClassCodec.schema/decode and ClassPartial. Source models stay unchanged; no
  part directive, generated Swift, inference, assets or routing is introduced.
- Support public concrete object models with named generative construction,
  primitives, public enums, lists, annotated nested types and nullable choices.
  Preserve guides/order, presence versus null, safe partial prefixes and exact
  scalar types. Unsupported forms/invalid guides/recursive or oversized graphs
  fail with source diagnostics rather than coercion.
- Keep native nullable-schema availability and runtime validation unchanged.
  Final conversion is structural; constructors/business validation stay app-owned.
  Partial views never construct final models or authorize effects.
- Test reproducible builder outputs, actual compiled companions, manual/import
  equivalence, metadata/error preservation and presence/null/partial behavior.
  Require whole-core and generator line coverage separately plus native regressions.
- Add opt-in document/choice examples and complete existing guides, API docs and
  agent choice questions. Prepare local CI coverage/generation checks; companion
  publication is separate and has not been configured/executed by this task.
- No breaking API, deployment-target change, commit, push or publication.

## 1.7.0

Prepared locally; not published. F08 adds optional local readiness observation and
text-model languages while preserving existing availability/Speech contracts.

- Add `watchAvailability(useCase:, localeIdentifier:, pollingInterval:,
  pauseWhenBackgrounded:)`, a cold single-subscription stream of initial active
  readiness and structural changes. Native Observation is the default; polling
  is explicit and bounded from one second through five minutes.
- Suspend native work on subscription pause and outside Flutter resumed state;
  recheck on resume, suppress duplicate snapshots and ignore stale callbacks.
  Await startup/cleanup; independent watchers use separate IDs and contexts.
- Report missing plugin/unsupported OS or SDK as terminal unavailable snapshots.
  Preserve bridge errors, malformed-payload failures and cancellation errors.
  Existing custom platform adapters remain valid through an optional interface.
- Add immutable `TextModelLanguage` labels and `getTextModelLanguages(useCase:)`
  from the selected local variant, independently of Speech. Preserve the existing
  model/Speech intersection and asset state in `getSupportedLanguages()`.
- Neither API requests inference, assets, Speech permissions or PCC. Advertised
  languages differ from supported regional locales and readiness; Observation
  has no guaranteed transition cadence or download progress percentage.
- Connect the chat's existing readiness banner with owned observation, preserving
  dictation language choices. Test transport isolation, pause/foreground races,
  errors/cleanup, the widget's changing status and genuine Swift Observation.
- Expand the native coverage gate to five production helpers and update existing
  docs, Dartdoc, integration choices and version state. No runtime dependency,
  deployment-target change, breaking API, commit or external delivery.

## 1.6.0

Prepared locally; not published. F07 adds explicit compatible history export and
restoration while preserving existing session constructors and platform adapters.

- Add immutable `SessionHistory`, entry/segment/tool-call descriptors, JSON
  serialization, `session.exportHistory`, `models.restoreSession` and optional
  `SessionOptions.history`. An optional platform capability leaves older platform
  implementations valid and reports unsupported history explicitly.
- Preserve Apple's native Codable Transcript rather than rebuilding from text.
  Retain IDs, complete structures, tools, prompt options/response formats,
  response asset IDs and supported OS 27 reasoning/signatures/metadata.
- Restore into a new native session with the saved route, variant, locale and
  instructions. Require exact tool registrations and known matching platform,
  OS and SDK. Register current callbacks without executing historical calls.
- Bound archives to 1 MiB UTF-8 and 256 entries. Reject attachments, binary/data
  entries, incomplete structure, unmatched/pending tools, duplicate IDs and
  descriptor/archive mismatches instead of dropping content.
- Keep export single-flight and lifecycle-safe. No automatic persistence,
  transcript editing, model-asset identity guarantee or provider replay is added.
  Apps own sensitive storage, user/thread identity, retention and encryption.
- Test native SDK Codable round-trips, options/metadata/tool preservation,
  compatibility failures, malformed payloads and Dart disposal/concurrency.
  Require complete Dart coverage and line/function/region coverage of the
  production schema/snapshot mappers and history codec.
- Add an explicit document extraction/history alternative and update existing
  guides, integration decisions, API docs and local release state. No runtime
  dependency, deployment-target change, breaking API or external delivery.

## 1.5.0

Prepared locally; not published. F06 adds explicit null, anyOf and bounded local
references while preserving existing valid schemas, events and legacy responses.

- Add `StructuredSchema`/`SchemaProperty` nullValue, anyOf and reference
  constructors, with root-scoped definitions. Preserve const constructors and
  existing fields; no public enum or sealed-event variant is added.
- Extend JSON import with null type, anyOf, root `$defs` and local `$ref` to one
  escaped definition name. Reject cycles, remote/recursive references, assertion
  siblings and unsupported composition forms rather than changing their meaning.
- Bound new graphs to 32 definitions, eight union branches and 512 expanded
  nodes; retain depth 16, field bounds and valid larger legacy literal trees.
- Resolve null capability under SDK/OS guards, requiring OS 26.4 and this
  package's compatible Xcode 27 SDK path. Pass the resolved native null schema
  into the mapper; unavailable support returns a typed capability failure.
  AnyOf/references retain their OS 26 path.
- Add `ModelResponse.hasStructuredValue` and an explicit native presence signal
  so final null is data while legacy missing null remains absent. Final decoders
  accept present null; malformed presence signals and incomplete data still fail.
- Test real Foundation Models null/union/reference schemas, reused constraints,
  presence versus optional fields, cycles/bounds, legacy graphs and nullable
  one-shot/stream results without generation inference.
- Update Dartdoc, existing guides and document example. Its default date remains
  optional; explicitNullDates opts into a required nullable date and native support.
- No runtime dependencies, deployment-target change, major break or publication.

## 1.4.0

Prepared locally; not published. F05 adds opt-in structured snapshots and
explicit property order without changing legacy streams or sealed event variants.

- Add optional `propertyOrder` to object roots and object properties. Validate
  full permutations in Dart and Swift; omission retains alphabetical native
  order. Imported schemas accept separate `propertyOrders` keyed by input
  object-schema JSON Pointers, preserving the strict standard-keyword subset.
- Add `GenerationOptions.includeStructuredSnapshots` for guided streams and
  nullable `TextSnapshotEvent.structuredSnapshot`. Defaults preserve the earlier
  wire/event behavior; no sealed `SessionEvent` subtype or public enum is added.
- Add immutable `StructuredSnapshot` with projected value, root availability,
  observed/complete paths and native completeness. Use the native GeneratedContent
  tree; withhold incomplete leaves and retain array prefixes without repairing JSON.
- Keep snapshots replaceable and nonterminal, even when their native flag is
  complete. Final JSON parsing and F04 final decoders remain strict and separate.
- Reject malformed snapshot payloads with typed parsing failures, await native
  cancellation and preserve the session's failed-cancellation protection.
  Reject snapshot opt-in for text-only streams and one-shot requests.
- Test authentic incomplete GeneratedContent, numeric/string withholding, nested
  fields, empty/scalar values, revisions and real SDK property order. Extend the
  native coverage gate to both production schema and snapshot mappers.
- Update existing API docs, guides, recipes, AI integration choices and document
  example. No third-party runtime dependency, SDK/deployment change or publication.

## 1.3.0

Prepared locally; not published. F04 adds app-owned final-value decoding while
preserving existing response types, generation behavior and public error enums.
This is additive to local 1.2.0, so no major-version change is required.

- Add `generateStructuredDecoded<T>` to the facade and owned sessions, with an
  explicit synchronous decoder and the existing schema/options/privacy policy.
- Add `ModelResponse.decodeStructured<T>` for an existing final response,
  including guided stream completion. Object/list/scalar and false/empty values
  are supported; nullable domain results may be returned intentionally.
- Add `DecodedModelResponse<T>` with `value` and the original `response` by
  identity, retaining text, route, metadata, nullable usage and termination.
- Add `StructuredDecodingException` retaining the decoder's original cause,
  stack and native response. Default stringification omits output/cause.
  Native schema/JSON/lifecycle failures retain their existing contracts.
- Reject non-completed responses, missing structured values and explicitly
  incomplete structures before conversion. Preserve unknown completeness.
  Do not reparse text, decode partial snapshots, repair fields or retry requests.
- Preserve facade disposal before conversion, owned-session reuse after decoder
  failures and existing native diagnostic events. App conversion remains outside
  native deadlines and authorization/persistence rules.
- Expand library tests for domain models, optional fields, scalars, metadata,
  conversion/native errors, cleanup, cancellation, timeout and concurrency.
  Extend the document example with typed final data preserving monetary strings.
- Update Dartdoc and existing guides, recipes, FAQ and AI integration choices.
  No runtime dependency, Swift change, SDK/target change or generator introduced.

## 1.2.0

Prepared locally; not published. F03 adds optional JSON Schema data import to
the same runtime contracts and native mapper as manual Dart definitions.

- Add `StructuredSchema.fromJsonSchema(Map<String, Object?>, {name,
  allowSwiftPatterns = false})` for the explicit JSON Schema 2020-12 generation
  subset: six root types, nested objects/arrays, string enums and F01 constraints.
- Require `additionalProperties: false` at every imported object. Omitted JSON
  `required` means none at every level; manual nested defaults remain unchanged.
- Reject unknown/type-incompatible keywords, open objects, references, unions,
  boolean/null schemas, fractional integer limits, non-finite values and number
  bounds that lose value in native Double conversion. Enforce depth/field limits.
- Copy input collections and report typed `invalidRequest` failures with
  `schemaSource: jsonSchema` and escaped input JSON Pointers before native work.
- Require explicit Swift-pattern opt-in rather than treating ECMA-262 patterns
  as equivalent. Native syntax/guide failures retain the existing contract.
- Test shared contact fixtures across Dart import and the production Swift
  mapper, boundaries, error paths, mutation isolation, one-shot output, guided
  streaming and budgets. Keep whole-library regressions and both coverage gates.
- Update existing API docs, guides and integration questions. The document
  extraction example now imports its schema without changing required fields
  or output bounds. No code generator, new runtime dependency or SDK change.

## 1.1.0

Prepared locally; not published. F02 extends the prepared 1.0.0 API without
changing valid object schemas, privacy defaults or required-field defaults.

- Add const `StructuredSchema.array`, `.string`, `.integer`, `.number` and
  `.boolean` constructors. Root values use the same F01 constraint validation
  and native mapper as properties; `type` identifies the root shape.
- Add optional `SchemaProperty.object(requiredProperties:)` and the equivalent
  generic property option. Null/omitted preserves all-required nested fields;
  an empty list makes them optional, and named lists require only those fields.
- Reject duplicate/undeclared nested required names and required lists on other
  property types before native request admission.
- Preserve `StructuredSchema.object`'s existing empty required-list default.
  Tool parameters remain object-root; output roots do not change that contract.
- Test empty lists, false, zero and empty strings as valid final values, plus
  contact extraction with missing optional fields, guided streams and budgets.
  Native tests inspect the real Foundation Models root/required schemas.
- Update existing Dartdoc, guides, AI integration questions and document example.
  JSON Schema import, null schemas, unions and generated schemas remain planned.

## 1.0.0

Prepared locally; not published. This is the first stable API version and the
F01 delivery. Existing 0.5.0 Dart constructors and privacy defaults remain valid.

- Add inclusive `minimum` and `maximum` to integer/number properties, native
  Swift regex `pattern` to strings, and `minItems`, `maxItems` or `exactItems`
  to arrays. Constraints apply to nested guided output and tool parameter schemas.
- Validate finite, ordered bounds and non-negative counts in Dart, including
  const values in release mode. Reject invalid native types, booleans used as
  numeric constraints, unsupported definitions and malformed Swift patterns with
  precise schema paths. Constraints are never silently dropped.
- Reject invalid stream constraints before admission so an idle session is not
  needlessly cancelled or made unusable.
- Preserve unbounded schema transport and existing root/required-field behavior.
  `SchemaProperty` keeps its public name and export while moving to its own file.
- Document the complete Dart API and update the existing guides with constraints,
  integration questions, version planning and explicit current/future boundaries.
- Add daily-use triage/invoice scenarios, production Swift mapper tests and
  separate Dart/native-schema coverage gates. Keep the existing library-wide
  lifecycle, tools, Speech and release-guard regression tests.

### Compatibility

F01 is additive to 0.5.0. No API removal or required dependency is introduced.
Generation still needs iOS/iPadOS 26 or macOS 26 and native model availability;
deployment remains iOS 15/macOS 12. No code generator is required or included.
The 1.x line will preserve compatible API changes in minor releases and move
breaking changes to a new major. See [Dart versioning](https://dart.dev/tools/pub/versioning).

### Planned feature versions

Each row records one completed implementation objective. F01–F10 are combined
in the core 1.9.0 delivery; targets 1.0.0–1.8.0 were not published individually.
The optional generator 1.8.0 has a separate publication flow. Targets are not a promise
to place breaking behavior in a minor release. If a contract must break, its
version and migration instructions will be revised to the next major.

| Version target | Feature | Status |
| --- | --- | --- |
| 1.0.0 | F01: numeric bounds, patterns and array lengths | Included in core 1.9.0 |
| 1.1.0 | F02: additional roots and nested required fields | Included in core 1.9.0 |
| 1.2.0 | F03: explicit JSON Schema subset import | Included in core 1.9.0 |
| 1.3.0 | F04: generic final-value decoder with response metadata | Included in core 1.9.0 |
| 1.4.0 | F05: structured partials and property order | Included in core 1.9.0 |
| 1.5.0 | F06: unions, null and local references | Included in core 1.9.0 |
| 1.6.0 | F07: export and restore session history | Included in core 1.9.0 |
| 1.7.0 | F08: observable availability and text-model languages | Included in core 1.9.0 |
| 1.8.0 | F09: separate optional Dart generator | Included in core 1.9.0 |
| 1.9.0 | F10: optional ecosystem adapters and stream conveniences | Included in core 1.9.0 |

## 0.5.0

- Add macOS registration and shared Darwin Swift sources for CocoaPods and Swift
  Package Manager, retaining iOS 15 and adding macOS 12 deployment targets.
- Extend native generation, sessions, streaming, structured output, tools,
  token counting, diagnostics and opt-in PCC to their matching macOS runtimes.
- Add a Mac file picker, microphone permission handling and a macOS example host.
- Document iPadOS support through the iOS target and the Flutter/API limits for
  visionOS, watchOS and tvOS. iOS and macOS examples compile with Xcode 27.2
  beta; device permissions, model/Speech readiness and entitled PCC remain unverified.
- Require Dart analysis, tests, 100% executable Dart line coverage and Apple
  example builds before creating a release tag or publishing to pub.dev.
- Fix live transcription cancellation while awaiting input and duplicate
  streaming cleanup errors; expand lifecycle, token, tool and diagnostics tests.
- Centralize generation option validation in serialization for every build mode,
  preserving const constructors and rejecting invalid values before native calls.

## 0.4.4

- Rewrite the getting-started guide around practical local AI tasks, with
  availability checks, error handling and clear iOS requirements.
- Add English and Spanish tutorials, structured extraction and classification
  recipes, an FAQ and a guide to choosing a local or cloud approach.
- Publish a documentation site with individual guide URLs, language links,
  search and sharing metadata, a sitemap and Markdown versions of the guides.
- Update package discovery metadata and link to the new documentation.
  The package name, public API, privacy defaults and runtime behavior are unchanged.

## 0.4.3

- Give the stream error-handler tear-off an exact two-positional-argument
  signature, fixing the handler warning introduced in 0.4.2 while retaining
  the removal of the forwarding closure. No public API change.

## 0.4.2

- Replace the stream error forwarding closure with its method tear-off, fixing
  the lint reported by pub.dev's scoring analysis. No API or behavior change.
- Point the documentation metadata to the generated pub.dev API reference,
  verified reachable with an HTTP HEAD request.

## 0.4.1

- Specify the new token-budget channel result type explicitly to satisfy strict
  inference; order Dart directives and required parameters consistently.
- No runtime/API contract change from 0.4.0. The same migration guide applies.
- Publication includes Pub's integrated package checks; no separate analysis,
  tests, builds or device execution was requested or performed.

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

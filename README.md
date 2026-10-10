# Cupertino Foundation Models — local AI for Flutter on Apple platforms

[![pub.dev](https://img.shields.io/pub/v/cupertino_fundations_models.svg)](https://pub.dev/packages/cupertino_fundations_models)
[![pub points](https://img.shields.io/pub/points/cupertino_fundations_models)](https://pub.dev/packages/cupertino_fundations_models/score)
[![MIT license](https://img.shields.io/badge/license-MIT-blue)](LICENSE)

Use Apple's **Foundation Models** from Dart to summarize text, rewrite a
message, extract structured fields or classify content in your Flutter iOS,
iPadOS or macOS app.
The plugin connects directly to the native framework through Swift, with
sessions, streaming, guided JSON and tools you define in your app.

Local generation runs on the device without an API key. Apple supplies the
model, so you do not need to bundle your own weights. The package also includes
file and live speech-to-text through Apple **Speech**, supports CocoaPods and
Swift Package Manager, and adds no third-party runtime dependencies.

Version **1.9.0** implements F01 value constraints, F02
array/scalar roots and nested required fields, F03 JSON Schema subset import and
F04 explicit decoding with the original response retained, and F05 opt-in native
structured snapshots plus property order, and F06 explicit null, anyOf and local
references with response presence kept separate. F07 adds explicit native history
export and restoration without replaying past tools. F08 adds optional local
availability observation and independent text-model language queries. F09 adds a
separate optional Dart generator for object schemas, final decoders and typed
partial views. F10 adds optional app adapters and lossless stream updates. Core
1.9.0 includes the complete series. The compatible generator 1.8.0 is released
separately; it is available in the repository and is not published by the core
workflow. Version 0.5.0 does not include those new options.
See the [release record](CHANGELOG.md#planned-feature-versions) for F01–F10 and
[optional integration contracts](doc/usage.md#optional-adapters-and-stream-updates).

[Documentation](https://sooyvilla.github.io/cupertino_fundations_models/) ·
[Start with local AI on iOS](doc/local-ai-ios.md) ·
[Español](doc/README.es.md) · [Apple platforms and macOS setup](doc/apple-platforms.md) ·
[Recipes](doc/recipes.md) · [FAQ](doc/faq.md) ·
[API reference](https://pub.dev/documentation/cupertino_fundations_models/latest/)

Generation needs iOS/iPadOS 26+ or macOS 26+, an eligible device, Apple
Intelligence and downloaded model assets. The plugin deployment targets are
iOS 15 and macOS 12; these do not make generation available on older systems.
Version 0.5.0 adds macOS support through the same Dart API.
On-device inference can work offline after Apple's required model assets are
available; initial downloads and optional cloud/Speech modes can need network.

## What you can build

| Need | What this package provides |
| --- | --- |
| Local text features | Dart APIs backed directly by native Foundation Models sessions. |
| Extract fields into JSON | `StructuredSchema`, guided generation, optional value constraints and decoded final output. |
| Reuse existing JSON Schema definitions | `StructuredSchema.fromJsonSchema` imports an explicit closed-object subset without code generation. |
| Generate companions from Dart classes | Optional development-only generator emits the same runtime schemas, final decoders and typed partial views. |
| Convert final output to a Dart type | `generateStructuredDecoded<T>` and `ModelResponse.decodeStructured<T>` retain the complete original response. |
| Display fields while guided output arrives | Opt-in immutable `TextSnapshotEvent.structuredSnapshot` and per-object generation order. |
| Keep local readiness visible | Optional `watchAvailability`, native Observation or explicit polling, foreground refresh and cleanup. |
| Choose text-only languages | `getTextModelLanguages(useCase: ...)` queries the local variant independently of Speech. |
| Continue an Apple session later | Explicit immutable `SessionHistory`, JSON export and creation of a compatible new session. |
| Integrate an app backend or delta consumer | Optional adapters retain original events; append/replacement updates preserve revised text and final reconciliation. |
| Streaming with a defined lifecycle | Cumulative snapshots, terminal results, cancellation and session disposal. |
| App-defined tool calling | Typed tool registration; your app owns argument validation and authorization. |
| A clear local/cloud boundary | Explicit local mode and `CloudPolicy.never`; PCC requires a separate opt-in. |
| Integration without a custom Swift bridge | Public Dart API, an example app, compatibility tables and recovery guides. |

Start with short, well-defined tasks on eligible Apple devices. If your app needs
other platforms, custom models or a cloud API, read
[choosing a local AI approach](doc/choosing-local-ai.md).

**Version 0.4.0 makes missing usage counters nullable.** Read the
[0.4.0 migration guide](doc/migration-0.4.0.md) for usage, lifecycle and transport
changes. Version 0.3.0 removed hybrid routing; read the
[migration guide](doc/migration-0.3.0.md) before upgrading from 0.2.x.

## Quick start

Use Flutter 3.41+ and Dart 3.11+. To use the published package, add:

```sh
flutter pub add cupertino_fundations_models
```

Version 1.9.0 is published on pub.dev. Use:

```yaml
dependencies:
  cupertino_fundations_models: ^1.9.0
```

To develop against this checkout, use a local path dependency. Adjust the path
to its location relative to your app:

```yaml
dependencies:
  cupertino_fundations_models:
    path: ../cupertino_fundations_models
```

Existing `^0.5.0` consumers do not automatically move to the major release.

The [example app](example/pubspec.yaml) uses a local path dependency to run
against the checked-out source.

For the Mac backend, follow the
[macOS host setup](doc/apple-platforms.md#macos-host-setup).

Rebuild the iOS or macOS host after adding or upgrading the plugin; hot reload cannot
install a changed Swift bridge. When upgrading from an older release, follow
the migration guides above as well.

```dart
import 'package:cupertino_fundations_models/cupertino_fundations_models.dart';

Future<String?> summarize(String shortText) async {
  final models = CupertinoFoundationModels();
  try {
    final availability = await models.checkAvailability(
      mode: ModelMode.local,
      cloudPolicy: CloudPolicy.never,
      localeIdentifier: 'en_US',
    );
    if (!availability.isAvailable) return null;

    final response = await models.respond(
      Prompt.text(shortText),
      mode: ModelMode.local,
      cloudPolicy: CloudPolicy.never,
      instructions: 'Summarize the supplied text in up to three short bullets.',
      options: const GenerationOptions(maximumResponseTokens: 180),
    );
    return response.text;
  } on FoundationModelsException {
    return null;
  }
}
```

Availability can change between the check and the request. Catch
`FoundationModelsException` and keep a manual path available. Let the user
review generated text, and validate extracted data before using it.

## Structured output and request handling

Use `session.streamStructured(prompt: ..., schema: ...)` for native schema-guided
streaming on local or explicitly authorized PCC sessions. Partial JSON snapshots
and decoded completion results remain separate.

In the 1.9.0 API, constraints can express the values the app expects:

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

Use inclusive `minimum`/`maximum` bounds for numeric properties, a Swift regex
`pattern` for strings, and `minItems`/`maxItems` or `exactItems` for arrays.
These constraints apply to native generation, including nested properties and
tool parameter schemas. Invalid Dart bounds fail before request admission;
integer limits on number schemas must retain their exact value as native Double.
Root and unnamed nested descriptions are preserved as native guidance.
Native regex/schema errors identify their path. Guided data still needs app
validation. See [constraints and examples](doc/usage.md#structured-generation).

F02 also supports root arrays, strings, integers, numbers and booleans. For a
list of contacts, each object can require its name and omit an unavailable email:

```dart
const contacts = StructuredSchema.array(
  name: 'Contacts',
  maxItems: 10,
  items: SchemaProperty.object(
    requiredProperties: ['name'],
    properties: {
      'name': SchemaProperty.string(),
      'email': SchemaProperty.string(),
    },
  ),
);
```

Use `.string`, `.integer`, `.number` or `.boolean` for a single guided value.
Final `structuredValue` preserves `false`, zero, an empty string or an empty
list. For nested objects, omitted `requiredProperties` keeps every child required;
`[]` makes every child optional. Root-object defaults remain unchanged. Tool
parameter schemas still require an object root.

F03 also accepts existing schema definitions as data:

```dart
final contact = StructuredSchema.fromJsonSchema({
  'title': 'Contact',
  'type': 'object',
  'additionalProperties': false,
  'properties': {
    'name': {'type': 'string'},
    'email': {'type': 'string'},
  },
  'required': ['name'],
});
```

Use this schema with the same generation, streaming and budget APIs. Every
imported object must explicitly use `additionalProperties: false`; omitted
JSON `required` makes all fields optional at that level. Unknown keywords fail
with an input path. Patterns require explicit `allowSwiftPatterns: true` because
native Swift syntax can differ from the JSON standard. See the
[supported subset and error contract](doc/usage.md#import-json-schema-definitions).
Manual constructors remain available. F09 offers a separate optional generator;
see [generation setup and profile](doc/usage.md#optional-dart-generation).

F04 converts the final guided value with your existing app decoder:

```dart
final result = await models.generateStructuredDecoded<(String, String?)>(
  prompt: const Prompt.text('Morgan supplied a name only.'),
  schema: contact,
  decoder: (value) {
    final fields = value! as Map<String, Object?>;
    return (fields['name']! as String, fields['email'] as String?);
  },
  mode: ModelMode.local,
  cloudPolicy: CloudPolicy.never,
);
final (name, email) = result.value;
final originalResponse = result.response;
```

The same helper exists on an owned session. To convert an existing final response,
including `CompletionEvent.response`, use `response.decodeStructured<T>(decoder: ...)`.
The original text, mode, metadata, usage and termination remain available.
Decoder errors use `StructuredDecodingException` with the original response,
cause and stack; native schema/JSON failures retain their existing errors.
No partial snapshots are decoded or requests retried. See the
[final-value contract](doc/usage.md#decode-final-values-to-dart-types).

F05 lets guided streams opt into `GenerationOptions(includeStructuredSnapshots: true)`.
Each `TextSnapshotEvent` may carry an immutable native projection, observed and
complete JSON Pointer paths, and a root completeness flag. Incomplete leaves
are withheld; replace the previous snapshot and decode final app models only
from `CompletionEvent.response`. Even a complete snapshot is not a terminal event.

Object constructors accept a full `propertyOrder`; omission retains alphabetical
order. For imported definitions, use the separate `propertyOrders` option rather
than adding a custom JSON keyword. See [structured progress and order](doc/usage.md#structured-snapshots-and-property-order).

F06 adds `nullValue`, `anyOf` and local `reference` constructors on roots and
properties, with a root `definitions` registry. JSON import accepts the same
forms through `type: null`, `anyOf`, root `$defs` and local `$ref`. Optional
absence remains different from a present null value. Null support requires
OS 26.4 and a compatible SDK; references/unions retain OS 26 support.

Read `response.hasStructuredValue` before treating a null root as data. With
explicit presence, a nullable F04 decoder receives null; missing/legacy absent
data still fails. See [graph limits, availability and presence](doc/usage.md#null-anyof-and-local-references).

Use `session.measureTokenBudget` when the selected model supports token counts.
Requests expose typed `termination`, separate first-result, idle and total
deadlines, and optional diagnostic callbacks. Missing usage counters remain
unknown, including unavailable PCC counts. Token estimates alone cannot tell
you whether an answer was truncated. Schema errors identify the failing path.

See [complete contracts](doc/usage.md), [document extraction](doc/document-extraction.md)
and [PCC eligibility and permission](doc/private-cloud-compute.md). The examples
in this documentation update were reviewed against the source but were not
run on a device. The 0.5.0 iOS and macOS examples were compiled with Xcode
27.2 beta; this F01–F10 iteration runs Dart tests and native helper contract tests
without rebuilding or launching either example host.
Dart tests cover every executable library line. Dedicated Swift tests exercise
the production schema/snapshot mappers, history codec, availability monitor and
text-language mapper against Apple frameworks, requiring full helper coverage. These are different scopes: they do not establish model quality,
coverage of every native service, device permissions or entitled PCC generation.

## Choose a bounded task

| Good starting point | Application responsibility |
| --- | --- |
| Summarize or rewrite a short passage | Preserve important facts and let the user review it. |
| Extract a few fields with a schema | Validate amounts, dates, identifiers and business rules. |
| Classify text into a small set of labels | Use enums and handle uncertain results. |
| Invoke a small set of registered tools | Validate arguments, authorization and side effects. |
| Transcribe a file or microphone input | Obtain permissions and choose the Speech privacy mode. |

The local model has a limited context window. Query `contextSize`, count tokens
when supported, and reserve room for instructions, schema, tools and the answer.
File-size limits protect memory; they do **not** mean the file fits the model.
Long documents, factual research, complex reasoning and long autonomous agents
need an application-level strategy. See [API/local integration](doc/app-owned-routing.md).

## Features and compatibility

| Feature | Minimum runtime | Package behavior |
| --- | --- | --- |
| Text, sessions, streaming, tools, structured output | iOS/iPadOS 26, macOS 26 | Native Foundation Models with runtime availability checks. |
| Content tagging and prewarm | iOS/iPadOS 26, macOS 26 | Explicit session use case and `prewarm()`. |
| Local readiness observation and text-model languages | iOS/iPadOS 26, macOS 26 | Observation has no transition-cadence guarantee; polling is explicit. No PCC or Speech request. |
| Native session history export/restore | iOS/iPadOS 26, macOS 26 | Strict same-platform/OS/SDK profile; PCC still requires OS 27 and host approval. |
| Local prompt/instructions/tools/schema/transcript token counts | iOS/iPadOS 26.4, macOS 26.4 | Requires this package to be built with Xcode 27+. |
| Explicit null schemas | iOS/iPadOS 26.4, macOS 26.4 | Xcode 26.4+ / Swift 6.3+ SDK build; anyOf/local refs retain OS 26 support. |
| Usage, reasoning options, explicit tool mode, transcript error policy | iOS/iPadOS 27, macOS 27 | SDK and selected-model support also required. |
| Private Cloud Compute (PCC) | iOS/iPadOS 27, macOS 27 | Explicit policy, host opt-in, Apple's managed entitlement, availability, network and quota. |
| Text/JSON/CSV/Markdown and text PDFs | iOS/iPadOS 26, macOS 26 | Extracted locally and inserted as text. |
| Images | iOS/iPadOS 27, macOS 27 | Local Vision OCR/classification/barcodes; **not native multimodal understanding**. |
| Audio files and live microphone | iOS/iPadOS 15, macOS 12 | SpeechAnalyzer on OS 26+, legacy Speech fallback where supported; OS 27 uses native input providers. |
| CocoaPods and Swift Package Manager | iOS 15, macOS 12 deployment | Both use the shared `darwin/` Swift sources. |

iPadOS uses the iOS plugin target. visionOS and watchOS do not have an official
Flutter deployment target; tvOS also lacks the Foundation Models APIs used here.
See the [platform research and requirements](doc/apple-platforms.md).

Use `getCapabilities()` for the exposed feature set and `checkAvailability()`
for whether generation can run now. `getDiagnostics(localeIdentifier: ...)`
reports local language support. `getSupportedLanguages()` returns the
intersection of model and modern Speech locales, which is useful for a shared
language selector but is not the complete list of text-only model languages.

The [September 19 SDK review](doc/ios-27.2-audit-2026-09-19.md) covers
**Xcode 27.2 beta / Swift 6.4**, including new data attachments and transcript
entries. This package does not expose those additions, Dynamic Profiles,
arbitrary model executors or a Photos picker. The previously crashing native
paths remain disabled pending device evidence.

## Optional app adapters and stream updates

F10 in local 1.9.0 uses a separate import, without adding framework/provider
runtime dependencies:

```dart
import 'package:cupertino_fundations_models/cupertino_fundations_models_adapters.dart';

final adapter = FoundationModelsAdapter(models: models);
var text = '';
final subscription = adapter.stream(prompt: Prompt.text('Summarize supplied text.')).listen((frame) {
  if (frame.textUpdate case final update?) text = update.applyTo(text);
  if (frame.original case CompletionEvent(:final response)) useFinalResponse(response);
}, onError: showRequestError);
await subscription.cancel();
```

Each owned request creates/disposes its own Apple session; existing sessions can
use `session.stream(...).adaptEvents()` with borrowed ownership. Original tools,
snapshots, final responses, nullable counters and failure details remain available.
A revised/shortened snapshot produces replacement, never a false suffix. Consumers
that only accept append can choose `allowReplacements: false` and fail explicitly.

The app chooses external frameworks/providers, schema translation, credentials,
consent and history. Genkit/LangChain recipes are contract guidance rather than
bundled provider plugins. See [lifecycle, metadata and integration recipes](doc/usage.md#optional-adapters-and-stream-updates).

## Optional Dart generation

F09 in local 1.9.0 adds `cupertino_fundations_models_generator` as a separate
**dev dependency**. The core adds its own dependency-free `StructuredModel` and
`StructuredField` annotations; it does not depend on the generator or build tools.
Manual constructors and JSON Schema import remain available.

Annotate one concrete model per source library under `lib/`, with public final
fields and a public generative constructor whose named parameters match them.
Explicitly run `dart run build_runner build` to create `model.structured.dart`.
Import that companion and use `ModelCodec.schema`, `ModelCodec.decode` or
`ModelPartial.fromSnapshot(snapshot)`. No `part` directive or Swift generation is
needed. Each partial field exposes presence, completeness and safe value separately.

The initial profile covers primitives, enums, lists, annotated nested models and
nullable choices; unsupported forms fail with source diagnostics. Generated final
conversion checks structure, not native guides or business truth. Generation does
not issue model requests, acquire assets or change local/PCC policy. See
[local installation, full profile and examples](doc/usage.md#optional-dart-generation).
An integrating coding agent asks once which definition route the user wants when
that choice is missing; it respects a previous manual/generated choice.

## Observe local availability and query text languages

F08 in local 1.9.0 keeps a local readiness display current without issuing a
model request:

```dart
final languages = await models.getTextModelLanguages();
final subscription = models.watchAvailability(localeIdentifier: 'es_CO').listen(
  (availability) => updateReadiness(availability),
  onError: (Object error) => showAvailabilityError(error),
);
// When the feature owner finishes:
await subscription.cancel();
```

Use `useCase: FoundationModelsUseCase.contentTagging` for that local variant.
`watchAvailability` emits the initial active snapshot and meaningful changes,
stops work while paused or outside foreground, and rechecks on resume. Native
Observation is the default; `pollingInterval: Duration(seconds: 15)` explicitly
selects bounded polling instead. Neither mode requests generation, model downloads,
Speech permissions or PCC. Readiness can change before a request.

`TextModelLanguage` has native identifiers and localized labels, with no Speech
asset flag. Advertised languages are not every regional locale accepted by the
model, nor proof that it is ready. `getSupportedLanguages()` keeps its existing
model/Speech intersection for apps using dictation. See [full lifecycle, errors and
language contract](doc/usage.md#observable-local-availability-and-text-languages).

## Export and restore session history

F07 in local 1.9.0 can retain native conversation context explicitly:

```dart
final snapshot = await session.exportHistory();
final json = snapshot.toJson();
await session.dispose();
final restored = await models.restoreSession(
  history: SessionHistory.fromJson(json),
  tools: currentTools,
);
try {
  final response = await restored.respond(Prompt.text('Continue our conversation.'));
} finally {
  await restored.dispose();
}
```

Export requires an idle session. The immutable descriptors are inspectable; the
native Codable archive also retains SDK options, formats and metadata. Restoring
creates a new session without invoking historical tool callbacks. Register current
implementations with the same tool definitions; PCC needs explicit cloud permission.
The app owns storage, account/thread selection, encryption and retention.

The initial profile requires the same platform, exact OS version and known build
SDK identifier, route, variant, locale and tool registrations. It accepts bounded
text/complete structured content, completed tools and OS 27 reasoning; it rejects
attachments, binary data and incomplete/pending content. It does not support editing
or replaying descriptors as a transcript. See [limits, errors and ownership](doc/usage.md#export-and-restore-session-history).

## Sessions and streaming

Use `models.respond()` for independent tasks. Reuse a session only when prior
turns are needed; its transcript lasts until disposal. F07 allows explicit export
and restoration; the package never persists it automatically.

```dart
final models = CupertinoFoundationModels();
final session = await models.createSession(
  options: const SessionOptions(
    mode: ModelMode.local,
    cloudPolicy: CloudPolicy.never,
    localeIdentifier: 'en_US',
    instructions: 'Answer briefly in English using the supplied information.',
  ),
);
try {
  await for (final event in session.stream(
    const Prompt.text('Suggest three names for a gardening journal.'),
    options: const GenerationOptions(maximumResponseTokens: 120),
  )) {
    switch (event) {
      case TextSnapshotEvent():
        print(event.text);
      case CompletionEvent():
        print(event.response.usedMode);
      case FailureEvent():
        print(event.message);
      case ToolCallEvent():
      case UnknownSessionEvent():
        break;
    }
  }
} on FoundationModelsException catch (error) {
  print(error.code);
} finally {
  await session.dispose();
}
```

A session is single-flight. Await request completion or cancellation before
reusing it. Separate sessions can stream concurrently, including sessions from
different `CupertinoFoundationModels` facades. Await stream subscription
cancellation and `dispose()`; neither undoes side effects in your Dart tools.

For guided streaming, use `streamStructured`, or pass `schema` to `stream`.
Each `TextSnapshotEvent.text` is the latest cumulative JSON snapshot, so replace
displayed text instead of appending or treating it as final data. The terminal
`CompletionEvent.response` contains the complete JSON string and decoded
`structuredValue`; an incomplete or undecodable final snapshot fails with
`parsingFailure`.

```dart
final structuredSession = await models.createSession(
  options: const SessionOptions(mode: ModelMode.local),
);
try {
  await for (final event in structuredSession.streamStructured(
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
    if (event case CompletionEvent(:final response)) {
      final appointment = response.structuredValue;
      print(appointment);
    }
  }
} finally {
  await structuredSession.dispose();
}
```

Guided streaming requires iOS/iPadOS 26+ or macOS 26+ and the same Apple Intelligence
availability as other generation. PCC additionally requires OS 27, the host opt-in and
Apple's managed entitlement.

See the [usage reference](doc/usage.md) for structured generation, tools,
attachments, token usage, Speech and the complete option behavior.

## Privacy and setup

The default model policy is local. There is no API client, API key storage,
hybrid router or automatic external-provider fallback in 0.3.0 and later.

| Selection | Result |
| --- | --- |
| `local` + any cloud policy | On-device generation. |
| `automatic` + `never` or `whenExplicit` | On-device generation. |
| `privateCloudCompute` + `never` | Rejected before PCC initialization. |
| `privateCloudCompute` + `whenExplicit` | Explicit PCC request; no generation fallback. |
| `automatic` + `automaticWithUserConsent` | PCC may be selected at session creation if available; otherwise local. The app must obtain consent. |

`GenerationOptions.cloudPolicy` is an optional restriction on an already
selected session: `null` inherits it, `never` rejects a request on a PCC session.
It cannot switch models or authorize a new cloud route.

For Speech, add the usage descriptions your app needs:

```xml
<key>NSSpeechRecognitionUsageDescription</key>
<string>Transcribe audio selected by the user.</string>
<key>NSMicrophoneUsageDescription</key>
<string>Transcribe speech while the microphone is enabled.</string>
```

File transcription needs the Speech key; live transcription needs both.
`AudioTranscriptionMode.onDevice` is the default. `automatic` permits a legacy
server fallback, and `server` permits Apple Speech networking. **Speech server
recognition is separate from PCC.** Model and Speech asset downloads can require
network even when inference is on-device.

On a sandboxed Mac host, configure user-selected file access and audio input
for those features. Server Speech also needs outgoing network access. See the
[macOS entitlements and example](doc/apple-platforms.md#macos-host-setup).

For PCC, first follow the [eligibility, entitlement request and signing guide](doc/private-cloud-compute.md).
Apple approval and correctly signed host provisioning are required before
enabling this separate package flag:

```xml
<key>CupertinoFoundationModelsPrivateCloudComputeEnabled</key>
<true/>
```

The flag defaults to false and is only an application configuration guard; it
neither grants nor verifies the signing entitlement. PCC generation has not been
validated in this example. The package keeps the previously unsafe PCC
language/capability getters and native image attachment path disabled.

## Documentation

- [Local AI for Flutter iOS: installation and first response](doc/local-ai-ios.md)
- [Apple platform compatibility and macOS setup](doc/apple-platforms.md)
- [Guía en español: IA local nativa de Apple con Flutter](doc/README.es.md)
- [Summarization, structured extraction and classification recipes](doc/recipes.md)
- [FAQ: offline AI, devices, privacy and platform support](doc/faq.md)
- [Choosing Apple Foundation Models, a custom model or a cloud API](doc/choosing-local-ai.md)
- [Usage and feature contracts](doc/usage.md)
- [PCC eligibility, requesting access and host setup](doc/private-cloud-compute.md)
- [Known failures, fixes and recovery](doc/troubleshooting.md)
- [API agent plus local model: app-owned routing](doc/app-owned-routing.md)
- [Migration from 0.2.x](doc/migration-0.3.0.md)
- [Implementation guide for coding agents](implementation_for_agents.md)
- [iOS 27.2 audit and release readiness](doc/ios-27.2-audit-2026-09-19.md)
- [Example app](example/README.md) · [Changelog](CHANGELOG.md)
- [Report an issue](https://github.com/sooyvilla/cupertino_fundations_models/issues)

The published identifier keeps the spelling `cupertino_fundations_models`
so existing imports continue to work. Cupertino Foundation Models is an
independent, MIT-licensed project maintained by Sebastián Villa.

## Common questions

### Is this a local AI or offline LLM library for iOS?

Yes: `ModelMode.local` with `CloudPolicy.never` selects Apple's on-device
Foundation Models. Generation can run offline when Apple Intelligence and the
required assets are available. The package does not ship an LLM model file.

### Can I use Apple Intelligence from Flutter without writing Swift?

Yes. Import `package:cupertino_fundations_models/cupertino_fundations_models.dart`
and use the typed Dart facade. The plugin supplies the native Swift bridge.
You still need an iOS or macOS host built with an appropriate Apple SDK.

### Does this support every iPhone or an app written only in Swift?

No. This Flutter plugin supports iOS/iPadOS and macOS in repository source;
it is not a standalone Swift SDK and does not support Android or web.
Generation requires OS 26+, an eligible
Apple Intelligence device, language/region support, enabled settings and assets.
Use `checkAvailability()` rather than a hard-coded list of device models.

### Are local AI and Private Cloud Compute the same?

No. PCC is an optional Apple cloud route with iOS/iPadOS 27 or macOS 27, entitlement, signing,
policy, consent and availability requirements. Local generation does not need
PCC approval. Speech server recognition has its own privacy policy.

### ¿Cómo integrar IA local en una app Flutter para iOS?

La [guía en español](doc/README.es.md) explica cómo integrar esta librería Flutter
con IA local nativa de Apple, comprobar disponibilidad y obtener una respuesta.

## Project and upstream references

- [Apple Foundation Models framework](https://developer.apple.com/documentation/foundationmodels)
- [Package versions and release notes](https://pub.dev/packages/cupertino_fundations_models/versions)
- [Contributing](CONTRIBUTING.md) and [issue tracker](https://github.com/sooyvilla/cupertino_fundations_models/issues)

If the package helps your app, a pub.dev like, GitHub star or issue with a
reproducible integration problem helps other developers assess and improve it.

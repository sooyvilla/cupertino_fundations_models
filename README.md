# Cupertino Foundation Models — local AI for Flutter iOS

[![pub.dev](https://img.shields.io/pub/v/cupertino_fundations_models.svg)](https://pub.dev/packages/cupertino_fundations_models)
[![pub points](https://img.shields.io/pub/points/cupertino_fundations_models)](https://pub.dev/packages/cupertino_fundations_models/score)
[![MIT license](https://img.shields.io/badge/license-MIT-blue)](LICENSE)

Use Apple's **Foundation Models** from Dart to summarize text, rewrite a
message, extract structured fields or classify content in your Flutter iOS app.
The plugin connects directly to the native framework through Swift, with
sessions, streaming, guided JSON and tools you define in your app.

Local generation runs on the device without an API key. Apple supplies the
model, so you do not need to bundle your own weights. The package also includes
file and live speech-to-text through Apple **Speech**, supports CocoaPods and
Swift Package Manager, and adds no third-party runtime dependencies.

[Documentation](https://sooyvilla.github.io/cupertino_fundations_models/) ·
[Start with local AI on iOS](doc/local-ai-ios.md) ·
[Español: inteligencia artificial local para iOS](doc/README.es.md) ·
[Recipes](doc/recipes.md) · [FAQ](doc/faq.md) ·
[API reference](https://pub.dev/documentation/cupertino_fundations_models/latest/)

**iOS only.** Generation needs iOS 26+, an eligible device, Apple Intelligence
and downloaded model assets. The plugin can be included in an iOS 15+ app;
that deployment target does not make generation available on older systems.
On-device inference can work offline after Apple's required model assets are
available; initial downloads and optional cloud/Speech modes can need network.

## What you can build

| Need | What this package provides |
| --- | --- |
| Local text features | Dart APIs backed directly by native Foundation Models sessions. |
| Extract fields into JSON | `StructuredSchema`, guided generation and decoded final output. |
| Streaming with a defined lifecycle | Cumulative snapshots, terminal results, cancellation and session disposal. |
| App-defined tool calling | Typed tool registration; your app owns argument validation and authorization. |
| A clear local/cloud boundary | Explicit local mode and `CloudPolicy.never`; PCC requires a separate opt-in. |
| Integration without a custom Swift bridge | Public Dart API, an example app, compatibility tables and recovery guides. |

Start with short, well-defined tasks on eligible iOS devices. If your app needs
other platforms, custom models or a cloud API, read
[choosing a local AI approach](doc/choosing-local-ai.md).

**Version 0.4.0 makes missing usage counters nullable.** Read the
[0.4.0 migration guide](doc/migration-0.4.0.md) for usage, lifecycle and transport
changes. Version 0.3.0 removed hybrid routing; read the
[migration guide](doc/migration-0.3.0.md) before upgrading from 0.2.x.

## Quick start

Use Flutter 3.41+ and Dart 3.11+. Add:

```sh
flutter pub add cupertino_fundations_models
```

Or declare the dependency directly:

```yaml
dependencies:
  cupertino_fundations_models: ^0.4.4
```

The [example app](example/pubspec.yaml) uses a local path dependency to run
against the checked-out source.

Rebuild the iOS host after adding or upgrading the plugin; hot reload cannot
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

Use `session.measureTokenBudget` when the selected model supports token counts.
Requests expose typed `termination`, separate first-result, idle and total
deadlines, and optional diagnostic callbacks. Missing usage counters remain
unknown, including unavailable PCC counts. Token estimates alone cannot tell
you whether an answer was truncated. Schema errors identify the failing path.

See [complete contracts](doc/usage.md), [document extraction](doc/document-extraction.md)
and [PCC eligibility and permission](doc/private-cloud-compute.md). The examples
in this documentation update were reviewed against the source but were not
run on a device. Physical iPhone and PCC verification remain pending.

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
| Text, sessions, streaming, tools, structured output | iOS 26 | Native Foundation Models with runtime availability checks. |
| Content tagging and prewarm | iOS 26 | Explicit session use case and `prewarm()`. |
| Local prompt/instructions/tools/schema/transcript token counts | iOS 26.4 | Requires this package to be built with Xcode 27+. |
| Usage, reasoning options, explicit tool mode, transcript error policy | iOS 27 | SDK and selected-model support also required. |
| Private Cloud Compute (PCC) | iOS 27 | Explicit policy, host opt-in, Apple's managed entitlement, availability, network and quota. |
| Text/JSON/CSV/Markdown and text PDFs | iOS 26 | Extracted locally and inserted as text. |
| Images | iOS 27 | Local Vision OCR/classification/barcodes; **not native multimodal understanding**. |
| Audio files and live microphone | iOS 15 | SpeechAnalyzer on iOS 26+, legacy Speech fallback where supported; iOS 27 uses native input providers. |
| CocoaPods and Swift Package Manager | iOS 15 deployment | Both use the same Swift sources. |

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

## Sessions and streaming

Use `models.respond()` for independent tasks. Reuse a session only when prior
turns are needed; its transcript lasts until disposal and is not persisted.

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

Guided streaming requires iOS 26+ and the same Apple Intelligence availability
as other generation. PCC additionally requires iOS 27, the host opt-in and
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
- [Guía en español: IA local nativa para iOS con Flutter](doc/README.es.md)
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
You still need an iOS host built with an appropriate Apple SDK.

### Does this support every iPhone or an app written only in Swift?

No. This is a Flutter plugin for iOS; it is not a standalone Swift SDK and does
not support Android, macOS or web. Generation requires iOS 26+, an eligible
Apple Intelligence device, language/region support, enabled settings and assets.
Use `checkAvailability()` rather than a hard-coded list of iPhone models.

### Are local AI and Private Cloud Compute the same?

No. PCC is an optional Apple cloud route with iOS 27, entitlement, signing,
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

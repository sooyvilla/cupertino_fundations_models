# Cupertino Foundation Models for Flutter

Run small AI tasks on an Apple device: summarize short text, rewrite a message,
extract structured fields, classify content, or call a few app-defined tools.
The plugin bridges Apple's **Foundation Models** and **Speech** frameworks with
no third-party runtime dependencies.

**iOS only.** Generation needs iOS 26+, an eligible device, Apple Intelligence
and downloaded model assets. The plugin can be included in an iOS 15+ app;
that deployment target does not make generation available on older systems.

**Version 0.3.0 removes hybrid routing.** Read the
[migration guide](doc/migration-0.3.0.md) before upgrading from 0.2.x.

## Quick start

Use Flutter 3.41+ and Dart 3.11+. Add:

```yaml
dependencies:
  cupertino_fundations_models: ^0.3.1
```

The [example app](example/pubspec.yaml) uses a local path dependency to run
against the checked-out source.

When upgrading, resolve the app's dependency lockfile to 0.3.1 or later and
rebuild the iOS host: guided streaming changes the native plugin, so hot reload
alone is insufficient. Existing text streams remain available; requesting JSON
in a prompt does not enable schema guidance.

```dart
import 'package:cupertino_fundations_models/cupertino_fundations_models.dart';

Future<String?> summarize(String shortText) async {
  final models = CupertinoFoundationModels();
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
}
```

Availability can change after a preflight. Handle
`FoundationModelsException` around the request and provide a manual path when
the model is unavailable. Model output still needs application validation.

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
| Local prompt/transcript token counts | iOS 26.4 | Requires this package to be built with Xcode 27+. |
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

The installed **Xcode 27.2 beta / Swift 6.4** SDK was inspected for this update.
New iOS 27.2 data attachments and transcript data entries are documented in the
[SDK audit](doc/ios-27.2-audit-2026-09-19.md); this package does not expose them,
Dynamic Profiles, arbitrary model executors, or a Photos picker. A newer SDK
does not prove that previously crashing native APIs are safe on a device.

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
hybrid router or automatic external-provider fallback in 0.3.x.

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

- [Usage and feature contracts](doc/usage.md)
- [PCC eligibility, requesting access and host setup](doc/private-cloud-compute.md)
- [Known failures, fixes and recovery](doc/troubleshooting.md)
- [API agent plus local model: app-owned routing](doc/app-owned-routing.md)
- [Migration from 0.2.x](doc/migration-0.3.0.md)
- [Implementation guide for coding agents](implementation_for_agents.md)
- [iOS 27.2 audit and release readiness](doc/ios-27.2-audit-2026-09-19.md)
- [Example app](example/README.md) · [Changelog](CHANGELOG.md)
- [Report an issue](https://github.com/sooyvilla/cupertino_fundations_models/issues)

The published package identifier intentionally remains
`cupertino_fundations_models` for compatibility with existing imports.

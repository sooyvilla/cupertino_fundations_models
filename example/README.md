# Flutter iOS, iPadOS and macOS local AI example — Apple Foundation Models

A Flutter chat using the local 1.9.0 path dependency, including F01 constrained
extraction, F02 nested required-field choices, F03 JSON Schema import and F04 typed
final conversion with the original response retained. F05 adds optional native
structured progress and explicit per-object order. F06 adds nullable/local-reference
choices and F07 adds explicit native history export/restoration. F08 observes local
readiness and independently queries text-model languages. This version is prepared locally
and has not been published.
For apps
using the earlier hybrid API, see the [migration guide](../doc/migration-0.3.0.md).

For an availability-checked first integration, start with
[local AI on iOS](../doc/local-ai-ios.md), the
[guía en español](../doc/README.es.md) or the
[structured extraction and classification recipes](../doc/recipes.md).
The package identifier is `cupertino_fundations_models`.

- Persistent Apple on-device session, cumulative streaming snapshots and a
  bounded `DeviceTimeTool`. Apps can also call `session.streamStructured(...)`
  with `StructuredSchema.object(...)`; snapshots are cumulative partial JSON
  and only the completion response is decoded final data.
- Explicit Private Cloud Compute selection; local generation is the default.
- Live Speech transcription with separate on-device/automatic/server choices.
- Shared language selection, availability diagnostics and typed error display.
- Text/PDF extraction and Vision-backed image context through the document picker.
- Request cancellation, draft recovery and serialized session disposal.

Sources: [chat](lib/main.dart) and [document extraction](lib/document_extraction.dart).
The document stream demonstrates schema guidance, per-component token budgets,
separate deadlines and optional diagnostics using fictitious Spanish amounts.
F01 limits extraction to at most 50 rows, positive source row numbers and an
explicit currency-code/unknown vocabulary. It does not force a row count or
validate the truth or coverage of extracted records.
F02 allows each row to omit `dateText` when no date was supplied, keeping
sourceRow, description and amountText required. Output roots can also be lists
or scalar values; the chat's document demo keeps its existing object shape.
F03 imports the document schema as data, explicitly closes each object and opts
into Swift patterns. The row limits and required/optional choices are preserved.
F04 adds `extractDocumentDecoded` as a one-shot alternative with app-owned
`ExtractedDocument`/`ExtractedDocumentRow` decoders. The value retains original
amount/date strings; `.response` retains native metadata and nullable usage.
The existing chat stream remains available. See the
[typed final example](../doc/document-extraction.md#typed-final-document).
F05 gives the schema explicit root/row property orders. Pass
`includeStructuredSnapshots: true` to `extractDocument` to receive native
projections in its existing text snapshot events. Defaults and chat behavior
stay unchanged; partial data must be replaced and final conversion waits for
completion. See [structured progress](../doc/document-extraction.md#structured-progress).
See its [integration guide](../doc/document-extraction.md) and the
[0.4.0 migration](../doc/migration-0.4.0.md). Usage counters are nullable and
successful stream completion has no inferred native stop reason.

Source: [lib/main.dart](lib/main.dart). External API routing belongs to the host
application; there is no Gemini client or provider key in this example.

F06 reuses $defs/DocumentRow through a local $ref. Default date omission stays
unchanged; explicitNullDates:true selects a required nullable date and native
null support. The original response preserves absent versus present null.
See [null-date mode](../doc/document-extraction.md#optional-explicit-null-dates).

F07 adds `extractDocumentWithHistory` as an explicit local alternative: it returns
the decoded final result plus an immutable `SessionHistory`, exporting before
its session is disposed. It does not store anything or change the chat defaults.
See [history example and compatibility](../doc/document-extraction.md#explicit-history-alternative)
and [full history contract](../doc/usage.md#export-and-restore-session-history).

F08 connects `watchAvailability` to the chat's existing local-readiness banner.
Refreshing or changing language cancels the previous watch and ignores stale
checks; disposal releases the subscription. Observation is the default and work
pauses outside foreground. The chat keeps the existing model/Speech language
intersection because it supports dictation. For text-only apps:

```dart
final choices = await models.getTextModelLanguages();
final subscription = models.watchAvailability(localeIdentifier: 'es_CO').listen(
  updateReadiness, onError: showReadinessError,
);
await subscription.cancel();
```

Choose explicit bounded polling only if needed. These APIs do not initiate
sessions, inference, downloads, Speech permissions or PCC. See
[monitoring, unsupported-host states and cleanup](../doc/usage.md#observable-local-availability-and-text-languages).

## Optional application backend

F10 adds [AppTextBackend](lib/app_text_backend.dart) and
[AppleTextBackend](lib/apple_text_backend.dart) as an app-owned interface example.
It delegates owned requests to FoundationModelsAdapter, defaults local/never,
and retains raw ModelResponse/AdaptedSessionEvent. No framework or remote provider
is installed. The existing chat can keep cumulative snapshots directly.
TextUpdate supplies append/replace/fullText; borrowed adaptEvents preserves session
ownership. See [contract and framework recipes](../doc/usage.md#optional-adapters-and-stream-updates).

## Optional generated companions

F09 adds annotated [GeneratedDocument](lib/generated_document.dart), row and
[choice model](lib/generated_generation_choices.dart) alternatives. Their checked-in
*.structured.dart files are created by the separate generator; chat/manual/import
examples retain their current route. Local pubspec_overrides.yaml points to core
and the generator in this repository. After choosing the generated route, run:

```sh
flutter pub get
dart run build_runner build
```

This generates Dart companions, not a native app. Use ClassCodec.schema/decode
with existing generation/response APIs and ClassPartial for display-only F05
snapshots. Final amount/date strings and metadata remain unchanged. The profile
is bounded and explicit null still needs OS26.4. See
[setup and field semantics](../doc/usage.md#optional-dart-generation). Core 1.9.0 and
compatible generator 1.8.0 are prepared locally, not published; the core workflow does not
publish the companion automatically.

## Setup

Use Flutter 3.41+/Dart 3.11+, an Apple Intelligence-capable device with its model
ready, and a suitable Xcode SDK. Generation needs iOS/iPadOS 26+ or macOS 26+,
token counts need OS 26.4+, and PCC/new tool modes need OS 27+. F01 numeric,
string and array guides use OS 26 APIs. The current iteration executes library
Dart tests and native helper contract tests without rebuilding or launching this
example. Historical build results do not validate the changed application.

The example includes the Speech and microphone usage descriptions. Grant those
permissions only when using dictation. On-device Speech assets may need an initial
download. Choosing an Apple Speech server mode is independent of PCC selection.

For PCC, follow the [eligibility and entitlement request guide](../doc/private-cloud-compute.md),
obtain Apple's managed entitlement, configure signing and explicitly
set `CupertinoFoundationModelsPrivateCloudComputeEnabled` in the host Info.plist.
The example leaves this flag off; changing it does not grant the entitlement.
Consult the [package setup](../README.md) before enabling it.
Apple's published PCC testing routes are TestFlight and ad hoc distribution;
the local `flutter run` instructions below do not establish PCC eligibility.

From the example directory, on your own device when you choose to run it:

```bash
flutter pub get
flutter run
```

No API key is needed for local generation. A simulator is not a substitute for
validating Apple Intelligence, microphone, assets, permissions or PCC on a device.

## macOS host

The repository includes `macos/Runner.xcworkspace`, a macOS 12 deployment
configuration and the same Dart example used on iPhone/iPad. Model generation
requires macOS 26+ and native Apple Intelligence availability. The plugin's
macOS support starts in 0.5.0; the path dependency uses the checked-out source.

Both Debug/Profile and Release entitlements allow microphone input, reading
user-selected files and outgoing network access for the demo's optional server
Speech mode. The Info.plist contains Speech/microphone usage descriptions and
keeps PCC opt-in disabled. See [Mac setup and platform research](../doc/apple-platforms.md).

When you choose to run it yourself, from this directory:

```bash
flutter pub get
flutter run -d macos
```

The 0.5.0 Mac Debug and unsigned iOS Release hosts were compiled with Xcode 27.2
beta and Flutter 3.47.5. The current F01–F10 tests cover Dart and the production Swift
schema/snapshot mappers, history codec, availability monitor and language mapper, not every native service or model response. Permission prompts,
model/Speech readiness and entitled PCC remain separate runtime checks.

## Behavior and limits

A route/language change resets the native conversation. One session accepts one
request at a time. Images are preprocessed with Vision into text; native image
Attachment calls are disabled. Large documents need application-side chunking.
This sample is not an autonomous agent or a tool authorization framework.
Guided streaming needs iOS/iPadOS 26+ or macOS 26+; PCC keeps its OS 27 host opt-in and
managed-entitlement requirements.

The existing `CFM_SMOKE_TEST` entry point is an **opt-in device harness**, not
normal app startup and not evidence that current tests passed. It runs only when
explicitly enabled with `--dart-define=CFM_SMOKE_TEST=true`. It was not executed
during the September 19 audit. Do not enable it in distributed application builds.

See [known failures and recovery](../doc/troubleshooting.md) and the
[historical SDK review](../doc/ios-27.2-audit-2026-09-19.md) for its evidence boundaries.

# Flutter iOS, iPadOS and macOS local AI example — Apple Foundation Models

A Flutter chat demonstrating the native Apple API in version 0.5.0. For apps
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
See its [integration guide](../doc/document-extraction.md) and the
[0.4.0 migration](../doc/migration-0.4.0.md). Usage counters are nullable and
successful stream completion has no inferred native stop reason.

Source: [lib/main.dart](lib/main.dart). External API routing belongs to the host
application; there is no Gemini client or provider key in this example.

## Setup

Use Flutter 3.41+/Dart 3.11+, an Apple Intelligence-capable device with its model
ready, and a suitable Xcode SDK. Generation needs iOS/iPadOS 26+ or macOS 26+,
token counts need OS 26.4+, and PCC/new tool modes need OS 27+. Earlier releases were compiled with Xcode
27.2 beta. Version 0.4.0 has source review only, without a new build or runtime
validation; prior results do not validate the changed source.

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

The Mac Debug host and the unsigned iOS Release host compile with Xcode 27.2
beta and Flutter 3.47.5. Neither app was launched for this integration. Permission
prompts, model/Speech readiness and entitled PCC remain unverified on Mac.
Dart unit coverage does not measure the native Swift bridge.

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
[current audit](../doc/ios-27.2-audit-2026-09-19.md) for evidence boundaries.

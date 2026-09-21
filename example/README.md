# Apple native example

A Flutter chat demonstrating the native Apple API in version 0.3.1. For apps
using the earlier hybrid API, see the [migration guide](../doc/migration-0.3.0.md).

- Persistent Apple on-device session, cumulative streaming snapshots and a
  bounded `DeviceTimeTool`. Apps can also call `session.streamStructured(...)`
  with `StructuredSchema.object(...)`; snapshots are cumulative partial JSON
  and only the completion response is decoded final data.
- Explicit Private Cloud Compute selection; local generation is the default.
- Live Speech transcription with separate on-device/automatic/server choices.
- Shared language selection, availability diagnostics and typed error display.
- Text/PDF extraction and Vision-backed image context through the document picker.
- Request cancellation, draft recovery and serialized session disposal.

Source: [lib/main.dart](lib/main.dart). External API routing belongs to the host
application; there is no Gemini client or provider key in this example.

## Setup

Use Flutter 3.41+/Dart 3.11+, an Apple Intelligence-capable device with its model
ready, and a suitable Xcode SDK. Generation needs iOS 26+, token counts need
26.4+, and PCC/new tool modes need iOS 27+. Development was compiled with Xcode
27.2 beta; this does not establish runtime compatibility with every OS version.

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

## Behavior and limits

A route/language change resets the native conversation. One session accepts one
request at a time. Images are preprocessed with Vision into text; native image
Attachment calls are disabled. Large documents need application-side chunking.
This sample is not an autonomous agent or a tool authorization framework.
Guided streaming needs iOS 26+; PCC keeps its existing iOS 27 host opt-in and
managed-entitlement requirements.

The existing `CFM_SMOKE_TEST` entry point is an **opt-in device harness**, not
normal app startup and not evidence that current tests passed. It runs only when
explicitly enabled with `--dart-define=CFM_SMOKE_TEST=true`. It was not executed
during the September 19 audit. Do not enable it in distributed application builds.

See [known failures and recovery](../doc/troubleshooting.md) and the
[current audit](../doc/ios-27.2-audit-2026-09-19.md) for evidence boundaries.

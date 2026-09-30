# Promotion kit — reviewable drafts, not published messages

Prepared September 30, 2026. These drafts accompany the 0.4.4 documentation
release. The documentation site is live; confirm the package upload before
using the version in a post. The maintainer should
review the voice and channel rules before any message is sent.

## Core message

Native Apple Foundation Models for Flutter iOS: local text generation,
structured JSON, streaming and app-defined tools through a Dart API and Swift
bridge. No API key for local generation. Eligible Apple Intelligence devices
and iOS 26+ required. Speech has a separate privacy setting; PCC is optional.

The package identifier is `cupertino_fundations_models`. The human-readable
name is Cupertino Foundation Models. Keep both consistent across channels.
Do not claim Apple endorsement, every-iPhone support, cross-platform support,
unrestricted image reasoning, benchmark superiority or guaranteed offline setup.

## Launch post for a Flutter developer community

**Title:** Apple-native local AI in Flutter iOS: guided JSON, streaming and a Dart API

I maintain `cupertino_fundations_models`, an MIT-licensed Flutter iOS plugin
for Apple's Foundation Models framework. It gives Dart apps native on-device
text generation, guided structured output, sessions, streaming and app-defined
tool calling, without an API key for local generation.

The documentation now includes an availability-checked first response,
English/Spanish setup guides, structured extraction/classification recipes,
and explicit lifecycle and privacy contracts. Streams expose cumulative
snapshots and a terminal result; the app owns validation and tool side effects.

It is iOS-only: generation needs iOS 26+, an eligible Apple Intelligence device,
supported settings/locale and downloaded assets. The iOS 15 plugin deployment
target does not make generation available on older systems. Local inference
can work offline once assets are ready; Speech and optional PCC have separate
requirements.

[Package](https://pub.dev/packages/cupertino_fundations_models) ·
[Source and guides](https://github.com/sooyvilla/cupertino_fundations_models)

What bounded task would you integrate first: summaries, classification or
structured extraction? Reproducible integration issues are useful feedback.

## Spanish launch post

**Título:** IA local nativa de Apple para Flutter iOS, desde Dart

Mantengo `cupertino_fundations_models`, una librería MIT que conecta Flutter
con Foundation Models de Apple mediante un puente Swift. Permite resumir,
reescribir, clasificar y extraer JSON estructurado, con streaming y herramientas
definidas por tu app. La generación local no requiere API key.

Preparé una guía en español con instalación, disponibilidad, manejo de errores
y liberación de sesiones, junto con ejemplos de extracción y clasificación.
Tu app conserva la validación de los datos y la autorización de sus herramientas.

La generación exige iOS 26+, un dispositivo apto para Apple Intelligence y los
recursos del modelo disponibles. No admite Android, macOS o web. La inferencia
local puede funcionar sin internet después de descargar los recursos; Speech
y Private Cloud Compute tienen políticas y requisitos separados.

[Paquete](https://pub.dev/packages/cupertino_fundations_models) ·
[Código y documentación](https://github.com/sooyvilla/cupertino_fundations_models)

## Short professional-network post

Apple-native local AI in a Flutter iOS app, from Dart:
`cupertino_fundations_models` exposes Foundation Models sessions, guided JSON,
streaming and app-defined tools. No API key for local generation. iOS 26+ and
Apple Intelligence availability required. New integration guides cover
availability, privacy and output validation in English and Spanish.

[Start with the package](https://pub.dev/packages/cupertino_fundations_models)

## Developer article draft

**Title:** Add local AI to Flutter iOS without maintaining your own Foundation Models bridge

**Description:** An availability-first integration using Cupertino Foundation
Models, with explicit local privacy, schema-guided JSON and session cleanup.

Adding an AI feature to a mobile app starts with a small task. A short summary,
a category suggestion or extraction of two supplied fields is easier to assess
than a general chatbot that promises to know everything. On eligible iOS
devices, Apple's Foundation Models framework provides an on-device model for
language tasks. A Flutter application needs a native bridge to use it.

`cupertino_fundations_models` supplies that bridge and a typed Dart API. Install
it with `flutter pub add cupertino_fundations_models`, then check
`checkAvailability()` for the intended mode and locale. A device running a new
iOS version is not enough: Apple Intelligence settings, supported hardware,
locale and model assets also affect availability.

For local-only generation, explicitly use `ModelMode.local` and
`CloudPolicy.never`. That path needs no external AI API key. It does not,
however, make every feature offline. Apple may need network for initial assets;
your own tools may call a backend; Speech has its own local/server selection.
These boundaries should be visible in the product's behavior and consent.

The [first-response guide](https://github.com/sooyvilla/cupertino_fundations_models/blob/main/doc/local-ai-ios.md)
shows availability checking, a bounded summary request, typed exception
handling and session disposal. When a model is unavailable, retain a useful
manual path. A preflight can succeed and the subsequent request can still fail,
so request-level errors remain part of the integration.

For extraction, provide `StructuredSchema` to `generateStructured()` rather
than simply writing “return JSON” in the prompt. The
[task recipes](https://github.com/sooyvilla/cupertino_fundations_models/blob/main/doc/recipes.md)
include a person/day extraction and a classification vocabulary with an
`other` label. Schema guidance constrains structure; it does not prove facts,
dates, amounts or domain decisions. Check the result against the supplied input
before persisting anything consequential.

For a responsive UI, use a retained session's stream. Its text snapshots are
cumulative, so replace displayed text rather than appending each snapshot.
Only the completion response is final, especially with guided JSON. Dispose
owned sessions and await cancellation cleanup before reusing them. Tool side
effects are your application's responsibility; cancelling the model does not
undo a database write.

This package targets Flutter **iOS**. For a Swift-only app, use Apple's
framework directly. For custom weights or other platforms, assess a runtime
that actually implements those requirements. An optional PCC path has separate
entitlement, signing, policy and runtime conditions; it is not a prerequisite
for local AI and it is not an automatic external-provider fallback.

The useful next step is one bounded feature with a clear manual fallback and
an independently checked result. The
[package](https://pub.dev/packages/cupertino_fundations_models),
[example](https://github.com/sooyvilla/cupertino_fundations_models/tree/main/example)
and [FAQ](https://github.com/sooyvilla/cupertino_fundations_models/blob/main/doc/faq.md)
provide the contracts. These documentation snippets are not a device benchmark
or a claim that every supported path has been physically validated.

## Distribution order

| Channel | Concrete material | Condition before posting/submitting |
| --- | --- | --- |
| GitHub repository | Prepared About text/topics, source, documentation link | Apply settings only with authorization; homepage must be live. |
| pub.dev | README, topic, description, included public guides | Publish a new version; existing archives cannot be overwritten. |
| r/FlutterDev | Developer launch draft with exact limits and package link | Review current community rules; disclose maintainer role; explicit posting authorization. |
| DEV / Hashnode / personal blog | Article draft plus linked working source | Account access and publishing authorization; avoid mass duplicate promotion. |
| LinkedIn / X | Short professional-network draft | Owner's account and explicit posting authorization. |
| Flutter Gems | Accurate package submission | Use the current submission link from [Flutter Gems](https://fluttergems.dev/); directory acceptance is independent. |
| Awesome Flutter | Future candidate for a relevant category | [Contribution rules](https://github.com/Solido/awesome-flutter/blob/master/contributing.md) require at least 35 stars; current baseline is 1, so it is not eligible now. External PR needs authorization. |
| Existing local-AI questions | A specific helpful answer when this package fits | Answer the actual question, disclose authorship, obey rules and obtain messaging authorization. |

Do not post the same pitch repeatedly in unrelated threads. Do not buy stars,
likes, backlinks or fabricated testimonials, and do not create scripts to inflate
downloads. No outreach, submission, external PR, campaign or message was performed.

A real-device demo could help adoption, but requires an expressly authorized
run/capture. Show the actual device, iOS/runtime, local availability and outcome;
do not turn sample UI or an unexecuted code block into a performance claim.
Use live canonical guide URLs in promotion after the site is confirmed public.

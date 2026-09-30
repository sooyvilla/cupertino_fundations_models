# Promotion kit — reviewable drafts, not published messages

Prepared September 30, 2026. These drafts accompany the 0.4.4 documentation
release. The package and documentation site are public. The maintainer should
review the voice and channel rules before any message is sent. These texts
have not been posted to a community or social account.

The owner requested a review of the exact text before every send or publication.
Before asking for that approval, identify the destination and account, check its
current rules, and show the complete draft. Approval of package publication
does not approve these messages.

## Recommended first distribution

Start with the maintainer's existing professional profile and an owned blog,
if available. The short post introduces the package; the article gives a
developer enough detail to decide whether to try it. The channel choice depends
on the owner's actual accounts and audience, which have not been inspected.
This is a proposed order, not a forecast of traffic or downloads.

Current rules change the community options:

- [r/FlutterDev rules](https://www.reddit.com/r/FlutterDev/about/rules.json)
  reject AI-generated articles. The draft below must not be submitted there
  as human-authored work. Use it as an outline for the maintainer's own writing.
- [DEV AI guidelines](https://dev.to/guidelines-for-ai-assisted-articles-on-dev)
  require disclosure and restrict promotional AI-assisted content, including
  content whose main purpose is SEO backlinks. This package-promotion draft is
  not a ready-to-publish DEV submission.

The owner can write a firsthand technical article using their own experience.
No device results, adoption figures or personal anecdotes should be added
without the corresponding evidence.

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

**Title:** Using Apple Foundation Models from Flutter: local summaries and structured JSON

I maintain `cupertino_fundations_models`, an MIT-licensed Flutter iOS plugin
for Apple's Foundation Models framework. You can use it from Dart to summarize
short text, rewrite a message, classify a note or extract fields into JSON.
Local generation runs on the device and needs no API key.

I updated the documentation with a first summary example, English and Spanish
setup guides, and two small recipes: extracting an appointment and classifying
a note. The guides also explain sessions, streaming, cancellation and tools.
Your app still checks the output before using it.

Generation needs iOS 26+, a device that supports Apple Intelligence, the right
settings and downloaded model assets. It can work offline once those assets
are ready. The plugin currently supports iOS; Speech and optional Private Cloud
Compute have their own privacy settings and requirements.

[Package](https://pub.dev/packages/cupertino_fundations_models) ·
[Documentation](https://sooyvilla.github.io/cupertino_fundations_models/)

If you try it and run into an integration issue, please share the package and
iOS versions with a small example. That makes it much easier to investigate.

## Spanish launch post

**Título:** IA local nativa de Apple para Flutter iOS, desde Dart

Mantengo `cupertino_fundations_models`, una librería MIT que conecta Flutter
con Foundation Models de Apple. Puedes usarla desde Dart para resumir un texto,
reescribir un mensaje, clasificar una nota o extraer campos en JSON.
La generación se ejecuta dentro del dispositivo y no necesita una clave de API.

Actualicé la documentación con una guía en español para obtener el primer
resumen y ejemplos pequeños de extracción y clasificación. También explica
las sesiones, el streaming y los errores que conviene manejar. Tu app sigue
validando los datos antes de usarlos.

La generación exige iOS 26+, un dispositivo apto para Apple Intelligence y los
recursos del modelo disponibles. No admite Android, macOS o web. La inferencia
local puede funcionar sin internet después de descargar los recursos; Speech
y Private Cloud Compute tienen políticas y requisitos separados.

[Paquete](https://pub.dev/packages/cupertino_fundations_models) ·
[Documentación](https://sooyvilla.github.io/cupertino_fundations_models/es/ia-local-ios/)

## Short professional-network post

Use Apple Foundation Models from Flutter with `cupertino_fundations_models`:
local summaries, guided JSON and streaming. No API key for local generation.
Requires iOS 26+ and Apple Intelligence. Setup guides are available in English
and Spanish.

[Start with the package](https://pub.dev/packages/cupertino_fundations_models)

## LinkedIn draft in Spanish

Si estás añadiendo una función de IA a una app Flutter para iOS, Apple
Foundation Models permite resolver tareas cortas dentro del dispositivo.

Mantengo `cupertino_fundations_models`, una librería que conecta ese framework
nativo con Dart. Puedes usarla para resumir texto, reescribir mensajes,
clasificar notas o extraer campos en JSON, sin una clave de API para generar
localmente.

Publiqué la versión 0.4.4 con una guía en español, ejemplos pequeños y una
documentación que explica la disponibilidad, el streaming y la privacidad.
La generación requiere iOS 26+ y un iPhone compatible con Apple Intelligence.
Tu app sigue validando los resultados antes de usarlos.

[Guía en español](https://sooyvilla.github.io/cupertino_fundations_models/es/ia-local-ios/)
· [Paquete](https://pub.dev/packages/cupertino_fundations_models)

## X draft

Apple Foundation Models from Flutter: local summaries, guided JSON and
streaming with cupertino_fundations_models. No API key for local generation.
Requires iOS 26+ and Apple Intelligence.
https://pub.dev/packages/cupertino_fundations_models

## Developer article draft

**Title:** Add local AI to Flutter iOS without maintaining your own Foundation Models bridge

**Description:** Add a short on-device summary, then extract fields into JSON
with Cupertino Foundation Models for Flutter iOS.

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

The [first-response guide](https://sooyvilla.github.io/cupertino_fundations_models/local-ai-ios/)
shows availability checking, a bounded summary request, typed exception
handling and session disposal. When a model is unavailable, retain a useful
manual path. A preflight can succeed and the subsequent request can still fail,
so request-level errors remain part of the integration.

For extraction, provide `StructuredSchema` to `generateStructured()` rather
than simply writing “return JSON” in the prompt. The
[task recipes](https://sooyvilla.github.io/cupertino_fundations_models/recipes/)
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
and [FAQ](https://sooyvilla.github.io/cupertino_fundations_models/faq/)
provide the contracts. These documentation snippets are not a device benchmark
or a claim that every supported path has been physically validated.

## Distribution order

| Channel | Concrete material | Condition before posting/submitting |
| --- | --- | --- |
| GitHub repository | About text/topics, source, documentation link | Published and confirmed September 30. |
| pub.dev | README, topic, description, included public guides | Version 0.4.4 published and confirmed September 30. |
| r/FlutterDev | Outline for a firsthand maintainer post | Current rules reject AI-generated articles; the prepared draft is not eligible for direct submission. |
| DEV | Possible future firsthand educational article | Current AI guidelines restrict promotional AI content; do not submit this package-marketing draft there. |
| Owned blog / Hashnode | Technical article draft plus source links | Existing account, applicable rules, complete owner review and approval before publication. |
| LinkedIn / X | Short drafts above | Confirm owner's account and show the exact message before approval and publication. |
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

---
title: Local AI for Flutter iOS | Cupertino Foundation Models
description: Use Apple Foundation Models from Flutter to summarize text, extract JSON and stream responses on iOS. Local generation runs on the device without an API key.
permalink: /
---
# Native local AI for Flutter iOS

Add a summary, rewrite a message or extract a few fields without sending the
text to an external AI service. `cupertino_fundations_models` connects your
Flutter app to **Apple Foundation Models** through a native Swift bridge.
You work in Dart, with sessions, streaming, guided JSON and tools defined by
your app.

[Start with local AI]({{ '/local-ai-ios/' | relative_url }}) ·
[Español: inteligencia artificial local para iOS]({{ '/es/ia-local-ios/' | relative_url }}) ·
[Get the package]({{ site.package_url }})

```sh
flutter pub add cupertino_fundations_models
```

## Keep generation on the device

Local inference requires no API key or third-party AI service. Set
`ModelMode.local` and `CloudPolicy.never`. Once Apple's required assets are
available, eligible devices can generate without network. Tools and Speech
have separate network/privacy behavior; PCC is an explicit optional cloud route.

## Find the guide for your task

| What you need | Where to start |
| --- | --- |
| Your first availability-checked response | [Local iOS AI tutorial]({{ '/local-ai-ios/' | relative_url }}) |
| Structured JSON extraction and classification | [Task recipes]({{ '/recipes/' | relative_url }}) |
| Sessions, cumulative streams, tools and cancellation | [Usage contracts]({{ '/usage/' | relative_url }}) |
| Text/PDF extraction with validation | [Document extraction]({{ '/document-extraction/' | relative_url }}) |
| Apple cloud eligibility and consent boundaries | [Private Cloud Compute]({{ '/private-cloud-compute/' | relative_url }}) |
| Offline behavior, platforms and eligible devices | [FAQ]({{ '/faq/' | relative_url }}) |

The plugin supports CocoaPods and Swift Package Manager and adds no third-party
runtime dependencies. It is an independent MIT-licensed package for **Flutter
iOS**, not a standalone Swift SDK or an Android/macOS/web plugin.

## Check availability before offering AI

Generation requires iOS 26+, a device eligible for Apple Intelligence, supported
settings/locale and model assets. The package can be included in an iOS 15+
app, but that deployment target does not enable generation on older systems.
Some features have newer runtime and SDK requirements.

Use `checkAvailability()` and handle request failures. Keep tasks bounded and
validate model output; guided JSON does not prove that facts or amounts are correct.
[Compare local, custom-model and cloud approaches]({{ '/choosing-local-ai/' | relative_url }}).

## Explore the implementation

[Full package overview]({{ '/overview/' | relative_url }}) ·
[Dart API reference]({{ site.api_url }}) ·
[Example source]({{ site.repository_url }}/tree/main/example) ·
[Release notes]({{ '/changelog/' | relative_url }}) ·
[Apple Foundation Models](https://developer.apple.com/documentation/foundationmodels)

This project is maintained by Sebastián Villa. If you run into an integration
problem, [open an issue]({{ site.repository_url }}/issues) with your package
version, iOS version and a small example. If the package helps your app,
a pub.dev like or GitHub star helps other developers discover it.

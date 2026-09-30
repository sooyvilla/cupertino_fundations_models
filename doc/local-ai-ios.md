# Local AI for Flutter iOS with Apple Foundation Models

This guide adds a short, on-device summary to a Flutter iOS app using
`cupertino_fundations_models`. The package connects Dart to Apple's native
Foundation Models framework. The same APIs support rewriting, classification,
structured JSON and tools defined by your app. Local generation needs no API key.

[Español](README.es.md) · [Task recipes](recipes.md) · [FAQ](faq.md)

## What you need

| Requirement | Meaning |
| --- | --- |
| Flutter 3.41+ and Dart 3.11+ | Minimum package SDK constraints. |
| macOS and an appropriate Xcode SDK | Build the native iOS host; feature-specific SDK requirements still apply. |
| iOS 26+ for generation | The plugin's iOS 15 deployment target permits installation, not generation on iOS 15. |
| Eligible Apple Intelligence device, settings, locale and model assets | Ask native availability; the OS version alone is insufficient. |

The plugin supports CocoaPods and Swift Package Manager. It does not add
third-party runtime packages or require downloading a GGUF model into your app.
Apple manages its system model and assets. Initial asset downloads may need
network even though inference runs on the device.

## Install the package

From your Flutter application:

```sh
flutter pub add cupertino_fundations_models
```

To choose the version explicitly, add:

```yaml
dependencies:
  cupertino_fundations_models: ^0.4.4
```

Import the exact package name, including the existing spelling `fundations`:

```dart
import 'package:cupertino_fundations_models/cupertino_fundations_models.dart';
```

Rebuild the iOS host after adding or upgrading the plugin. Hot reload
cannot install a changed Swift bridge. A local-only app can leave PCC disabled.
Text generation alone does not require microphone or Speech usage descriptions.

## Generate your first summary

Call this function from your Flutter application. It checks availability,
creates a local session and releases it when finished. A null result lets
your UI offer its usual manual flow if the model is unavailable or the request fails.

```dart
import 'package:cupertino_fundations_models/cupertino_fundations_models.dart';

Future<String?> summarizeOnDevice(String text) async {
  final models = CupertinoFoundationModels();
  FoundationModelSession? session;
  try {
    final availability = await models.checkAvailability(
      mode: ModelMode.local,
      cloudPolicy: CloudPolicy.never,
      localeIdentifier: 'en_US',
    );
    if (!availability.isAvailable) return null;

    session = await models.createSession(
      options: const SessionOptions(
        mode: ModelMode.local,
        cloudPolicy: CloudPolicy.never,
        localeIdentifier: 'en_US',
        instructions:
            'Summarize the supplied passage in three short English bullets. '
            'Use only facts present in the passage.',
      ),
    );
    final response = await session.respond(
      Prompt.text(text),
      options: const GenerationOptions(maximumResponseTokens: 180),
    );
    return response.text;
  } on FoundationModelsException {
    return null;
  } finally {
    await session?.dispose();
  }
}
```

Keep the input short and let the user review the result. Availability can
change between the check and generation. Your app can use the typed
error code and [recovery guide](troubleshooting.md) to explain a failure rather
than treating every null result as the same condition.

## Choose the next API

| Task | API | Important contract |
| --- | --- | --- |
| Independent text generation | `models.respond()` | Creates and disposes a session for that call. |
| Conversation using earlier turns | `models.createSession()` | The app owns disposal and transcript lifetime. |
| Show incremental text | `session.stream()` | Replace displayed text with each cumulative snapshot. |
| Extract typed JSON fields | `models.generateStructured()` | Supply a supported `StructuredSchema`; validate business meaning afterward. |
| Stream guided JSON | `session.streamStructured()` | Partial JSON is not final data; use the completion response. |
| Invoke app functions | `SessionOptions.tools` | The app checks tool arguments, authorization and side effects. |
| Recognize speech | `transcribeAudio()` or `liveTranscription()` | Separate permissions, assets and Speech privacy policy. |

See [recipes](recipes.md) for structured extraction and classification, and
[usage](usage.md) for complete lifecycle, token-budget and timeout semantics.

## Keep local AI local

Set `ModelMode.local` and `CloudPolicy.never` explicitly. This selects on-device
generation. The package does not automatically send failed requests to OpenAI,
Gemini or another remote API, and it does not store API keys.

Tools are application code: a tool can access your app's database or network.
The local model policy does not make a networking tool offline. Speech's
`AudioTranscriptionMode.onDevice` is a separate setting; its `automatic` or
`server` alternatives can allow Apple Speech networking.

PCC is an optional Apple cloud route, not a requirement for local generation.
Read [Private Cloud Compute](private-cloud-compute.md) for the separate iOS 27,
Apple entitlement, signing, host opt-in and consent requirements. A plist flag
does not grant cloud access.

## Plan for the model's limits

This package supports **iOS**, not macOS, Android, web or a standalone Swift
application. Apple's broader framework support does not imply plugin support
on those platforms. Local generation is not available on every iPhone.

Use small, well-defined tasks. A local language model is not a web search
engine, source of verified facts or general autonomous agent. Check context
capacity where available and reserve space for instructions, schemas, tools
and the output. File size alone does not prove a document fits.

Text and PDF input reaches the model as extracted text. Image input uses
Vision OCR, classification and barcodes; native multimodal attachments remain
disabled, so arbitrary visual reasoning is unavailable.

These examples were reviewed against the source and were not run during this
documentation update. Try them with your app's supported devices, languages
and inputs before shipping.

## References and next steps

- [Apple Foundation Models](https://developer.apple.com/documentation/foundationmodels)
- [Full usage reference](usage.md)
- [Example application](../example/README.md)
- [Document extraction example](document-extraction.md)
- [Choosing a local or cloud AI approach](choosing-local-ai.md)
- [API reference](https://pub.dev/documentation/cupertino_fundations_models/latest/)
- [Report an integration issue](https://github.com/sooyvilla/cupertino_fundations_models/issues)

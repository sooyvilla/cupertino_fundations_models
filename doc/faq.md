# Questions about local AI on iOS

## What is cupertino_fundations_models?

An independent MIT-licensed Flutter iOS plugin that bridges Dart to Apple's
native Foundation Models and Speech frameworks. It exposes local language
generation, sessions, streaming, guided structured output and app-defined tools.
Start with the [English tutorial](local-ai-ios.md) or [guía en español](README.es.md).

## Is this an Apple Intelligence Flutter package?

It uses the Foundation Models framework that exposes Apple Intelligence models
to applications. It is not an Apple-maintained or Apple-endorsed package and
does not enable Apple Intelligence on an unsupported device.

## Can I run AI locally on iOS without an API key?

Yes. Select `ModelMode.local` with `CloudPolicy.never`. Local generation uses
Apple's system model rather than an external AI API. Your application's tools
may have their own credentials or network behavior.

## Does local generation work without internet?

It can run offline after the required Apple Intelligence assets are present
and native availability succeeds. Setup and model/Speech asset downloads may
require network. PCC, server Speech and networking tools still need a connection.

## Do I have to bundle or download an LLM myself?

No custom model file is required by this plugin. Apple manages the system
model. The package is not a GGUF, llama.cpp, ONNX or custom-weight runtime.

## Which iOS versions are supported?

The plugin deployment target is iOS 15. Foundation Models generation requires
iOS 26+ and native Apple Intelligence availability. Some options require iOS 27
or a newer build SDK. Read the [compatibility table](../README.md#features-and-compatibility).

## Does it support every iPhone running iOS 26?

No. Hardware eligibility, region, language, enabled settings and model assets
also matter. Call `checkAvailability()` to find out whether the model can run
on the user's device now.

## Does the plugin support macOS, Android or web?

No. The declared Flutter plugin platform is iOS. Broader Apple framework
availability is not a promise of broader plugin platform support.

## Can I import this package into a Swift-only app?

No. This is a Flutter package with a native Swift implementation. For an app
written only in Swift, use Apple's Foundation Models framework directly.

## Does this package ship third-party runtime dependencies?

No. Its Dart runtime dependency is Flutter from the SDK; its native bridge uses
Apple platform frameworks. Development tooling is separate from runtime dependencies.

## Does it support CocoaPods and Swift Package Manager?

Yes. Both plugin integrations use the same Swift sources. Your iOS host still
needs an appropriate build SDK, deployment configuration and native rebuild
after an upgrade.

## Can I request structured JSON rather than prompt for JSON?

Yes. Supply a supported object-root `StructuredSchema` to
`generateStructured()` or `streamStructured()`. A prompt that says “return JSON”
does not enable native schema guidance. Guided output still needs application
validation for facts, amounts, dates and business constraints.

## Are streaming events tokens or text chunks to append?

`TextSnapshotEvent.text` is cumulative. Replace your displayed text with the
latest snapshot. The terminal `CompletionEvent.response` contains the final
result. In a structured stream, partial JSON must not be committed as final data.

## Can I call my own tools from the model?

Yes. Register tools on `SessionOptions`. The app validates arguments and checks
authorization before side effects. A local model does not make its tools
automatically safe or offline. Cancellation does not undo a tool's side effects.

## Is Private Cloud Compute enabled by default?

No. PCC requires its own policy, iOS 27 runtime, Apple-managed entitlement,
host signing and provisioning, an opt-in flag, availability and appropriate
application consent. Physical PCC verification remains pending.
See [PCC setup](private-cloud-compute.md).

## Does the plugin automatically fall back to a cloud provider?

No. The consuming application owns external API routing, consent, history,
credentials and retries. Failed private prompts are not automatically replayed
to another provider. See [application-owned routing](app-owned-routing.md).

## Does on-device generation also make speech-to-text local?

Speech has a separate privacy setting. `AudioTranscriptionMode.onDevice` is
the local default. `automatic` and `server` can permit Apple Speech networking.
Configure the host usage descriptions and handle denied permissions, missing
assets and unsupported locales. Apple Speech servers are not PCC.

## Does image input provide native multimodal reasoning?

No. The documented iOS 27 path uses Vision OCR, image classification and
barcodes to provide text context. Native Foundation Models image attachments
remain disabled because of recorded fatal beta crashes. The package therefore
does not offer unrestricted chart, diagram or handwriting understanding.

## Is it suitable for long PDFs or financial decisions?

Use bounded input and validate extracted fields against the source. A model
response is not proof of complete row coverage or correct amounts. The package
does not reconcile financial data, enforce your business rules or persist
transactions. See [document extraction](document-extraction.md).

## Why does the package name use “fundations”?

The published identifier remains `cupertino_fundations_models` to preserve
existing imports. The human-readable framework name is Apple Foundation Models.
Use the exact published identifier in dependencies and Dart imports.

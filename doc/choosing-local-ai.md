# Choosing a local AI approach for a Flutter app on Apple platforms

Use `cupertino_fundations_models` when your Flutter app needs **Apple-native
on-device language generation on eligible iPhone, iPad and Mac devices**. It supplies the Dart
API and Swift bridge, including sessions, streams and tool calls. Your app
can focus on the task, the interface and validation of the result.

The best fit depends on your platforms, model requirements and privacy policy.
This table compares the integration work for each approach.

| Requirement | This Flutter plugin | Direct Foundation Models in Swift | A custom local model runtime | An application-owned cloud API |
| --- | --- | --- | --- | --- |
| Flutter iOS/iPadOS and macOS integration | Typed Dart facade and native bridge included | You implement or maintain the Flutter bridge | Depends on the chosen runtime/plugin | You integrate the provider client |
| Apple system language model | Yes, native availability required | Yes, native availability required | Usually brings its own weights; check that runtime | Depends on the service |
| Model choice and custom weights | No custom-weight loader | Depends on the Apple API and your implementation | Runtime/model-specific | Provider-specific |
| Android or web in this package | No | Requires platform-specific implementation | Runtime/plugin-specific | Client/provider-specific |
| Local inference without an API key | Yes, once eligible and assets are ready | Yes, under Apple's availability requirements | Runtime/license-specific | Cloud credentials or authenticated backend normally required |
| Guided schemas and streaming | Existing Dart API with lifecycle contracts | You design the app/bridge contracts | Runtime/model-specific | Provider/model-specific |
| App size and model delivery | No custom weights bundled by this plugin | Apple manages system-model assets | You plan model storage and delivery | Provider hosts the model |
| Privacy boundary | Explicit local policy; tools and Speech remain separate | Defined by your application | Defined by your runtime and application | Data leaves the device under your policy |

## Choose this package for bounded native tasks

Good first integrations include short summaries, message rewriting, a small
classification vocabulary and extraction of a few fields into a schema. Start
with [local AI on iOS](local-ai-ios.md), [Mac setup](apple-platforms.md) and
[recipes](recipes.md). macOS support starts in version 0.5.0.

The plugin adds session ownership, terminal stream delivery, awaited
cancellation/disposal, bounded tool execution, token measurements where native
support exists and opt-in diagnostics. The consuming app still checks model
output, protects side effects and decides what happens when the model is unavailable.

## Choose another approach when your requirements differ

If your app is written only in Swift, use
[Apple's Foundation Models framework](https://developer.apple.com/documentation/foundationmodels)
directly. If you need one runtime across Android and iOS or must select custom
weights, assess a runtime/plugin that explicitly supports those requirements.

For broad factual research, larger context or another model family, design an
application-owned API path. Before sending user data off-device, your app must
resolve consent, credentials, policy, history and retries. A failed local request
still needs permission before it is sent elsewhere. See [routing](app-owned-routing.md).

PCC is an optional Apple cloud route in this package. It has separate
[eligibility and signing requirements](private-cloud-compute.md); it does not
make an app offline or guarantee availability.

## Questions to resolve before adoption

1. Is the feature useful on a device where Apple Intelligence is unavailable?
2. Can the task fit a bounded input and response budget?
3. Can the app validate the result without trusting generated text blindly?
4. Do tools perform mutations or network requests, and how are they authorized?
5. Does the app need a local-only promise for both generation and Speech?
6. Does it require unsupported platforms, custom models or native multimodal input?

The [FAQ](faq.md) and [usage contracts](usage.md) answer the package-specific
parts. Device/model performance and product fit need evidence from your actual
app; this documentation is not a comparative benchmark.

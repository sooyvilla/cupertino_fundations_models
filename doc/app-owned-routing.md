# Combine an API agent with the local Apple model

The application owns the agent, credentials, consent, conversation, tools,
idempotency and routing policy. This package is a bounded Apple capability
inside that architecture.

Before offering the Apple cloud route, complete the
[PCC eligibility, entitlement and signing setup](private-cloud-compute.md).
An external API subscription or Speech server permission does not authorize PCC.

A useful split is:

```text
App task dispatcher
  -> Small independent text transformation -> Apple local session
  -> API agent / retrieval / long reasoning -> App backend
  -> Authorized Apple cloud task            -> Explicit PCC session
```

Choose a route **before** sending content. Keep the local model's input limited
to the current task. Do not replicate a complete API-agent conversation,
financial history, credentials or a large tool catalog into a small local
session just because both routes can generate text.

## Small application-owned boundary

This example returns a local result or a typed reason for the app to handle.
It never calls a remote provider as an exception handler:

```dart
import 'package:cupertino_fundations_models/cupertino_fundations_models.dart';

Future<ModelResponse> rewriteLocally(String text) async {
  final models = CupertinoFoundationModels();
  final availability = await models.checkAvailability(
    mode: ModelMode.local,
    cloudPolicy: CloudPolicy.never,
  );
  if (!availability.isAvailable) {
    throw const FoundationModelsException(
      code: FoundationModelsErrorCode.modelUnavailable,
      message: 'Local rewriting is unavailable.',
    );
  }
  return models.respond(
    Prompt.text(text),
    mode: ModelMode.local,
    cloudPolicy: CloudPolicy.never,
    instructions: 'Rewrite the supplied message clearly. Preserve its meaning.',
    options: const GenerationOptions(maximumResponseTokens: 180),
  );
}
```

The caller can offer manual editing or a separately authorized backend action.
It should apply its own input limit, token budget and output validation. The
plugin does not promise a specific task quality from the fact that a model is
available.

## When an API agent calls the local capability

Expose narrowly named operations such as `rewriteDraft`, `classifyNote` or
`extractContact`, with bounded inputs and a schema where appropriate. Return a
validated result or a typed failure to the application's orchestrator. Limit
concurrent work and account for tool definitions/output in the context budget.

For structured progress, use `session.streamStructured` (0.3.1+) and treat JSON
snapshots as provisional. Consume `CompletionEvent.response.structuredValue`
after success and business validation. A JSON-only prompt on a text stream does
not activate native schema guidance; see [guided streaming](usage.md#guided-streaming).

Keep tools that perform payments, writes, sends or deletes behind the app's
normal authorization and idempotency controls. A local model asking for a tool
is not user approval. A tool timeout or cancellation does not undo an already
started Dart function. Replaying the same request through a second agent can
repeat a side effect.

Version 0.4.0 exposes component budgets, nullable actual usage, typed
termination and deadline phases to inform that application policy. Unknown PCC
counts and native stop reasons must remain unknown. Opt-in diagnostics do not
persist or upload source material. See [usage](usage.md) and
[migration](migration-0.4.0.md).

## Optional framework bindings

F10 in the prepared core 1.9.0 adds an optional Dart entry point:

```dart
import 'package:cupertino_fundations_models/cupertino_fundations_models_adapters.dart';

final apple = FoundationModelsAdapter(models: CupertinoFoundationModels());
var text = '';
await for (final event in apple.stream(prompt: Prompt.text('Rewrite this draft.'))) {
  final update = event.textUpdate;
  if (update != null) text = update.applyTo(text);
  if (event.original case CompletionEvent(:final response)) {
    reviewResponse(response);
  }
}
```

`reviewResponse` is an app callback. The adapter owns one new session per call,
disposes it, and forwards the original events and final response by identity.
Streams are cold and single-subscription. Existing sessions instead use
`session.stream(...).adaptEvents()`; the app still owns their disposal. See the
[ownership, pause and failure contracts](usage.md#optional-adapters-and-stream-updates).
The executable [AppTextBackend](../example/lib/app_text_backend.dart) and
[AppleTextBackend](../example/lib/apple_text_backend.dart) example provides an
app-owned interface without choosing a third-party framework.

These are integration recipes, not bundled Genkit plugins or LangChain model
subclasses. They were checked against the current primary documentation on
2026-10-09. Apps choose and pin a framework version separately; the core has
no new runtime dependency and keeps its Dart ^3.11.0 requirement.

### Genkit recipe

Genkit 1.0.0 currently requires Dart ^3.12.0. An app choosing it must meet that
SDK requirement; merely importing the Apple adapter does not upgrade the app.
[Package requirements](https://pub.dev/packages/genkit)

1. Register an application-owned model action with the app's chosen Genkit API.
   Keep credentials, flow state, telemetry and provider selection in that app.
2. Map only supported inputs to `Prompt`, `SessionOptions`, `GenerationOptions`
   and an explicit `StructuredSchema`. Reject incompatible media, tools or
   schema keywords before starting the Apple request.
3. Bind Genkit's cancellation signal to the adapted subscription and await
   `subscription.cancel()`. Pausing delivery does not suspend native inference
   or deadlines. Cancellation of a framework flow needs its own cancellation
   token; do not assume it follows from cancelling an unrelated stream.
4. For a consumer that concatenates text chunks, set `allowReplacements: false`
   and emit only append contents. A revised snapshot, including a revised final
   response, then fails explicitly. If the host UI accepts replacements, retain
   `TextUpdate` operations or full snapshots in a separate app event contract.
5. Return the final native response and available counters through the app's
   mapping. Keep absent counts unknown and preserve metadata/termination in an
   app sidecar when the framework has no corresponding field.

Genkit text chunks and accumulated text have different roles; partial structured
output can be absent. An output schema or prompt-based constrained-generation
simulation is not proof of native guided generation. The app must select a
supported schema and retain F05 partial snapshots separately from F04 final
decoding. Genkit can run a tool loop or return tool requests; an observed Apple
`ToolCallEvent` must not be sent back through that loop for duplicate execution.
[Model and streaming contracts](https://genkit.dev/docs/dart/models/),
[flow cancellation](https://genkit.dev/docs/dart/flows/),
[tool execution](https://genkit.dev/docs/dart/tool-calling/)

### LangChain recipe

The current `langchain` 0.9.0 contract composes generated chat chunks by
concatenation. A binding should use the strict append mode above, or expose
replacement operations through its own app/UI contract. Subtracting string
lengths and treating a revision as a suffix loses text. There is no universal
replacement event or provider cancellation token in that chat result contract.
[Package](https://pub.dev/packages/langchain),
[ChatResult and message API](https://pub.dev/documentation/langchain/latest/langchain/)

Keep the binding narrow: a text/guided request maps to the Apple adapter, while
external retrieval, agent memory and provider tools remain app-owned. Cancel
the Apple subscription explicitly and await its completion when the agent stops.
Do not turn observed native tool calls into framework tool requests. Structured
chunk parsing in a framework does not replace native schema enforcement or make
partial JSON safe for a final decoder. Usage is provider-dependent; for example,
the OpenAI integration documents optional streaming usage collection. Preserve
unknown counters rather than setting them to zero.
[Provider usage contract](https://pub.dev/packages/langchain_openai)

### Shared mapping rules

| Source | Application binding |
| --- | --- |
| `TextUpdate.append` | Append its suffix only against the matching buffer; `applyTo` rejects stale state. |
| `TextUpdate.replace` | Replace the complete buffer, or fail explicitly for an append-only target. |
| `TextSnapshotEvent.structuredSnapshot` | Retain provisional presence/completeness data; never emit a final domain object. |
| `CompletionEvent.response` | Reconcile final text, then map the original response, route, nullable usage and termination. |
| `ToolCallEvent` | Forward observation data; execution belongs to the existing native session/tool bridge. |
| `FailureEvent` / stream error | Retain the original failure; no synthetic success, hidden retry or remote fallback. |
| Unknown event or unsupported metadata | Keep the original event in an app sidecar or reject the mapping; do not guess its meaning. |

A terminal event is delivered after source cancellation and owned disposal. A
cleanup failure is an error and withholds that terminal; explicit cancellation
also suppresses a terminal waiting for cleanup. Consumers must handle both
native failure events and stream errors. Source streams must follow the Dart
contract, including no events before `listen` returns.
[Dart synchronous stream contract](https://api.dart.dev/dart-async/SynchronousStreamController-class.html)

External framework callbacks, logs and tracing can upload inputs or outputs.
The app must decide that policy and user consent before forwarding data; using
an on-device model alone does not make the surrounding framework local. No
external provider, framework runtime, signed PCC request or model quality was
validated by these recipes. The adapter and example interface are covered by
local Dart unit/channel tests.

## Retry and fallback rules

| Failure | Application action |
| --- | --- |
| Disabled Intelligence, ineligible device, missing assets | Show the local status; offer a manual path or separately authorized remote route. |
| Unsupported locale or capability | Change the task configuration; do not retry unchanged. |
| `invalidRequest` / schema / attachment error | Fix the input. A different provider is not input validation. |
| `contextSizeExceeded` | Split the input or start a bounded new session. Preserve coverage explicitly. |
| Guardrail/refusal | Handle the failure; do not use provider fallback to evade a refusal. |
| Rate limit / network / quota | Apply bounded backoff only for idempotent work and within the app's policy. |
| Tool failure / timeout / cancellation | Reconcile possible side effects before any retry. |

Do not silently upload a partial local transcript after a streaming failure.
Provider changes should start a clearly scoped request with consented data and
an explicit application-owned history policy.

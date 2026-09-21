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

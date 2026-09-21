# Migrating from 0.2.x to 0.3.0

0.3.0 is a breaking, pre-1.0 update from 0.2.x. This guide covers the removed
hybrid layer and the stricter native session contracts.

These breaking changes also apply when upgrading from 0.2.x to 0.4.0.
Also apply the [0.4.0 migration](migration-0.4.0.md) for nullable usage and lifecycle changes.
From 0.3.0, the public addition is [guided streaming](usage.md#guided-streaming):
use `session.streamStructured(...)` or `session.stream(..., schema: ...)`.
Existing text streams retain their event types. Custom transports importing the
internal platform interface must accept the optional `StructuredSchema? schema`
named parameter. Before selecting Apple cloud, follow the
[PCC setup guide](private-cloud-compute.md).

## Move routing to the host application

The package no longer exports or contains `FoundationModelsOrchestrator`,
`FoundationModelsChatSession`, routing policies, external provider adapters,
shared chat history, or `Orchestrated*` DTOs. The example no longer accepts a
`GEMINI_API_KEY` or includes a Gemini HTTP client.

| Old call or type | Replacement |
| --- | --- |
| `orchestrator.respondText(...)` | `models.respond(Prompt.text(...), mode: local, cloudPolicy: never)` for a local single turn. |
| `orchestrator.startChat()` | `models.createSession(options: ...)`; await creation. |
| `chat.send(...)` | `session.respond(Prompt.text(...))`. |
| `chat.sendStream(...)` | `session.stream(Prompt(...))`. |
| `OrchestratedChatTextEvent` | `TextSnapshotEvent`; replace displayed text. |
| `OrchestratedChatCompletionEvent` | `CompletionEvent`; read `response.usedMode`. |
| `chat.reset()` | Await `session.dispose()` and create a new session. |
| `FoundationModelsDefaults` | `SessionOptions` plus per-request `GenerationOptions`. |
| External provider/transcription adapters and runtime prompt context | App-owned services and routing policy. |

See [the routing guide](app-owned-routing.md) before combining local and API
agents. No conversation, attachments or tool actions are replayed to another
provider by this package.

## Enforce privacy explicitly

- `privateCloudCompute` plus `CloudPolicy.never` now fails. Use
  `CloudPolicy.whenExplicit` only when the app has authorized PCC.
- `automatic` plus `whenExplicit` stays local. Automatic PCC selection requires
  `automaticWithUserConsent`, with consent obtained by the host application.
- `GenerationOptions.cloudPolicy` is now nullable. Omit it to inherit the
  selected session; `never` blocks a PCC request. It cannot upgrade or reroute
  an existing session.
- `SessionOptions.localeIdentifier` optionally validates the local language
  before creating the session. Instructions still select the response language.
  PCC language preflight stays unavailable because its unsafe getters remain
  disabled.

## Handle stricter validation

Unsupported schema types or constraints, arrays without `items`, invalid
required-property names, invalid tool parameter schemas, empty text attachments
and invalid option ranges return errors instead of silent substitutions.
Schemas are a documented subset, not arbitrary JSON Schema.

Explicit `required`/`disallowed` tool modes and reasoning choices cannot be
silently applied to iOS 26. Use default options there. On iOS 27, `required`
needs at least one tool and a bounded call budget.

Only one live microphone transcription can own the shared native capture path.
Await its subscription cancellation before starting another. Multiple model
sessions remain supported.

## Packaging and versioning

The iOS deployment target stays at 15. Foundation Models availability stays at
26/26.4/27 according to each feature. CocoaPods and SPM remain supported, with
no new runtime package dependency.

Do not interpret 0.3.0 or a successful build as a claim that all beta runtime
paths are stable. The [audit](ios-27.2-audit-2026-09-19.md) separates current
source/build evidence from the historical physical-device checks and the work
needed before a 1.0 stability commitment.

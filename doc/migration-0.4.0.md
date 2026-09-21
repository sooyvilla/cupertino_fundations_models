# Migrating to 0.4.0

Version 0.4.1 retains this contract and corrects publication diagnostics.

This release keeps the existing text/structured streaming event hierarchy and
adds request reliability APIs. Resolve the consuming app's dependency to
`^0.4.3` and rebuild its iOS host. Hot reload cannot update the native bridge.

## Breaking changes

Every `ModelUsage` counter is now `int?`. A missing native counter stays null;
previous versions decoded a missing counter as zero. Handle absence before
arithmetic or displaying usage. Do not replace absence with zero when deciding
whether a response was truncated or whether another request fits.

```dart
final total = response.usage?.totalTokenCount;
final label = total == null ? 'Usage unavailable' : '$total tokens';
```

The internal platform interface adds `measureTokenBudget`. Custom transports or
fakes importing `src/platform` must implement that method. It returns named
component measurements, their precision and availability; it must not fabricate
PCC counts using the local tokenizer.

Closing a stream without a completion/failure event now raises `nativeFailure`
with `details['streamClosedWithoutResult'] == true`. Cancellation cleanup errors
are propagated; the session must then be disposed and recreated. A normal close
alone has never proved a valid answer.

## Additive APIs

- `session.measureTokenBudget(prompt: ..., schema: ..., options: ...)` measures
  local prompt, instructions, tools, schema and transcript separately. These
  components can overlap; their sum is not an exact request count. PCC counts and
  unknown context limits remain unavailable.
- `ModelResponse.termination`, `FailureEvent.termination` and
  `FoundationModelsException.termination` distinguish operation outcome,
  structure completeness and timeout phase. Successful generation has an unknown
  stop reason when Apple supplies none.
- `GenerationOptions.firstResponseTimeout`, `idleTimeout` and `totalTimeout`
  separate stream deadlines. Existing `timeout` behavior remains the fallback.
- `GenerationOptions.diagnostics` supplies an opt-in callback. Output capture
  is separately disabled by default and bounded when enabled.
- Dynamic schema names are unique by path. Mapping errors expose `schemaPath`;
  unsupported constraints remain unsupported.

See [usage](usage.md), the [document example](document-extraction.md), and
[PCC setup](private-cloud-compute.md). No local → PCC → external-provider routing
or financial validation is added to the library.

# Usage reference

This reference describes version 0.4.0. See the [README](../README.md) for
installation and the [0.4.0 migration guide](migration-0.4.0.md) for breaking changes.
Migration from the removed hybrid API is covered in [0.3.0](migration-0.3.0.md).
For Apple cloud, complete [PCC eligibility, entitlement and host setup](private-cloud-compute.md)
before enabling or selecting the cloud model.

## Availability, locales and session ownership

`getCapabilities()` describes the package/runtime feature surface, not whether
Apple Intelligence is enabled now. Call `checkAvailability()` for the intended
mode, cloud policy and locale. Recheck after settings or asset changes, and
handle request errors even after a successful preflight.

`getDiagnostics(localeIdentifier: ...)` reports model language support and
system locale; it cannot read the Siri language. `getSupportedLanguages()` is
specifically the intersection with modern Speech locales. Text-only apps can
use `getCapabilities().supportedLanguages` and locale-specific availability
without requiring Speech support.

`SessionOptions` defines the model, cloud policy, instructions, tools, optional
`localeIdentifier`, content-tagging use case and transcript error policy.
`metadata` is not automatically inserted into the prompt. Local locale preflight
validates support; instructions must still tell the model which language to use.
PCC language preflight is intentionally unavailable while its diagnostic
getters remain disabled.

One-shot facade calls create and dispose their own session. A reused
`FoundationModelSession` keeps native conversation context, and exposes:

| Method | Contract |
| --- | --- |
| `respond(prompt, options: ...)` | One complete text response. |
| `stream(prompt, schema: ..., options: ...)` | Cumulative text snapshots and a terminal result; an optional schema enables guided JSON. Failures may arrive as stream errors. |
| `streamStructured(prompt: ..., schema: ..., options: ...)` | Cumulative guided JSON snapshots and a decoded terminal result. |
| `generateStructured(prompt: ..., schema: ..., options: ...)` | Guided generation with a supported object-root schema. |
| `prewarm(promptPrefix: ...)` | Hint to preload resources; not an availability guarantee. |
| `measureTokenBudget(prompt: ..., schema: ..., options: ...)` | Separate component measurements for the actual session model; unavailable fields remain unknown. |
| `countTokens()` | Local transcript token count, iOS 26.4+ with an Xcode 27 build. |
| `cancelActiveRequest()` | Cancel and await the matching native work. |
| `dispose()` | Release the native session; concurrent callers await the same disposal. |

A session is single-flight, including prewarm and transcript token counting.
Separate sessions may operate concurrently. Normal facades share the native
transport so constructing another client does not steal stream/tool callbacks.
Background-isolate and multiple-engine sharing are not promised.

After `contextSizeExceeded`, create a fresh session with a bounded summary or
split an independent task. No automatic history trimming, summarization,
persistence or cross-provider replay occurs.

## Generation options and budgets

- `maximumResponseTokens`: positive answer budget. The model can stop sooner.
- `samplingMode`: greedy, random top-K, or probability-threshold sampling.
  Top-K must be positive; probability and finite temperature are in `[0, 1]`.
- `samplingSeed`: optional nonnegative seed. Older SDK paths may lack seeding;
  repeatability across OS/model versions is not guaranteed.
- `maximumToolCalls`: 1–128 calls per request, default 16. A budget breach fails
  the request; it does not guarantee the model produced an answer.
- `toolCallingMode`: `allowed` by default. `required` and `disallowed` need iOS
  27 and a compatible SDK. Required mode needs registered tools.
- `reasoningLevel`: automatic by default; explicit/custom values need iOS 27
  and support from the selected model.
- `includeSchemaInPrompt`: uses the older guided-generation option on iOS 26
  and `ContextOptions` on iOS 27.
- `cloudPolicy`: nullable request restriction. Null inherits session selection;
  `never` rejects PCC. Other values cannot change the selected model.
- `timeout`: positive duration, default 60 seconds. Existing fallback: a
  deadline for one-shot calls, or inactivity between stream events.
- `firstResponseTimeout`: optional stream deadline until the first text/JSON
  snapshot or terminal response. Tool/unknown events do not extend it. Until
  that result arrives, this replaces the initial inactivity deadline.
- `idleTimeout`: optional inactivity limit after the first result, reset by
  stream events. Without an explicit first-response deadline it applies from
  the start. It falls back to `timeout`.
- `totalTimeout`: optional absolute generation duration. For a stream it runs
  independently of events; for one-shot calls it replaces `timeout`.
- First-response and idle settings apply only to streaming. All supplied
  durations must be positive. Timers start on subscription; pausing a consumer
  does not suspend native generation or its deadlines. OS suspension can delay
  Dart timers, so these options do not promise wall-clock enforcement while the
  process is suspended.

Timeout errors carry `termination.status == GenerationStatus.timedOut` and
`termination.timeoutPhase`. Native cancellation and subscription cleanup are
awaited before the session can be reused; that cleanup may outlast the deadline.
Cancellation failures require disposal and a fresh session. Wait for stream
completion/cancellation cleanup before another request, even after an error event.

### Token measurements and actual usage

`models.countTokens(prompt)` counts the constructed prompt with the default local
model, including extracted attachment text. `session.countTokens()` counts its
local transcript. Prefer the session budget API for model-specific components:

```dart
final budget = await session.measureTokenBudget(
  prompt: prompt,
  schema: schema,
  options: const GenerationOptions(maximumResponseTokens: 1200),
);
final measurement = budget.components['prompt'];
if (measurement?.precision == TokenPrecision.exact) {
  print(measurement?.count);
}
```

`TokenBudget.components` has `prompt`, `instructions`, `tools`, `schema` and
`transcript`. On supported local iOS 26.4+ SDK/runtime paths, `exact` means the
native tokenizer's count for that particular component and session model.
`estimated` is reserved for explicitly labeled estimates; this implementation
never substitutes an estimate. `unavailable` supplies no count and a reason.
PCC has no exposed matching token-count API in the inspected SDK, so its
measurements are unavailable. Older runtimes return unavailable rather than
fabricating zero. An absent local component can have an exact zero count.

These scopes may overlap: transcript entries can already contain instructions
and tool context. Do not sum them as an exact serialized-request count. The
framework does not expose an exact complete request count through this API.
`maximumResponseTokens` echoes the requested reservation, not observed output.
`modelIdentifier` identifies the selected mode/use case, not an immutable Apple
model revision. Local `contextWindowTokens` uses the selected model's native
context size; PCC remains null. Do not
assume local and PCC have the same capacity. Measurements do not mutate the
transcript or reserve capacity, and token counting itself has no generation
timeout. It occupies the session until the native measurement finishes.

On iOS 27, `ModelResponse.usage` may contain actual native input, cached-input,
output, reasoning and total token counts. Earlier systems return null. Each
counter is also nullable when absent, never synthesized as zero. Cached and
reasoning counts are subcategories, not extra tokens to add to `totalTokenCount`.
`usedMode` identifies the selected Apple backend. Neither a request estimate
nor an observed token count alone establishes the cause of truncation.

### Result and termination

`ModelResponse.termination` describes operation completion; its `reason` remains
`unknown` when Apple supplies no explicit stop reason. `nativeReason` stays null
unless actually supplied; it is not inferred from text length or usage.
`structuredContentComplete` reports the native completeness flag where provided;
structured streaming additionally requires complete, decodable final JSON.
This does not prove that every source row or correct amount was extracted.

`FoundationModelsException.termination` and `FailureEvent.termination` identify
failure, cancellation, timeout phase, context overflow, refusal or invalid
structure through the package's typed error mapping. Error categories do not
claim a native stop reason. A stream that closes without a terminal event now
fails with `nativeFailure` and `details['streamClosedWithoutResult'] == true`.
[Apple documents](https://developer.apple.com/documentation/foundationmodels/generationoptions/maximumresponsetokens)
that hitting an output limit can end generation early without an error; a
successful completion therefore does not establish a natural stopping point.

### Request diagnostics

```dart
final options = GenerationOptions(
  firstResponseTimeout: const Duration(seconds: 45),
  idleTimeout: const Duration(seconds: 20),
  totalTimeout: const Duration(minutes: 3),
  diagnostics: GenerationDiagnostics(
    captureOutput: false,
    onEvent: (event) {
      updateRequestStatus(event.requestId, event.stage, event.elapsed);
    },
  ),
);
```

`updateRequestStatus` is a host callback. Events contain a package request ID,
optional native stream ID, session ID, effective mode, OS/model metadata,
host SDK identifier when available,
package version, elapsed time, first-result latency, terminal usage and typed
termination when available. An unknown native model revision/SDK version is not
invented. Events describe accepted generation requests; preflight, token
measurement and invalid options are not generation telemetry.

Callbacks are synchronous, exceptions are isolated, and they must remain small.
There is no automatic console logging, persistence or transmission. Prompts,
schemas, tool arguments/results, error messages and hidden reasoning are not
captured. `captureOutput: true` separately opts into the exact string delivered
by the framework for each snapshot/final response, not remote network bytes.
`maximumOutputCharacters` defaults to 65536 UTF-16 code units per event. Larger
strings are omitted with `outputOmitted: true`; no prefix is passed off as exact.
The callback recipient controls retention, redaction and export. Do not enable
capture by default for sensitive documents. Events are not buffered for replay.

## Structured generation

```dart
final response = await models.generateStructured(
  prompt: const Prompt.text('The appointment is with Morgan on Friday.'),
  schema: const StructuredSchema.object(
    name: 'Appointment',
    properties: <String, SchemaProperty>{
      'person': SchemaProperty.string(),
      'day': SchemaProperty.string(),
    },
    requiredProperties: <String>['person', 'day'],
  ),
  mode: ModelMode.local,
  cloudPolicy: CloudPolicy.never,
  options: const GenerationOptions(maximumResponseTokens: 120),
);
final value = response.structuredValue;
```

The Dart schema root is an object. Properties support strings, string enums,
integers, numbers, booleans, arrays with an `items` schema, and nested objects.
Top-level `requiredProperties` defaults to an empty list; nested objects created
with `SchemaProperty.object` currently require all declared child properties.
The native tool schema also accepts the `required` and string `enum` aliases.
Unsupported constraints (for example regex, ranges, references or unions) are
rejected rather than silently ignored. Nesting is limited to 16 levels and
objects to 128 properties. Internal type names are derived uniquely from
their full schema paths; repeated nested property names do not share types.
Mapping failures expose `FoundationModelsException.details['schemaPath']`
and a path-bearing message. Native framework errors may lack a property path.

`structuredValue` is typed `Object?` to preserve decoded channel values, but
this does not add scalar/array root constructors to the public schema API.
Guided structure is not semantic correctness: validate extracted facts and
business constraints in the application.

### Guided streaming

```dart
await for (final event in session.streamStructured(
  prompt: const Prompt.text('The appointment is with Morgan on Friday.'),
  schema: const StructuredSchema.object(
    name: 'Appointment',
    properties: <String, SchemaProperty>{
      'person': SchemaProperty.string(),
      'day': SchemaProperty.string(),
    },
    requiredProperties: <String>['person', 'day'],
  ),
)) {
  switch (event) {
    case TextSnapshotEvent(:final text):
      print(text);
    case CompletionEvent(:final response):
      print(response.structuredValue);
    default:
      break;
  }
}
```

`stream(prompt, schema: schema, options: ...)` is equivalent to
`streamStructured(prompt: prompt, schema: schema, options: ...)`.
`TextSnapshotEvent.text` is a complete replacement snapshot, not a JSON chunk
to append or consume as a final result. `CompletionEvent.response.text` is the
complete JSON string and `structuredValue` is decoded only after native content
reports completion. A missing final snapshot, incomplete JSON, or a decoding
failure returns `parsingFailure`; preserve the user's input and retry or
simplify the schema. This needs iOS 26+ and normal model availability; PCC adds
the existing iOS 27 host opt-in and entitlement requirements.

## Tools

```dart
final class DeviceTimeTool implements ModelTool {
  const DeviceTimeTool();
  @override
  String get name => 'device_time';
  @override
  String get description => 'Return the current device timestamp.';
  @override
  Map<String, Object?> get parameters => const <String, Object?>{
    'type': 'object',
    'properties': <String, Object?>{},
  };
  @override
  Duration get timeout => const Duration(seconds: 3);
  @override
  Object? call(Map<String, Object?> arguments) =>
      DateTime.now().toIso8601String();
}
```

Register tools at session creation through `SessionOptions.tools`. Names must
be unique and non-empty. Parameters must use a supported object schema, and
tool timeouts must be between 1 ms and 10 minutes. Return codec-safe values
(strings, numbers, booleans, null, lists and string-keyed maps).

Dart and Swift bound tool waits. Native results above 64,000 characters are
replaced with an explicit size failure, not silently truncated data. Keep
results far smaller to fit the local context. Tool failures are returned to the
model as failure text; application code must decide whether an action succeeded.
Malformed non-object tool arguments are rejected before invoking the handler.

Cancellation stops waiting; it cannot interrupt arbitrary Dart code or undo an
external side effect. Make mutating tools idempotent and validate authorization
inside the handler. Do not assume `ToolCallEvent` is a complete tool audit log:
actual tool execution is delivered through the registered `ModelTool` callback.

## Files and images

`models.pickFile(kind: ...)` opens the native document picker; cancellation
returns null. The returned path is an app-local temporary copy with a separate
original display name. `kind: any` means the picker accepts any item, not that
the model understands every format. The host owns retention and deletion of
picked temporary copies after all requests using them finish.

| Attachment | Handling and limits |
| --- | --- |
| UTF-8 text, Markdown, JSON, CSV | At most 5 MiB; non-empty text is inserted into the prompt. |
| Text PDF | At most 20 MiB; PDFKit extraction, at most 5 MiB extracted text. |
| Image bytes/files on iOS 27 | At most 50 MiB; downsample to 2,048 pixels, then local Vision OCR/classification/barcodes. |
| Scanned PDF | OCR externally or supply individual images; text extraction alone is insufficient. |
| Audio | Use `transcribeAudio()` first, then send bounded text. |
| Word/binary/unsupported files | Typed error; convert to a supported format. |

```dart
final file = await models.pickFile(kind: FoundationModelsFileKind.text);
if (file != null) {
  final prompt = Prompt(
    text: 'Summarize the supplied document.',
    attachments: <PromptAttachment>[file.toPromptAttachment()],
  );
  final count = await models.countTokens(prompt);
  print(count);
}
```

Extraction and file validation do not guarantee complete interpretation.
Image preprocessing cannot answer every visual question or recover every
receipt/table field. A scanned or partly scanned PDF may need OCR even when
some pages contain text. Verify coverage; never silently drop missing pages in
financial or other accuracy-sensitive workflows.

Native Foundation Models image attachments remain disabled on **all supported
runtimes** in this version because of previously reproduced beta ABI crashes.
The new iOS 27.2 data-attachment APIs are also not exposed. See the
[SDK audit](ios-27.2-audit-2026-09-19.md).

## Speech

```dart
final transcript = await models.transcribeAudio(
  const AudioTranscriptionRequest(
    filePath: '/absolute/path/to/audio.m4a',
    localeIdentifier: 'en_US',
    mode: AudioTranscriptionMode.onDevice,
    timeout: Duration(minutes: 2),
  ),
);
```

Live input:

```dart
final subscription = models.liveTranscription(
  request: const LiveTranscriptionRequest(
    localeIdentifier: 'en_US',
    mode: AudioTranscriptionMode.onDevice,
  ),
).listen(
  (event) => print(event.text),
  onError: (Object error) => print(error),
);
await subscription.cancel();
```

Only one live capture is allowed. Each event is the whole recognized snapshot;
modern Speech finalizes segments while the capture continues, so segment
finality is not the end of the whole stream. Cancellation ends capture; it does
not promise an extra final transcript event. Preserve the last received text.

The modern engine uses SpeechAnalyzer/SpeechTranscriber on iOS 26+, with
AssetInputSequenceProvider/CaptureInputSequenceProvider on iOS 27. Supported
locales and asset downloads are determined at runtime. Metadata identifies the
engine and effective mode. `taskHint` and `addsPunctuation` apply to the legacy
SFSpeechRecognizer path; the modern path uses its native transcription options.

`onDevice` forbids server recognition. `automatic` may use the Apple Speech
server when local recognition is unavailable; `server` permits that networking
path and is not a PCC request. File transcription timeout cancels the native
request and reports `transcriptionTimeout`. Asset acquisition or native cleanup
may delay completion; the package cannot guarantee transcription latency.

For a complete example with Spanish numeric text and physical integration
scenarios, see [document extraction](document-extraction.md).

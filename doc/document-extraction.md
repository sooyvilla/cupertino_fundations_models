# Structured document extraction

The local 1.9.0 example adds F01 constraints: at most 50 output rows, positive
source row numbers, and an uppercase three-letter currency or `unknown`.
The currency pattern checks spelling, not membership in an ISO currency list.
Use bounded chunks for longer documents and validate source coverage; an output
limit does not establish that every row was extracted.

F02 configures the row object's own required list: sourceRow, description and
amountText are required, while dateText may be omitted when not supplied. The
outer object and other constraints remain unchanged. Missing optional fields
must not be filled with invented data or confused with an explicit null schema.

F03 now defines this example through `StructuredSchema.fromJsonSchema`. The
outer and row objects explicitly use `additionalProperties: false`; JSON
`required` preserves the same field choices. `allowSwiftPatterns: true` makes
the currency pattern's native dialect explicit. Manual constructors remain an
equivalent alternative. See the [import profile](usage.md#import-json-schema-definitions).

The complete [Dart example](../example/lib/document_extraction.dart) owns a
session, measures its budget, streams a schema-guided response and disposes the
session even when its subscription is cancelled. It accepts an explicit Apple
model/policy; local-only is the default. Call availability preflight in the host
feature and handle request errors regardless of its result.

```dart
await for (final event in extractDocument(
  models: CupertinoFoundationModels(),
  document: fictionalDocument,
  onBudget: (budget) {
    final prompt = budget.components['prompt'];
    print('${prompt?.precision}: ${prompt?.count}');
  },
)) {
  switch (event) {
    case TextSnapshotEvent(:final text):
      displayPartialJson(text);
    case CompletionEvent(:final response):
      reviewExtractedRows(response.structuredValue);
    case FailureEvent(:final code):
      showExtractionFailure(code);
    default:
      break;
  }
}
```

Import the example file to use `extractDocument` and `fictionalDocument`.
`displayPartialJson`, `reviewExtractedRows` and `showExtractionFailure` represent
host UI callbacks. Snapshots replace prior JSON; they may be incomplete and are
not committed financial data. Errors can also be thrown by the stream.

## Structured progress

F05 assigns full orders to the root and row objects: currency before rows, and
sourceRow/dateText/description/amountText inside each row. Required-field choices
remain unchanged; an unavailable optional date may still be omitted.

```dart
await for (final event in extractDocument(
  models: CupertinoFoundationModels(),
  document: fictionalDocument,
  includeStructuredSnapshots: true,
)) {
  if (event is TextSnapshotEvent) {
    final snapshot = event.structuredSnapshot;
    if (snapshot != null) replaceDocumentProgress(snapshot);
  } else if (event is CompletionEvent) {
    final result = event.response.decodeStructured<ExtractedDocument>(
      decoder: ExtractedDocument.fromStructuredValue,
    );
    reviewExtractedDocument(result.value, result.response);
  }
}
```

The host's progress callback displays immutable projected data and native
observed/complete paths; a begun amount string may be present while its value
is withheld. Replace prior state rather than merge rows, and do not interpret or
save partial amounts. Root completeness still does not end the stream. Catch
stream/package failures and final conversion failures using the existing app
error flow. See [snapshot and order contracts](usage.md#structured-snapshots-and-property-order).

## Optional explicit null dates

F06 reuses root $defs/DocumentRow through a local $ref. Default date omission
is preserved. Pass explicitNullDates:true to extractDocument or
extractDocumentDecoded only when every row should include dateText, with null
when no date was supplied. This selects nullableDocumentSchema and requires
OS26.4 plus compatible SDK support; check capability/availability and handle errors.

```dart
final result = await extractDocumentDecoded(
  models: CupertinoFoundationModels(),
  document: fictionalDocument,
  explicitNullDates: true,
);
final raw = result.response.structuredValue! as Map<String, Object?>;
final first = (raw['rows']! as List<Object?>).first! as Map<String, Object?>;
final wasPresent = first.containsKey('dateText');
final date = first['dateText'];
```

The app model's nullable date may represent either missing/null; the retained
raw response preserves presence if it matters. Do not invent a date or silently
fall back to omission. The shared row order is configured at #/$defs/DocumentRow,
the definition path rather than the reference use site. See
[graph and presence semantics](usage.md#null-anyof-and-local-references).

## Typed final document

F04 adds the one-shot `extractDocumentDecoded` alternative to the same example:

```dart
final result = await extractDocumentDecoded(
  models: CupertinoFoundationModels(),
  document: fictionalDocument,
);
final document = result.value;
for (final row in document.rows) {
  print('${row.sourceRow}: ${row.amountText}');
}
final nativeResponse = result.response;
reviewExtractedDocument(document, nativeResponse);
```

The app-owned [document decoder](../example/lib/extracted_document.dart) and
[row decoder](../example/lib/extracted_document_row.dart) convert only declared
field types. They preserve amount/date spelling, leave an absent date null and
return an immutable row list. They do not calculate amounts, verify currency
membership or establish source coverage. The facade disposes its session before
the synchronous decoder runs; `.response` retains text, native route, metadata,
nullable usage and termination.

To keep the existing stream, convert its `CompletionEvent.response` explicitly:

```dart
final result = response.decodeStructured<ExtractedDocument>(
  decoder: ExtractedDocument.fromStructuredValue,
);
reviewExtractedDocument(result.value, result.response);
```

`reviewExtractedDocument` is the host's review flow. Perform availability preflight
and catch `FoundationModelsException` around generation. Catch
`StructuredDecodingException` separately for incompatible app data; it retains
the original response, cause and stack. A completed native diagnostic does not
mean app conversion succeeded. The [final-value contract](usage.md#decode-final-values-to-dart-types)
describes missing/incomplete payloads, nullable outputs and cleanup. Partial JSON
snapshots are not passed to this decoder, and conversion does not authorize
saving the result.

The fictitious sample deliberately preserves `-1.234,56`, `+2.000,00` and
`-3,50` as strings. The app must interpret locale/currency, retain signs, use
decimal-safe arithmetic, reject malformed values and compare source row IDs and
counts. Valid JSON does not guarantee correct amounts or complete extraction.

For long tables, split source text into bounded chunks with stable row IDs.
Keep document identity, deduplication, coverage tracking and reconciliation in
the application. Use a fresh session for independent chunks to avoid accumulating
the entire document transcript. Neither file size nor an estimated output
budget proves that every row fits or was returned.

## Optional reproduction

Set `GenerationDiagnostics(captureOutput: true, onEvent: ...)` only when the
feature explicitly needs the exact strings delivered by Apple. The callback is
the app's retention boundary: the plugin does not save or upload diagnostic
events. Oversized output is omitted with `outputOmitted: true`, not silently
truncated and described as exact. See [diagnostics](usage.md#request-diagnostics).

## Physical integration scenarios

These are suggested future checks, not results from this release:

| Scenario | Evidence to collect |
| --- | --- |
| Local guided stream on iOS/iPadOS and macOS 26 and 27 | Partial snapshots, decoded terminal structure, source row coverage and exact amounts. |
| Long tables and deliberately small output limit | Structure status, usage when supplied, unknown stop reason; no inferred truncation proof. |
| Cancel before first output and mid-stream | Awaited cleanup, no later output, safe session disposal. |
| First-result, idle and total deadlines | Typed timeout phase and no new request until cleanup finishes. |
| Background/foreground transition | Observed OS interruption and typed error; no promise of background execution. |
| PCC on an entitled physical device | Approved signature/profile, explicit cloud policy, network/quota failures and guided completion. |
| Repeated nested property/enum names | Distinct internal types with the original output property names preserved. |

PCC requires [Apple approval and host setup](private-cloud-compute.md). A build,
simulator run, local-model success or package publication cannot establish PCC
runtime behavior. Automated tests, builds and physical checks were not run for
this release.

## Explicit history alternative

F07 offers a local alternative when the app needs to retain this extraction's
native conversation context:

```dart
final extracted = await extractDocumentWithHistory(
  models: models, document: fictionalDocument,
);
final document = extracted.result.value;
final originalResponse = extracted.result.response;
final history = extracted.history;
```

The helper owns a session, waits for final generation/conversion, explicitly
exports its history and disposes in `finally`, including export failure. Existing
streaming and one-shot alternatives do not export or persist history. Use the
history only when continuing context is required; it is sensitive and separate
from the reviewed domain result. The caller owns account/thread selection,
storage, encryption and retention. `explicitNullDates` remains optional.

To continue, call `models.restoreSession(history: history)` and dispose that new
session after use. Restoration requires the same known platform/OS/SDK and session
context; tool-bearing sessions also need matching current registrations. The native
archive retains options/formats and supported metadata, without old tool execution.
This profile accepts complete text/structures and rejects attachment/data entries,
partial structure and pending tools; at most 256 entries/1 MiB of native archive.
No descriptor editing, model-version guarantee, automatic storage or external
provider replay is included. See [history contract](usage.md#export-and-restore-session-history).


## Optional generated document models

F09 adds separate annotated GeneratedDocument/GeneratedDocumentRow models and
checked-in *.structured.dart companions. The existing extraction/chat stays on
its manual/imported route. After explicitly choosing generation:

```dart
final extracted = await models.generateStructuredDecoded<GeneratedDocument>(
  prompt: Prompt.text(fictionalDocument),
  schema: GeneratedDocumentCodec.schema,
  decoder: GeneratedDocumentCodec.decode,
);
```

Import both the model and companion. The generated contract keeps currency
spelling, at most 50 rows, positive source identifiers, explicit generation order
and optional date omission. It matches equivalent manual/inline-imported schemas
and preserves original amount/date strings; review source coverage and facts.
GeneratedDocumentPartial views F05 snapshots as typed fields with independent
presence/completeness/value, including partial row containers. It never constructs
final document models before completion. The additional GeneratedGenerationChoices
example demonstrates named constructors, enums, booleans/numbers and explicit
nullable list indices; nullable schemas still require OS26.4.

Code generation was executed locally and its output is compiled/tested by Flutter
unit tests; no native app or model inference is claimed. See
[installation, profile and safe partial use](usage.md#optional-dart-generation).

## Optional adapter boundary

F10 can adapt the existing extraction stream without changing its budget,
schema, route or session ownership:

```dart
import 'package:cupertino_fundations_models/cupertino_fundations_models_adapters.dart';

final progress = extractDocument(
  models: models,
  document: fictionalDocument,
  includeStructuredSnapshots: true,
).adaptEvents();
```

The extraction helper still owns its session. The adapter forwards original
structured snapshots and terminal responses by identity; `textUpdate` gives
append/replacement operations for a separate text buffer. Use original F05
snapshots for typed progress and decode only the original final response.
For a new one-shot request, `FoundationModelsAdapter.generate` accepts a manual,
imported or generated schema and owns creation/disposal; it does not implicitly
run this extraction helper's budget measurement. See
[adapter contracts](usage.md#optional-adapters-and-stream-updates) and
[framework recipes](app-owned-routing.md#optional-framework-bindings).

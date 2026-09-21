# Structured document extraction

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
| Local guided stream on iOS 26 and 27 | Partial snapshots, decoded terminal structure, source row coverage and exact amounts. |
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

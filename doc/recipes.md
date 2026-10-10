# Flutter local AI recipes for Apple platforms

The same recipes apply to iOS/iPadOS and macOS. The constrained recipe needs
the locally prepared 1.9.0 checkout; earlier recipes also work with 0.5.0.
See [platform status and Mac host setup](apple-platforms.md).

Here are small tasks you can adapt to your Flutter app: summarize a passage,
extract appointment fields and classify a note. Start with
[installation and availability](local-ai-ios.md). Each recipe uses
`ModelMode.local` and `CloudPolicy.never` to keep generation on the device.
The snippets describe the API; native model output from them has not been
executed or benchmarked in this documentation update.

## Summarize a short passage

Use the complete availability-checked, session-owned example in the
[English tutorial](local-ai-ios.md#generate-your-first-summary)
or [Spanish tutorial](README.es.md#generar-tu-primer-resumen).
Use supplied facts, bound input and output, and keep the manual path available.

## Extract a person's name and an explicitly supplied day

Pass a schema instead of relying on a prompt that merely requests JSON.
This function returns a decoded map for application review, or null when the
model is unavailable or the expected fields cannot be accepted.

```dart
import 'package:cupertino_fundations_models/cupertino_fundations_models.dart';

Future<Map<String, Object?>?> extractAppointment(String text) async {
  final models = CupertinoFoundationModels();
  try {
    final availability = await models.checkAvailability(
      mode: ModelMode.local,
      cloudPolicy: CloudPolicy.never,
      localeIdentifier: 'en_US',
    );
    if (!availability.isAvailable) return null;

    final response = await models.generateStructured(
      prompt: Prompt.text(text),
      mode: ModelMode.local,
      cloudPolicy: CloudPolicy.never,
      instructions:
          'Extract only the person and day explicitly written in the text. '
          'Use an empty string for a missing field. Do not infer a calendar date.',
      schema: const StructuredSchema.object(
        name: 'Appointment',
        properties: <String, SchemaProperty>{
          'person': SchemaProperty.string(),
          'day': SchemaProperty.string(),
        },
        requiredProperties: <String>['person', 'day'],
      ),
      options: const GenerationOptions(maximumResponseTokens: 120),
    );
    final value = response.structuredValue;
    if (value is! Map<String, Object?>) return null;
    if (value['person'] is! String || value['day'] is! String) return null;
    return value;
  } on FoundationModelsException {
    return null;
  }
}
```

The facade owns session disposal for `generateStructured()`. A valid schema
does not prove the extracted name/day is correct. Compare with the input and
ask the user before creating an appointment. See
[document extraction](document-extraction.md) for a larger bounded example.

## Classify text into a small vocabulary

An enum prevents arbitrary category strings. Keep an `other` label for text
outside the feature's scope and validate the decoded result independently.

```dart
import 'package:cupertino_fundations_models/cupertino_fundations_models.dart';

Future<String?> classifyNote(String text) async {
  final models = CupertinoFoundationModels();
  const categories = <String>['work', 'personal', 'other'];
  try {
    final availability = await models.checkAvailability(
      mode: ModelMode.local,
      cloudPolicy: CloudPolicy.never,
      localeIdentifier: 'en_US',
    );
    if (!availability.isAvailable) return null;

    final response = await models.generateStructured(
      prompt: Prompt.text(text),
      mode: ModelMode.local,
      cloudPolicy: CloudPolicy.never,
      instructions:
          'Classify the note as work, personal or other. '
          'Choose other if the text is ambiguous or unrelated.',
      schema: const StructuredSchema.object(
        name: 'NoteCategory',
        properties: <String, SchemaProperty>{
          'category': SchemaProperty.string(enumValues: categories),
        },
        requiredProperties: <String>['category'],
      ),
      options: const GenerationOptions(maximumResponseTokens: 60),
    );
    final value = response.structuredValue;
    if (value is! Map<String, Object?>) return null;
    final category = value['category'];
    if (category is! String || !categories.contains(category)) return null;
    return category;
  } on FoundationModelsException {
    return null;
  }
}
```

The label is an AI suggestion, not an authorization or irreversible decision.
Allow correction and preserve a deterministic default.

## Constrain a support-ticket triage

Use bounds for a severity rating and an exact count for suggested actions.
The ticket field is optional, so a missing identifier does not need to be invented.
This uses F01 in the prepared 1.9.0 checkout and does not require code generation.

```dart
const schema = StructuredSchema.object(
  name: 'SupportTriage',
  requiredProperties: ['severity', 'actions'],
  properties: {
    'severity': SchemaProperty.integer(minimum: 1, maximum: 5),
    'ticket': SchemaProperty.string(pattern: r'^SUP-[0-9]{4}$'),
    'actions': SchemaProperty.array(
      items: SchemaProperty.string(),
      exactItems: 3,
    ),
  },
);

final response = await models.generateStructured(
  prompt: const Prompt.text('SUP-1234: the login button does nothing.'),
  schema: schema,
  mode: ModelMode.local,
  cloudPolicy: CloudPolicy.never,
  instructions: 'Rate severity from 1 to 5. Copy the ticket identifier only '
      'when supplied. Suggest three short actions for human review.',
  options: const GenerationOptions(maximumResponseTokens: 300),
);
```

Check availability before this request and catch native failures. If bounds
come from runtime app settings, catch `ArgumentError` for invalid definitions
and let the user correct the configuration. Strings use Swift regex syntax.
Use `minItems`/`maxItems` when a varying number of source records is valid.
Do not save a ticket or run the suggested actions merely because the response
matches the schema. See [constraint semantics](usage.md#structured-generation).

## Extract a list without inventing optional contact details

F02 in the prepared 1.9.0 checkout can return a root list directly. Require the
name and allow the email to be absent when it was not supplied:

```dart
const contacts = StructuredSchema.array(
  name: 'Contacts',
  maxItems: 10,
  items: SchemaProperty.object(
    requiredProperties: ['name'],
    properties: {
      'name': SchemaProperty.string(),
      'email': SchemaProperty.string(),
    },
  ),
);
final response = await models.generateStructured(
  prompt: const Prompt.text('Morgan; Riley, riley@example.test'),
  schema: contacts,
  mode: ModelMode.local,
  cloudPolicy: CloudPolicy.never,
  instructions: 'Extract supplied contacts. Omit email when absent. '
      'Return an empty list when no contact is supplied.',
);
final value = response.structuredValue;
if (value is List<Object?>) {
  for (final contact in value) {
    if (contact is Map<String, Object?>) {
      print(contact['name']);
    }
  }
}
```

Perform the usual availability/error handling and review the data. An empty
list is a valid result. For nested objects, `requiredProperties: null` or omission
keeps the old all-required behavior; `[]` explicitly makes all children optional.
The same choices apply at deeper levels and to item objects in arrays.

## Reuse a compatible JSON Schema definition

F03 in local 1.9.0 can define the same contact list from schema data:

```dart
final contacts = StructuredSchema.fromJsonSchema({
  'title': 'Contacts',
  'type': 'array',
  'maxItems': 10,
  'items': {
    'type': 'object',
    'additionalProperties': false,
    'required': ['name'],
    'properties': {
      'name': {'type': 'string'},
      'email': {'type': 'string'},
    },
  },
});
```

Pass it to the same generation/streaming/budget APIs used above. The importer
copies the definition and rejects unsupported keywords with a typed error and
input path. Every object must be explicitly closed; omitted JSON `required`
makes that object's fields optional. It does not apply the manual nested
all-required default or silently discard constraints. Read the
[exact subset](usage.md#import-json-schema-definitions) before importing an
existing definition. Pattern use additionally requires explicit Swift dialect
opt-in. The [document example](document-extraction.md) shows bounded imported
rows with optional dates; no Dart generator is needed.

## Convert the final value and keep the response metadata

F04 in local 1.9.0 can reuse the same contact schema with an app decoder:

```dart
final result = await models.generateStructuredDecoded<List<(String, String?)>>(
  prompt: const Prompt.text('Morgan; Riley, riley@example.test'),
  schema: contacts,
  decoder: (value) => (value! as List<Object?>).map((entry) {
    final fields = entry! as Map<String, Object?>;
    return (fields['name']! as String, fields['email'] as String?);
  }).toList(),
  mode: ModelMode.local,
  cloudPolicy: CloudPolicy.never,
);
for (final (name, email) in result.value) {
  print('$name: ${email ?? "not supplied"}');
}
final nativeResponse = result.response;
```

The result retains the original response text, route, metadata, nullable counters
and termination. A model-generated value still needs app review. Catch
`StructuredDecodingException` separately for a failed conversion, preserving its
response for recovery; native/schema/JSON failures keep their existing contracts.
No automatic retry or write occurs. For a final response already obtained from
generation or `CompletionEvent`, call `response.decodeStructured<T>` directly.
Read [conversion and cleanup](usage.md#decode-final-values-to-dart-types) and the
[typed document example](document-extraction.md#typed-final-document).

## Display complete fields during a guided stream

F05 can enrich the contact stream while keeping the final result separate:

```dart
await for (final event in session.streamStructured(
  prompt: const Prompt.text('Morgan supplied a name only.'),
  schema: contacts,
  options: const GenerationOptions(includeStructuredSnapshots: true),
)) {
  if (event is TextSnapshotEvent && event.structuredSnapshot != null) {
    replaceContactProgress(event.structuredSnapshot!);
  } else if (event is CompletionEvent) {
    reviewContacts(event.response.structuredValue);
  }
}
```

The host callbacks replace display state and review final data. Do not merge
snapshots, repair incomplete strings/numbers or call a final domain decoder before
completion. Choose full property permutations per object when an earlier field
helps display; for imported contacts, the item definition path is `#/items`.
Omission keeps alphabetical order. Read [paths, completeness and cancellation](usage.md#structured-snapshots-and-property-order).

## Reuse a nullable contact definition

F06 supports explicit null and local references without code generation:

```dart
const schema = StructuredSchema.object(
  name: 'Profile',
  definitions: {
    'NullableName': SchemaProperty.anyOf(alternatives: [
      SchemaProperty.string(), SchemaProperty.nullValue(),
    ]),
  },
  properties: {'name': SchemaProperty.reference('NullableName')},
  requiredProperties: ['name'],
);
```

Here name must be present and may be null. Omitting it remains different from
explicit null. Check OS26.4/SDK null support and availability, then handle native
errors rather than weakening the schema. At a null output root, use
ModelResponse.hasStructuredValue before applying a nullable final decoder.
For imported schemas use root $defs/$ref and anyOf; remote pointers, cycles and
oneOf exclusivity are outside the profile. See
[graph limits and presence](usage.md#null-anyof-and-local-references) and the
[explicit date mode](document-extraction.md#optional-explicit-null-dates).

## Adapt an application backend or delta consumer

F10's optional FoundationModelsAdapter retains Apple results/events through an
app-owned boundary. For an existing session, adaptEvents borrows it; the caller
still disposes the session. Apply TextUpdate using append/replacement or fullText,
including final changes. Strict append-only destinations reject revisions and await
cleanup. Do not re-execute observed tool events or invent missing usage counters.
See [complete adapter contract](usage.md#optional-adapters-and-stream-updates),
[app example](../example/lib/apple_text_backend.dart) and
[framework binding decisions](app-owned-routing.md#optional-framework-bindings).

## Choose generated object-model companions

If the user prefers classes to define this contract, choose the optional F09 dev
package and annotate those models. Explicit generation creates ClassCodec.schema
and ClassCodec.decode for the existing generateStructuredDecoded API, plus
ClassPartial for F05 snapshots. The same guides/native policies apply; final
conversion is structural and partials remain nonterminal. No new engine, provider
routing or generated Swift is introduced. Keep manual/imported definitions for
contracts outside the bounded profile. See [setup and choices](usage.md#optional-dart-generation)
and [generated document alternative](document-extraction.md#optional-generated-document-models).

## Keep local readiness visible

For a requested readiness display, query text-only language labels independently
of dictation, then own a local watch:

```dart
final languages = await models.getTextModelLanguages();
final subscription = models.watchAvailability(localeIdentifier: 'es_CO').listen(
  updateReadiness, onError: showReadinessError,
);
await subscription.cancel();
```

Observation is the default; pollingInterval selects explicit one-second-to-five-
minute polling. Both pause native work outside foreground/on subscription pause
and recheck on resume. There is no inference, asset request or PCC selection.
Use the selected local useCase/locale, retain request error handling and await
cleanup. Dictation can keep getSupportedLanguages; advertised text languages are
not every supported regional locale or current readiness. See
[monitoring contract](usage.md#observable-local-availability-and-text-languages).

## Resume a compatible conversation

For a user-requested resumable chat, explicitly export after work completes:

```dart
final snapshot = await session.exportHistory();
final json = snapshot.toJson();
await session.dispose();
final next = await models.restoreSession(
  history: SessionHistory.fromJson(json), tools: currentTools,
);
try {
  final response = await next.respond(Prompt.text('Continue our last topic.'));
} finally {
  await next.dispose();
}
```

No storage or tool replay occurs here. Reuse app-owned user/thread storage and
retention, and handle strict environment/context mismatches without silently
sending history elsewhere. Attachments, data, partial structure and pending tools
are outside the bounded profile. See [complete F07 contract](usage.md#export-and-restore-session-history).

## Add streaming, tools or speech

- [README streaming example](../README.md#sessions-and-streaming): cumulative
  snapshots, completion, failure and `finally` disposal.
- [Guided streaming](usage.md#guided-streaming): only terminal JSON is final.
- [Tool calling](usage.md#tools): validate authorization in the app's tool.
- [Speech transcription](usage.md#speech): separate privacy, permissions and assets.
- [Example source](../example/lib/main.dart): existing Flutter integration.

Do not run multiple requests on one session. Await cancellation and native
cleanup before reuse. Use [troubleshooting](troubleshooting.md) for typed
failure recovery; do not hide failure behind generated success text.

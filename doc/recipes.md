# Flutter local AI recipes for Apple platforms

The same Dart recipes apply to iOS/iPadOS and macOS in version 0.5.0.
See [platform status and Mac host setup](apple-platforms.md).

Here are small tasks you can adapt to your Flutter app: summarize a passage,
extract appointment fields and classify a note. Start with
[installation and availability](local-ai-ios.md). Each recipe uses
`ModelMode.local` and `CloudPolicy.never` to keep generation on the device.
The snippets were reviewed against the source and were not executed.

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

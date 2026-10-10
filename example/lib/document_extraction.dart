import 'package:cupertino_fundations_models/cupertino_fundations_models.dart';

import 'extracted_document.dart';

export 'extracted_document.dart';

/// Bounded extraction schema for the supplied fictional document.
/// Row counts can vary; source identifiers must be positive when present.
final documentSchema = createDocumentSchema();

/// Optional mode with a required date field whose value may be explicit null.
/// This schema needs native explicit-null support on OS 26.4.
final nullableDocumentSchema = createDocumentSchema(explicitNullDates: true);

/// Builds the same bounded document contract with a reusable local row definition.
/// [explicitNullDates] chooses present null rather than omitting an absent date.
StructuredSchema createDocumentSchema({bool explicitNullDates = false}) {
  return StructuredSchema.fromJsonSchema({
    'title': 'DocumentRows', 'type': 'object', 'additionalProperties': false,
    'required': ['currency', 'rows'],
    'properties': {
      'currency': {'type': 'string', 'pattern': r'^(?:[A-Z]{3}|unknown)$'},
      'rows': {'type': 'array', 'maxItems': 50, 'items': {r'$ref': r'#/$defs/DocumentRow'}},
    },
    r'$defs': {
      'DocumentRow': {
        'type': 'object', 'additionalProperties': false,
        'required': ['sourceRow', if (explicitNullDates) 'dateText', 'description', 'amountText'],
        'properties': {
          'sourceRow': {'type': 'integer', 'minimum': 1},
          'dateText': explicitNullDates ? {'anyOf': [{'type': 'string'}, {'type': 'null'}]} : {'type': 'string'},
          'description': {'type': 'string'}, 'amountText': {'type': 'string'},
        },
      },
    },
  }, allowSwiftPatterns: true, propertyOrders: {
    '#': ['currency', 'rows'],
    r'#/$defs/DocumentRow': ['sourceRow', 'dateText', 'description', 'amountText'],
  });
}

/// Synthetic rows used to demonstrate extraction without personal data.
const fictionalDocument = '''
Moneda: EUR
Fila | Fecha | Descripción | Importe
1 | 01/09/2026 | Compra de material | -1.234,56
2 | 02/09/2026 | Abono recibido | +2.000,00
3 | 03/09/2026 | Comisión | -3,50
''';

/// Extracts one final app model while retaining the complete model response.
/// The facade releases its session before the decoder runs; the host reviews
/// source coverage and interprets monetary strings before using them.
Future<DecodedModelResponse<ExtractedDocument>> extractDocumentDecoded({
  required CupertinoFoundationModels models,
  required String document,
  ModelMode mode = ModelMode.local,
  CloudPolicy cloudPolicy = CloudPolicy.never,
  bool explicitNullDates = false,
  GenerationOptions options = const GenerationOptions(
    maximumResponseTokens: 1200,
    timeout: Duration(minutes: 3),
  ),
}) {
  return models.generateStructuredDecoded<ExtractedDocument>(
    prompt: Prompt.text(document),
    schema: explicitNullDates ? nullableDocumentSchema : documentSchema,
    decoder: ExtractedDocument.fromStructuredValue,
    mode: mode,
    cloudPolicy: cloudPolicy,
    instructions: 'Extract only supplied rows. Preserve source row numbers, '
        'descriptions and amount spelling. '
        '${explicitNullDates ? 'Return dateText:null when no date is supplied. ' : 'Include dateText only when supplied. '}'
        'Use a three-letter currency code or unknown. Do not calculate or invent rows.',
    options: options,
  );
}

/// Extracts a final value and explicitly exports its native history before disposal.
/// The caller owns storage, account/thread selection and retention of the returned history.
Future<({DecodedModelResponse<ExtractedDocument> result, SessionHistory history})> extractDocumentWithHistory({
  required CupertinoFoundationModels models,
  required String document,
  bool explicitNullDates = false,
  GenerationOptions options = const GenerationOptions(
    maximumResponseTokens: 1200,
    timeout: Duration(minutes: 3),
  ),
}) async {
  final session = await models.createSession(options: SessionOptions(
    mode: ModelMode.local,
    instructions: 'Extract only supplied rows. Preserve source row numbers, '
        'descriptions and amount spelling. '
        '${explicitNullDates ? 'Return dateText:null when no date is supplied. ' : 'Include dateText only when supplied. '}'
        'Use a three-letter currency code or unknown. Do not calculate or invent rows.',
  ));
  try {
    final result = await session.generateStructuredDecoded<ExtractedDocument>(
      prompt: Prompt.text(document),
      schema: explicitNullDates ? nullableDocumentSchema : documentSchema,
      decoder: ExtractedDocument.fromStructuredValue,
      options: options,
    );
    final history = await session.exportHistory();
    return (result: result, history: history);
  } finally {
    await session.dispose();
  }
}

/// Streams bounded extraction and releases its owned session on every outcome.
/// The caller reviews final data and source coverage before using the result.
Stream<SessionEvent> extractDocument({
  required CupertinoFoundationModels models,
  required String document,
  ModelMode mode = ModelMode.local,
  CloudPolicy cloudPolicy = CloudPolicy.never,
  GenerationDiagnostics? diagnostics,
  bool includeStructuredSnapshots = false,
  bool explicitNullDates = false,
  void Function(TokenBudget budget)? onBudget,
}) async* {
  final session = await models.createSession(
    options: SessionOptions(
      mode: mode,
      cloudPolicy: cloudPolicy,
      instructions: 'Extract only supplied rows. Preserve each source row number, '
          'description and amount spelling. '
          '${explicitNullDates ? 'Return dateText:null when no date is supplied. ' : 'Include dateText only when supplied. '}'
          'Use an explicit three-letter '
          'currency code or unknown when not supplied. Do not calculate or invent rows.',
    ),
  );
  final options = GenerationOptions(
    includeStructuredSnapshots: includeStructuredSnapshots,
    maximumResponseTokens: 1200,
    firstResponseTimeout: const Duration(seconds: 45),
    idleTimeout: const Duration(seconds: 20),
    totalTimeout: const Duration(minutes: 3),
    diagnostics: diagnostics,
  );
  final prompt = Prompt.text(document);
  try {
    onBudget?.call(await session.measureTokenBudget(
      prompt: prompt,
      schema: explicitNullDates ? nullableDocumentSchema : documentSchema,
      options: options,
    ));
    yield* session.streamStructured(
      prompt: prompt,
      schema: explicitNullDates ? nullableDocumentSchema : documentSchema,
      options: options,
    );
  } finally {
    await session.dispose();
  }
}

import 'package:cupertino_fundations_models/cupertino_fundations_models.dart';

const documentSchema = StructuredSchema.object(
  name: 'DocumentRows',
  properties: <String, SchemaProperty>{
    'currency': SchemaProperty.string(),
    'rows': SchemaProperty.array(
      items: SchemaProperty.object(
        properties: <String, SchemaProperty>{
          'sourceRow': SchemaProperty.integer(),
          'dateText': SchemaProperty.string(),
          'description': SchemaProperty.string(),
          'amountText': SchemaProperty.string(),
        },
      ),
    ),
  },
  requiredProperties: <String>['currency', 'rows'],
);

const fictionalDocument = '''
Moneda: EUR
Fila | Fecha | Descripción | Importe
1 | 01/09/2026 | Compra de material | -1.234,56
2 | 02/09/2026 | Abono recibido | +2.000,00
3 | 03/09/2026 | Comisión | -3,50
''';

Stream<SessionEvent> extractDocument({
  required CupertinoFoundationModels models,
  required String document,
  ModelMode mode = ModelMode.local,
  CloudPolicy cloudPolicy = CloudPolicy.never,
  GenerationDiagnostics? diagnostics,
  void Function(TokenBudget budget)? onBudget,
}) async* {
  final session = await models.createSession(
    options: SessionOptions(
      mode: mode,
      cloudPolicy: cloudPolicy,
      instructions: 'Extract only supplied rows. Preserve each source row number, '
          'date, description and amount spelling. Do not calculate or invent rows.',
    ),
  );
  final options = GenerationOptions(
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
      schema: documentSchema,
      options: options,
    ));
    yield* session.streamStructured(
      prompt: prompt,
      schema: documentSchema,
      options: options,
    );
  } finally {
    await session.dispose();
  }
}

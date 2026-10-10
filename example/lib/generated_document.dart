import 'package:cupertino_fundations_models/cupertino_fundations_models_annotations.dart';

import 'generated_document_row.dart';

/// Optional generation route alongside the manual/imported document example.
@StructuredModel(name: 'DocumentRows', propertyOrder: ['currency', 'rows'])
final class GeneratedDocument {
  /// Creates an immutable row collection without changing source values.
  GeneratedDocument({required this.currency, required List<GeneratedDocumentRow> rows})
    : rows = List<GeneratedDocumentRow>.unmodifiable(rows);
  /// Supplied currency code or unknown marker.
  @StructuredField(pattern: r'^(?:[A-Z]{3}|unknown)$')
  final String currency;
  /// At most fifty extracted rows, whose source coverage the app still reviews.
  @StructuredField(maxItems: 50)
  final List<GeneratedDocumentRow> rows;
}

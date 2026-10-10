import 'package:cupertino_fundations_models/cupertino_fundations_models_annotations.dart';

/// Optional annotated alternative retaining source spellings.
@StructuredModel(propertyOrder: ['sourceRow', 'dateText', 'description', 'amountText'])
final class GeneratedDocumentRow {
  /// Creates supplied row data without interpreting amounts or dates.
  const GeneratedDocumentRow({required this.sourceRow, required this.description,
    required this.amountText, this.dateText});
  /// Positive source row identifier.
  @StructuredField(minimum: 1)
  final int sourceRow;
  /// Optional original date spelling.
  final String? dateText;
  /// Original description.
  final String description;
  /// Original signed monetary spelling; arithmetic belongs to the app.
  final String amountText;
}

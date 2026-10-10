import 'package:cupertino_fundations_models/cupertino_fundations_models_annotations.dart';

import 'generated_document_row.dart';

/// A small typed vocabulary for the optional generator example.
enum ReviewStatus { pending, reviewed }

/// Demonstrates native null as a separate choice from ordinary omission.
@StructuredModel(constructor: 'named', explicitNulls: true, description: 'Typed integration choices')
final class GeneratedGenerationChoices {
  /// Uses named construction without turning defaults into generated facts.
  const GeneratedGenerationChoices.named({required this.score, required this.confidence,
    required this.count, required this.accepted, required this.status, required this.rows,
    required this.labels, this.note});
  /// Finite double projection.
  @StructuredField(minimum: 0, maximum: 1)
  final double score;
  /// Original finite numeric representation.
  final num confidence;
  /// Supplied count; no arithmetic is performed.
  final int count;
  /// False remains valid data.
  final bool accepted;
  /// Enum names are matched exactly.
  final ReviewStatus status;
  /// Nullable list elements need native null support.
  final List<GeneratedDocumentRow?> rows;
  /// Nullable strings remain explicit values at their array indices.
  @StructuredField(exactItems: 2)
  final List<String?> labels;
  /// Required presence can hold explicit null.
  @StructuredField(required: true, name: 'note/~')
  final String? note;
}

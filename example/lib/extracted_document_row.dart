/// A supplied document row with original date and amount spelling.
final class ExtractedDocumentRow {
  /// Creates a row without parsing amounts or inventing a missing date.
  const ExtractedDocumentRow({
    required this.sourceRow,
    required this.description,
    required this.amountText,
    this.dateText,
  });

  /// Converts declared row fields; incompatible data produces a FormatException.
  factory ExtractedDocumentRow.fromStructuredValue(Object? value) {
    if (value case <String, Object?>{
      'sourceRow': final int sourceRow,
      'description': final String description,
      'amountText': final String amountText,
    }) {
      final dateText = value['dateText'];
      if (dateText != null && dateText is! String) {
        throw const FormatException('A supplied date must retain its string representation.');
      }
      return ExtractedDocumentRow(sourceRow: sourceRow, description: description,
          amountText: amountText, dateText: dateText as String?);
    }
    throw const FormatException('Expected the declared document row fields.');
  }

  /// Identifier copied from the supplied source.
  final int sourceRow;

  /// Original date text, or null when the optional date is absent.
  final String? dateText;

  /// Description extracted from supplied content.
  final String description;

  /// Original amount spelling; the host owns decimal-safe interpretation.
  final String amountText;
}

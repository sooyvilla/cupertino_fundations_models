import 'extracted_document_row.dart';

export 'extracted_document_row.dart';

/// App-owned final document data, separate from the native response metadata.
final class ExtractedDocument {
  /// Creates document data with an immutable list of rows.
  ExtractedDocument({required this.currency, required List<ExtractedDocumentRow> rows})
      : rows = List<ExtractedDocumentRow>.unmodifiable(rows);

  /// Converts the final guided value without interpreting dates or money.
  factory ExtractedDocument.fromStructuredValue(Object? value) {
    if (value case <String, Object?>{
      'currency': final String currency,
      'rows': final List<Object?> rows,
    }) {
      return ExtractedDocument(currency: currency,
          rows: rows.map(ExtractedDocumentRow.fromStructuredValue).toList());
    }
    throw const FormatException('Expected currency and the supplied document rows.');
  }

  /// Supplied three-letter currency spelling or the schema's unknown marker.
  final String currency;

  /// Converted rows whose source coverage the application must still review.
  final List<ExtractedDocumentRow> rows;
}

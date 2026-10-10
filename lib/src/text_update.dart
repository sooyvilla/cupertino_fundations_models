/// How an update changes a consumer's current text buffer.
enum TextUpdateKind {
  /// Adds a suffix to an unchanged previous snapshot.
  append,
  /// Replaces text after a revision, shortening or unsafe UTF-16 boundary.
  replace,
}

/// Lossless text change with an authoritative complete text value.
final class TextUpdate {
  /// Creates an append operation tied to its exact previous buffer.
  const TextUpdate.append({required this.content, required String baseText})
    : kind = TextUpdateKind.append, _baseText = baseText;
  /// Creates a replacement operation independent of the previous buffer.
  const TextUpdate.replace({required this.content})
    : kind = TextUpdateKind.replace, _baseText = null;

  /// Whether to append or replace; replacements are never disguised as deltas.
  final TextUpdateKind kind;
  /// Suffix for append, or complete replacement text for replace.
  final String content;
  final String? _baseText;
  /// Authoritative full text after this update, including empty values.
  String get fullText => kind == TextUpdateKind.append ? _baseText! + content : content;

  /// Applies a change, rejecting append against a stale consumer buffer.
  String applyTo(String previous) {
    if (kind == TextUpdateKind.append && previous != _baseText) {
      throw StateError('The text buffer does not match the append update baseline.');
    }
    return fullText;
  }
}

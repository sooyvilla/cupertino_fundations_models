/// A language advertised by an on-device text model, independently of Speech.
final class TextModelLanguage {
  /// Creates localized labels without implying model readiness or Speech assets.
  const TextModelLanguage({required this.identifier, required this.languageCode,
    required this.displayName, required this.nativeDisplayName});

  /// Reads native language labels, preserving the identifier as the fallback.
  factory TextModelLanguage.fromMap(Map<Object?, Object?> map) {
    final identifier = (map['identifier'] as String?) ?? 'und';
    return TextModelLanguage(identifier: identifier,
      languageCode: (map['languageCode'] as String?) ?? identifier,
      displayName: (map['displayName'] as String?) ?? identifier,
      nativeDisplayName: (map['nativeDisplayName'] as String?) ?? (map['displayName'] as String?) ?? identifier);
  }

  /// Minimal native language identifier; not every accepted regional locale.
  final String identifier;
  /// Primary native language code.
  final String languageCode;
  /// Name localized for the host's current locale.
  final String displayName;
  /// Name localized in the represented language.
  final String nativeDisplayName;

  /// Serializes labels without querying the host or requesting assets.
  Map<String, Object?> toMap() => {'identifier': identifier, 'languageCode': languageCode,
    'displayName': displayName, 'nativeDisplayName': nativeDisplayName};
}

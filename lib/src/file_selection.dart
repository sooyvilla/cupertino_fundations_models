import 'generation.dart';

/// File category requested from the native Apple file picker.
enum FoundationModelsFileKind {
  /// Allows any file category supported by the native picker.
  any,
  /// Requests the native image filter.
  image,
  /// Requests the native audio filter.
  audio,
  /// Requests supported text documents, including text PDFs.
  text,
}

/// File selected through the native Apple file picker.
final class PickedFoundationModelsFile {
  /// Creates a selected-file descriptor.
  const PickedFoundationModelsFile({
    required this.path,
    required this.name,
    required this.mimeType,
    required this.kind,
  });

  /// Creates a selected-file descriptor from a platform-channel payload.
  factory PickedFoundationModelsFile.fromMap(Map<Object?, Object?> map) {
    return PickedFoundationModelsFile(
      path: (map['path'] as String?) ?? '',
      name: (map['name'] as String?) ?? '',
      mimeType: map['mimeType'] as String?,
      kind: _kindFromName((map['kind'] as String?) ?? 'any'),
    );
  }

  /// Absolute path to the temporary file available to the native plugin.
  final String path;

  /// Display name reported by the document picker.
  final String name;

  /// MIME type reported for the file, when available.
  final String? mimeType;

  /// Picker filter requested by the app; this is not an inferred content type.
  final FoundationModelsFileKind kind;

  /// Converts this file into a prompt attachment.
  PromptAttachment toPromptAttachment({String? label}) {
    return PromptAttachment.file(
      path: path,
      label: label ?? name,
      mimeType: mimeType,
    );
  }
}

FoundationModelsFileKind _kindFromName(String name) {
  for (final FoundationModelsFileKind value
      in FoundationModelsFileKind.values) {
    if (value.name == name) {
      return value;
    }
  }
  return FoundationModelsFileKind.any;
}

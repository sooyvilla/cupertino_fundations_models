import 'generation.dart';

enum FoundationModelsFileKind { any, image, audio, text }

final class PickedFoundationModelsFile {
  const PickedFoundationModelsFile({
    required this.path,
    required this.name,
    required this.mimeType,
    required this.kind,
  });

  factory PickedFoundationModelsFile.fromMap(Map<Object?, Object?> map) {
    return PickedFoundationModelsFile(
      path: (map['path'] as String?) ?? '',
      name: (map['name'] as String?) ?? '',
      mimeType: map['mimeType'] as String?,
      kind: _kindFromName((map['kind'] as String?) ?? 'any'),
    );
  }

  final String path;
  final String name;
  final String? mimeType;
  final FoundationModelsFileKind kind;

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

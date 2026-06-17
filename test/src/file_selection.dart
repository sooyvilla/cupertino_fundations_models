import 'package:cupertino_fundations_models/cupertino_fundations_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('file selection', () {
    test('picked files parse and convert to prompt attachments', () {
      final file = PickedFoundationModelsFile.fromMap(<Object?, Object?>{
        'path': '/tmp/file.txt',
        'name': 'file.txt',
        'mimeType': 'text/plain',
        'kind': FoundationModelsFileKind.text.name,
      });

      expect(file.kind, FoundationModelsFileKind.text);
      expect(file.toPromptAttachment().toMap()['label'], 'file.txt');
      expect(
        file.toPromptAttachment(label: 'custom').toMap()['label'],
        'custom',
      );
      expect(
        PickedFoundationModelsFile.fromMap(<Object?, Object?>{
          'kind': 'future',
        }).kind,
        FoundationModelsFileKind.any,
      );
    });
  });
}

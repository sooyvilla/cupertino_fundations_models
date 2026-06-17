import 'package:cupertino_fundations_models/cupertino_fundations_models.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_helpers.dart';

void main() {
  group('tools', () {
    test('definitions and results serialize', () {
      final tool = TestTool(
        name: 'search',
        description: 'Search',
        parameters: const <String, Object?>{'type': 'object'},
        timeout: const Duration(seconds: 1),
        callback: (Map<String, Object?> arguments) => arguments['q'],
      );

      expect(
        ToolDefinition.fromTool(tool).toMap()['timeoutMilliseconds'],
        1000,
      );
      expect(
        const ToolResult.success(<String>['ok']).toMap()['isError'],
        isFalse,
      );
      expect(const ToolResult.failure('bad').toMap()['message'], 'bad');
    });
  });
}

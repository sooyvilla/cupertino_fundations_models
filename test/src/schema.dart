import 'package:cupertino_fundations_models/cupertino_fundations_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('schema', () {
    test('structured schemas and properties serialize', () {
      const schema = StructuredSchema.object(
        name: 'Answer',
        description: 'desc',
        requiredProperties: <String>['title'],
        properties: <String, SchemaProperty>{
          'title': SchemaProperty.string(
            description: 'title',
            enumValues: <String>['a'],
          ),
          'count': SchemaProperty.integer(),
          'score': SchemaProperty.number(),
          'ok': SchemaProperty.boolean(),
          'tags': SchemaProperty.array(items: SchemaProperty.string()),
          'nested': SchemaProperty.object(
            properties: <String, SchemaProperty>{
              'value': SchemaProperty.string(),
            },
          ),
        },
      );

      expect(schema.toMap()['type'], 'object');
      expect(const SchemaProperty(type: 'custom').toMap()['type'], 'custom');
    });
  });
}

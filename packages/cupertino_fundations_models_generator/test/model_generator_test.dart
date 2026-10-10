import 'dart:io';

import 'package:build/build.dart';
import 'package:build_test/build_test.dart';
import 'package:cupertino_fundations_models_generator/builder.dart';
import 'package:test/test.dart';

const annotations = "import 'package:cupertino_fundations_models/cupertino_fundations_models_annotations.dart';";
const package = 'cupertino_fundations_models_generator';

Future<TestBuilderResult> buildModel(String declaration, {Map<String, String> extras = const {}, String path = 'lib/sample.dart'}) =>
  testBuilder(structuredModelsBuilder(BuilderOptions.empty), {
    '$package|$path': '$annotations\n$declaration',
    for (final file in ['cupertino_fundations_models_annotations.dart', 'src/structured_model.dart', 'src/structured_field.dart', 'src/availability.dart'])
      'cupertino_fundations_models|lib/$file': File('../../lib/$file').readAsStringSync(),
    ...extras,
  }, rootPackage: package, flattenOutput: true);

Future<String> generate(String declaration, {Map<String, String> extras = const {}}) async {
  final result = await buildModel(declaration, extras: extras);
  if (!result.succeeded) throw StateError(result.errors.join('\n'));
  return result.readerWriter.readAsString(AssetId(package, 'lib/sample.structured.dart'));
}

void main() {
  test('standalone object companion emits existing schema and final decoder calls', () async {
    final result = await generate(r'''
@StructuredModel(name: 'Contact', propertyOrder: ['name', 'email'])
class Contact {
  const Contact({required this.name, this.email});
  @StructuredField(description: 'Supplied name', pattern: r'^.+$')
  final String name;
  final String? email;
}
''');
    expect(result, contains('final class ContactCodec'));
    expect(result, contains('final class ContactPartial'));
    expect(result, contains('_cfm.StructuredSchema.object'));
    expect(result, contains('requiredProperties: ["name"]'));
    expect(result, contains('allowNull: false'));
    expect(result, isNot(contains('part of')));
  });

  test('generation is reproducible across identical inputs', () async {
    const source = '@StructuredModel() class Item { const Item({required this.value}); final bool value; }';
    expect(await generate(source), await generate(source));
  });

  test('nullable choices enums nested lists aliases and imports preserve the declared contract', () async {
    final output = await generate(r'''
import 'nested/child.dart' as nested;
import 'package:cupertino_fundations_models/src/availability.dart' as local;
@StructuredModel(constructor: 'named', description: 'Guide', explicitNulls: true)
class Choice {
  Choice.named({required this.rows, required this.score, required this.name, required this.status, this.note});
  @StructuredField(description: 'Rows', minItems: 1, maxItems: 4)
  final List<List<nested.Child?>> rows;
  @StructuredField(minimum: -2.5, maximum: 10)
  final double score;
  @StructuredField(name: 'note/~', required: true)
  final String? note;
  @StructuredField(pattern: r'^a$')
  final Text name;
  final local.ModelMode status;
}
typedef Text = String;
''', extras: {
      '$package|lib/nested/child.dart': '$annotations\n@StructuredModel() class Child { const Child({required this.value}); final num value; }',
    });
    expect(output, contains('nested/child.structured.dart'));
    expect(output, contains('package:cupertino_fundations_models/src/availability.dart'));
    expect(output, contains('SchemaProperty.anyOf'));
    expect(output, contains('SchemaProperty.nullValue'));
    expect(output, contains('Choice.named'));
    expect(output, contains('StructuredPartialField<String>'));
    expect(output, contains('partialList'));
  });

  test('nested model guidance and relative paths work through imported source prefixes', () async {
    final result = await buildModel('''
import '../models/child.dart' as c;
@StructuredModel()
class Parent {
 const Parent({required this.child});
 @StructuredField(description: 'Supplied child') final c.Child child;
}
''', path: 'lib/features/sample.dart', extras: {'$package|lib/models/child.dart': '''
$annotations
@StructuredModel(name: 'ChildShape', description: 'Child', propertyOrder: ['value'])
class Child { const Child({required this.value}); final int value; }
'''});
    expect(result.succeeded, true, reason: result.errors.join('\n'));
    final output = await result.readerWriter.readAsString(AssetId(package, 'lib/features/sample.structured.dart'));
    expect(output, contains('description: "Supplied child"'));
    expect(output, contains('../models/child.structured.dart'));
    expect(output, contains('ChildPartial'));
  });

  final rejected = <String, String>{
    'enum annotation': '@StructuredModel() enum Bad { one }',
    'two models': '@StructuredModel() class A { const A({required this.x}); final int x; } @StructuredModel() class B { const B({required this.x}); final int x; }',
    'private class': '@StructuredModel() class _Bad { const _Bad({required this.x}); final int x; }',
    'abstract': '@StructuredModel() abstract class Bad { Bad({required this.x}); final int x; }',
    'generic': '@StructuredModel() class Bad<T> { Bad({required this.x}); final T x; }',
    'inherited': 'class Base {} @StructuredModel() class Bad extends Base { Bad({required this.x}); final int x; }',
    'mixin': 'mixin M {} @StructuredModel() class Bad with M { Bad({required this.x}); final int x; }',
    'positional': '@StructuredModel() class Bad { Bad(this.x); final int x; }',
    'factory': '@StructuredModel(constructor: "create") class Bad { Bad({required this.x}); factory Bad.create({required int x}) => Bad(x:x); final int x; }',
    'missing constructor': '@StructuredModel(constructor: "absent") class Bad { Bad({required this.x}); final int x; }',
    'no fields': '@StructuredModel() class Bad { Bad(); }',
    'mutable field': '@StructuredModel() class Bad { Bad({required this.x}); int x; }',
    'private field': '@StructuredModel() class Bad { Bad({required int x}) : _x=x; final int _x; }',
    'late': '@StructuredModel() class Bad { Bad({required int x}) {this.x=x;} late final int x; }',
    'reserved': '@StructuredModel() class Bad { Bad({required this.snapshot}); final String snapshot; }',
    'unmatched parameter': '@StructuredModel() class Bad { Bad({required int y}) : x=y; final int x; }',
    'mismatched parameter type': '@StructuredModel() class Bad { Bad({required num x}) : x=x.toInt(); final int x; }',
    'empty name': '@StructuredModel(name: "") class Bad { Bad({required this.x}); final int x; }',
    'empty wire': '@StructuredModel() class Bad { Bad({required this.x}); @StructuredField(name: "") final int x; }',
    'duplicate wire': '@StructuredModel() class Bad { Bad({required this.x,required this.y}); @StructuredField(name: "same") final int x; @StructuredField(name: "same") final int y; }',
    'bad order': '@StructuredModel(propertyOrder: ["unknown"]) class Bad { Bad({required this.x}); final int x; }',
    'optional non-nullable': '@StructuredModel() class Bad { Bad({required this.x}); @StructuredField(required: false) final int x; }',
    'numeric string': '@StructuredModel() class Bad { Bad({required this.x}); @StructuredField(minimum: 0) final String x; }',
    'non-finite': '@StructuredModel() class Bad { Bad({required this.x}); @StructuredField(minimum: double.nan) final double x; }',
    'fractional integer': '@StructuredModel() class Bad { Bad({required this.x}); @StructuredField(maximum: 1.5) final int x; }',
    'integer too large': '@StructuredModel() class Bad { Bad({required this.x}); @StructuredField(maximum: 9223372036854775808.0) final int x; }',
    'precision loss': '@StructuredModel() class Bad { Bad({required this.x}); @StructuredField(minimum: 9007199254740993) final num x; }',
    'inverted bounds': '@StructuredModel() class Bad { Bad({required this.x}); @StructuredField(minimum: 2, maximum: 1) final int x; }',
    'pattern on number': '@StructuredModel() class Bad { Bad({required this.x}); @StructuredField(pattern: "x") final int x; }',
    'counts on string': '@StructuredModel() class Bad { Bad({required this.x}); @StructuredField(minItems: 1) final String x; }',
    'range and exact': '@StructuredModel() class Bad { Bad({required this.x}); @StructuredField(exactItems: 1, maxItems: 2) final List<int> x; }',
    'negative counts': '@StructuredModel() class Bad { Bad({required this.x}); @StructuredField(minItems: -1) final List<int> x; }',
    'inverted counts': '@StructuredModel() class Bad { Bad({required this.x}); @StructuredField(minItems: 2, maxItems: 1) final List<int> x; }',
    'dynamic': '@StructuredModel() class Bad { Bad({required this.x}); final dynamic x; }',
    'function': '@StructuredModel() class Bad { Bad({required this.x}); final void Function() x; }',
    'record': '@StructuredModel() class Bad { Bad({required this.x}); final (int,int) x; }',
    'map': '@StructuredModel() class Bad { Bad({required this.x}); final Map<String,String> x; }',
    'date': '@StructuredModel() class Bad { Bad({required this.x}); final DateTime x; }',
    'unannotated child': 'class Child { Child({required this.x}); final int x; } @StructuredModel() class Bad { Bad({required this.x}); final Child x; }',
    'recursive': '@StructuredModel() class Bad { Bad({this.x}); final Bad? x; }',
    'extension type': 'extension type Money(int amount) {} @StructuredModel() class Bad { Bad({required this.x}); final Money x; }',
    'private enum': 'enum _E {x} @StructuredModel() class Bad { Bad({required this.x}); final _E x; }',
    'static guide': '@StructuredModel() class Bad { Bad({required this.x}); final int x; @StructuredField(minimum: 1) static final int other=1; }',
    'getter guide': '@StructuredModel() class Bad { Bad({required this.x}); final int x; @StructuredField() int get computed => x; }',
    'parameter guide': '@StructuredModel() class Bad { Bad({@StructuredField() required this.x}); final int x; }',
  };
  for (final entry in rejected.entries) {
    test('rejects ${entry.key} with a source diagnostic instead of coercion', () async {
      final result = await buildModel(entry.value);
      expect(result.succeeded, false);
      expect(result.outputs, isEmpty);
      expect(result.errors.join('\n'), contains('sample.dart'));
    });
  }

  test('empty required choices and complete integer boundaries remain supported', () async {
    final output = await generate('''
@StructuredModel()
class Limits {
  const Limits({this.note, required this.count});
  @StructuredField(required: false) final String? note;
  @StructuredField(minimum: -9223372036854775808, maximum: 9223372036854775807) final int count;
}
''');
    expect(output, contains('minimum: -9223372036854775808'));
    expect(output, contains('maximum: 9223372036854775807'));
  });
  test('models outside lib fail rather than emitting nonportable imports', () async {
    final result = await buildModel('@StructuredModel() class Item { const Item({required this.x}); final int x; }', path:'test/sample.dart');
    expect(result.succeeded,false); expect(result.errors.join('\n'),contains('under lib/'));
  });
  test('field count and schema depth boundaries are enforced', () async {
    final fields = List.generate(129,(i) => 'final bool f$i;').join();
    final params = List.generate(129,(i) => 'required this.f$i').join(',');
    expect((await buildModel('@StructuredModel() class Large { const Large({$params}); $fields }')).succeeded,false);
    for (final count in [15,16]) {
      final type = '${'List<' * count}String${'>' * count}';
      final result = await buildModel('@StructuredModel() class Depth { const Depth({required this.x}); final $type x; }');
      expect(result.succeeded,count == 15,reason:result.errors.join('\n'));
    }
    final type = '${'List<' * 15}String?${'>' * 15}';
    expect((await buildModel('@StructuredModel() class Depth { const Depth({required this.x}); final $type x; }')).succeeded,false);
  });
  test('expanded nullable graphs keep the runtime 512-node bound', () async {
    final fields = List.generate(128,(i) => 'final bool f$i;').join();
    final params = List.generate(128,(i) => 'required this.f$i').join(',');
    final child = '$annotations @StructuredModel() class Child { const Child({$params}); $fields }';
    final result = await buildModel("import 'child.dart'; @StructuredModel(explicitNulls:true) class Root { Root({required this.a,required this.b,required this.c,required this.d,this.note}); final Child a; final Child b; final Child c; final Child d; final String? note; }", extras:{'$package|lib/child.dart':child});
    expect(result.succeeded,false); expect(result.errors.join('\n'),contains('512'));
  });

}

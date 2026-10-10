import 'package:cupertino_fundations_models/cupertino_fundations_models.dart';
import 'package:flutter_test/flutter_test.dart';

// ignore: avoid_relative_lib_imports
import '../example/lib/generated_document.structured.dart';
// ignore: avoid_relative_lib_imports
import '../example/lib/generated_document_row.structured.dart';
// ignore: avoid_relative_lib_imports
import '../example/lib/generated_generation_choices.dart';
// ignore: avoid_relative_lib_imports
import '../example/lib/generated_generation_choices.structured.dart';

StructuredSnapshot snapshot(Object? value, {bool complete = false, bool hasValue = true,
  List<String> present = const ['#'], List<String> completed = const []}) => StructuredSnapshot.fromMap({
    'hasValue': hasValue, 'value': value, 'isComplete': complete,
    'presentPaths': present, 'completePaths': completed,
  });

Map<String,Object?> choices({Object? note, List<Object?> rows = const []}) => {
  'score': 0, 'confidence': 0.5, 'count': 0, 'accepted': false, 'status': 'pending',
  'rows': rows, 'labels': ['supplied', null], 'note/~': note,
};

void main() {
  test('annotation options remain ordinary dependency-free Dart values', () {
    final names = <String, String>{'model': 'Row', 'field': 'x'};
    final annotation = StructuredModel(name: names['model'], description: 'Source', propertyOrder: ['x'], explicitNulls: true, constructor: 'named');
    expect(annotation.name, 'Row'); expect(annotation.description, 'Source');
    expect(annotation.propertyOrder, ['x']); expect(annotation.explicitNulls, true); expect(annotation.constructor, 'named');
    final field = StructuredField(name: names['field'], description: 'Guide', required: true, minimum: 0,
      maximum: 1, pattern: '^x', minItems: 0, maxItems: 1, exactItems: 1);
    expect(field.name, 'x'); expect(field.description, 'Guide'); expect(field.required, true);
    expect(field.minimum, 0); expect(field.maximum, 1); expect(field.pattern, '^x');
    expect(field.minItems, 0); expect(field.maxItems, 1); expect(field.exactItems, 1);
  });

  test('generated schema equals the same manual and imported inline contracts', () {
    const row = SchemaProperty.object(properties: {'sourceRow': SchemaProperty.integer(minimum: 1),
      'dateText': SchemaProperty.string(), 'description': SchemaProperty.string(), 'amountText': SchemaProperty.string()},
      requiredProperties: ['sourceRow', 'description', 'amountText'],
      propertyOrder: ['sourceRow', 'dateText', 'description', 'amountText']);
    const manual = StructuredSchema.object(name: 'DocumentRows', properties: {
      'currency': SchemaProperty.string(pattern: r'^(?:[A-Z]{3}|unknown)$'),
      'rows': SchemaProperty.array(items: row, maxItems: 50),
    }, requiredProperties: ['currency', 'rows'], propertyOrder: ['currency', 'rows']);
    expect(GeneratedDocumentCodec.schema.toMap(), manual.toMap());
    final imported = StructuredSchema.fromJsonSchema({'type': 'object', 'additionalProperties': false,
      'title': 'DocumentRows', 'required': ['currency', 'rows'], 'properties': {
        'currency': {'type': 'string', 'pattern': r'^(?:[A-Z]{3}|unknown)$'},
        'rows': {'type': 'array', 'maxItems': 50, 'items': {'type': 'object', 'additionalProperties': false,
          'required': ['sourceRow','description','amountText'], 'properties': {
            'sourceRow': {'type': 'integer','minimum': 1}, 'dateText': {'type':'string'},
            'description': {'type':'string'}, 'amountText': {'type':'string'},
          }}},
      }}, allowSwiftPatterns: true, propertyOrders: {'#': ['currency','rows'],
        '#/properties/rows/items': ['sourceRow','dateText','description','amountText']});
    expect(GeneratedDocumentCodec.schema.toMap(), imported.toMap());
  });

  test('compiled generated decoder retains monetary spelling and full response metadata', () {
    const response = ModelResponse(text: 'original', usedMode: ModelMode.local, metadata: {'id':'native'},
      structuredValue: {'currency':'EUR', 'rows': [
        {'sourceRow':1, 'description':'Source', 'amountText':'-1.234,56'},
        {'sourceRow':2, 'description':'Received', 'amountText':'+2.000,00', 'dateText':'02/09/2026'},
      ]});
    final result = response.decodeStructured(decoder: GeneratedDocumentCodec.decode);
    expect(result.response, same(response)); expect(result.value.rows.first.amountText, '-1.234,56');
    expect(result.value.rows.first.dateText, isNull); expect(result.value.rows.last.dateText, '02/09/2026');
    expect(result.value.rows.clear, throwsUnsupportedError);
    expect(GeneratedDocumentCodec.decode({'currency':'unknown','rows':<Object?>[]}).rows, isEmpty);
  });

  test('named constructor enums nullable lists and required explicit null compile and decode', () {
    final result = GeneratedGenerationChoicesCodec.decode(choices(rows: [null, {'sourceRow':1,'description':'x','amountText':'0'}]));
    expect(result.score, 0.0); expect(result.confidence, 0.5); expect(result.count, 0); expect(result.accepted, false);
    expect(result.status, ReviewStatus.pending); expect(result.note, isNull); expect(result.rows.first, isNull);
    expect(result.labels, ['supplied', null]); expect(result.labels.clear, throwsUnsupportedError);
    expect(GeneratedGenerationChoicesCodec.schema.properties['note/~']!.type, 'anyOf');
    expect(GeneratedGenerationChoicesCodec.schema.requiredProperties, contains('note/~'));
    expect(GeneratedGenerationChoicesCodec.decode(choices(note: 'Review')).note, 'Review');
  });

  for (final value in <Object?>[
    null, [], {'currency':'EUR'}, {'currency':'EUR','rows':<Object?>[],'unexpected':true},
    {'currency':7,'rows':<Object?>[]}, {'currency':'EUR','rows':[{'sourceRow':1,'description':'x','amountText':'0','dateText':null}]},
    {...choices(), 'status':'unknown'}, {...choices(), 'accepted':0}, {...choices(), 'count':0.5},
    {...choices(), 'score':double.nan}, {...choices(), 'score':9223372036854775807},
    choices()..remove('note/~'),
  ]) {
    test('generated final conversion rejects structural incompatibility: $value', () {
      final decoder = value is Map && value.containsKey('score') ? GeneratedGenerationChoicesCodec.decode : GeneratedDocumentCodec.decode;
      expect(() => decoder(value), throwsFormatException);
    });
  }

  test('decoder failures keep F04 original response and omit source data in error messages', () {
    const response = ModelResponse(text: 'sensitive', usedMode: ModelMode.local, metadata: {},
      structuredValue: {'currency':'EUR','rows':[{'sourceRow':'secret','description':'x','amountText':'0'}]});
    try { response.decodeStructured(decoder: GeneratedDocumentCodec.decode); fail('Expected failure'); }
    on StructuredDecodingException catch (error) {
      expect(error.response, same(response)); expect(error.cause, isA<FormatException>());
      expect(error.cause.toString(), contains('#/rows/0/sourceRow'));
      expect(error.cause.toString(), isNot(contains('secret')));
    }
  });

  test('typed partial views preserve incomplete containers and never construct final rows', () {
    final partial = GeneratedDocumentPartial.fromSnapshot(snapshot({'currency':'EUR','rows':[
      {'sourceRow':1,'description':'known'},
    ]}, present: ['#','#/currency','#/rows','#/rows/0','#/rows/0/sourceRow','#/rows/0/description','#/rows/0/amountText'],
      completed: ['#/currency','#/rows/0/sourceRow','#/rows/0/description']));
    expect(partial.isComplete, false); expect(partial.currency.value, 'EUR');
    expect(partial.rows.isComplete, false); expect(partial.rows.hasValue, true);
    final row = partial.rows.value!.single;
    expect(row.sourceRow.value, 1); expect(row.description.value, 'known');
    expect(row.amountText.isPresent, true); expect(row.amountText.hasValue, false);
    expect(row.dateText.isPresent, false); expect(partial.snapshot.hasValue, true);
    expect(partial.rows.value!.clear, throwsUnsupportedError);
  });

  test('partial absence explicit null false and zero retain independent flags', () {
    final value = choices(rows: [null]);
    final paths = ['#', for (final key in value.keys) StructuredValueReader.childPath('#',key), '#/rows/0','#/labels/0','#/labels/1'];
    final native = snapshot(value, complete:true,present:paths,completed:paths);
    final partial = GeneratedGenerationChoicesPartial.fromSnapshot(native);
    expect(partial.snapshot, same(native)); expect(partial.isComplete,true);
    expect(partial.accepted.value,false); expect(partial.count.value,0); expect(partial.score.value,0.0);
    expect(partial.confidence.value,0.5); expect(partial.status.value,ReviewStatus.pending);
    expect(partial.note.path,'#/note~1~0'); expect(partial.note.isPresent,true);
    expect(partial.note.isComplete,true); expect(partial.note.hasValue,true); expect(partial.note.value,isNull);
    expect(partial.rows.value,[null]); expect(partial.labels.value,['supplied',null]);
    final absent = GeneratedDocumentRowPartial.fromSnapshot(snapshot(null,hasValue:false));
    expect(absent.sourceRow.hasValue,false);
  });

  test('partial arrays withhold incomplete primitive suffixes and malformed typed projections fail', () {
    final partial = GeneratedGenerationChoicesPartial.fromSnapshot(snapshot({'labels':['known','withheld']},
      present:['#','#/labels','#/labels/0','#/labels/1'],completed:['#/labels/0']));
    expect(partial.labels.value,['known']);
    final invalid = GeneratedDocumentRowPartial.fromSnapshot(snapshot({'sourceRow':'secret'},
      present:['#','#/sourceRow'],completed:['#/sourceRow']));
    expect(() => invalid.sourceRow,throwsFormatException);
    expect(() => GeneratedDocumentPartial.fromSnapshot(snapshot(false,complete:true,completed:['#'])),throwsFormatException);
  });

  test('shared reader types and paths fail without coercion or value disclosure', () {
    expect(StructuredValueReader.string('', '#'), ''); expect(StructuredValueReader.number(0,'#'),0);
    expect(StructuredValueReader.number(0.5,'#'),0.5); expect(StructuredValueReader.doubleValue(0.5,'#'),0.5);
    expect(StructuredValueReader.integer(-9223372036854775808,'#'),-9223372036854775808);
    expect(StructuredValueReader.boolean(false,'#'),false);
    expect(() => StructuredValueReader.object({7:'private'},'#',{}),throwsFormatException);
    expect(() => StructuredValueReader.list(7,'#',StructuredValueReader.string),throwsFormatException);
    expect(() => StructuredValueReader.number('secret','#'),throwsFormatException);
    expect(() => StructuredValueReader.enumValue('absent','#',ReviewStatus.values),throwsFormatException);
    expect(StructuredValueReader.field({},'x','#',StructuredValueReader.string,required:false,allowNull:false),isNull);
    expect(() => StructuredValueReader.field({'x':null},'x','#',StructuredValueReader.string,required:false,allowNull:false),throwsFormatException);
    final view = snapshot({'array':[<String, Object?>{}]});
    for (final path in ['wrong','#/~x']) { expect(() => StructuredValueReader.partialObject(view,path,{}),throwsFormatException); }
    for (final path in ['#/missing','#/array/-1','#/array/01','#/array/1','#/array/x','#/array/0/missing']) {
      expect(StructuredValueReader.partialObject(view,path,{}),isEmpty);
    }
    expect(StructuredValueReader.partialObject(snapshot({}),'#',{}),isEmpty);
    expect(() => StructuredValueReader.partialList(view,7,'#',StructuredValueReader.string),throwsFormatException);
  });
}

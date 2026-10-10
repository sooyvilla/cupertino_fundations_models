import 'dart:convert';

import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/nullability_suffix.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:cupertino_fundations_models/cupertino_fundations_models_annotations.dart';
import 'package:source_gen/source_gen.dart';

/// Emits one validated standalone companion with deterministic import allocation.
final class ModelEmitter {
  /// Receives the annotated root and resolved annotation metadata.
  ModelEmitter(this.root, this.annotation);
  final ClassElement root;
  final ConstantReader annotation;
  final Map<String, String> _imports = {};
  final Map<ClassElement, List<FieldElement>> _fields = {};
  int _nodes = 0;
  bool _advancedGraph = false;
  static const _modelChecker = TypeChecker.typeNamed(StructuredModel, inPackage: 'cupertino_fundations_models');
  static const _fieldChecker = TypeChecker.typeNamed(StructuredField, inPackage: 'cupertino_fundations_models');

  /// Produces runtime API calls, never inference or a generated native bridge.
  String emit() {
    final fields = _modelFields(root);
    final schema = _object(root, <ClassElement>[], 0, rootSchema: true);
    if (_advancedGraph && _nodes > 512) _fail(root, 'Nullable schema graphs support at most 512 expanded nodes.');
    final type = _named(root);
    final arguments = fields.map((field) {
      final required = _required(field);
      final expression = _decodeBase(field.type, 'value', 'path', partial: false);
      final read = '_cfm.StructuredValueReader.field(_object, ${_quote(_wire(field))}, path, (value, path) => $expression, required: $required, allowNull: ${_nullable(field.type) && _model(root).read('explicitNulls').boolValue})';
      return '${field.name}: $read${_nullable(field.type) ? '' : '!'}';
    }).join(',\n');
    final constructor = _model(root).read('constructor').stringValue;
    final target = constructor.isEmpty ? type : '$type.$constructor';
    final getters = fields.map((field) {
      final expression = _nullable(field.type) && !_model(root).read('explicitNulls').boolValue
          ? _decodeBase(field.type, 'value', 'path', partial: true)
          : _decode(field.type, 'value', 'path', partial: true);
      return '_cfm.StructuredPartialField<${_dartType(field.type, partial: true)}> get ${field.name} =>\n'
        '    _cfm.StructuredValueReader.partialField(_snapshot, _cfm.StructuredValueReader.childPath(_path, ${_quote(_wire(field))}), (value, path) => $expression, container: ${_container(field.type)});';
    }).join('\n');
    final body = '''
/// Generated guidance and final conversion for ${root.name}.
final class ${root.name}Codec {
  /// Equivalent runtime schema; native availability and guide validation still apply.
  static const schema = $schema;
  /// Converts final data structurally without validating business truth or guides.
  static $type decode(Object? value, {String path = '#'}) {
    final _object = _cfm.StructuredValueReader.object(value, path, ${_fieldSet(fields)});
    return $target($arguments);
  }
}

/// A typed nonterminal view retaining native presence and completeness.
final class ${root.name}Partial {
  /// Views the original snapshot at an object path without final-model construction.
  ${root.name}Partial.fromSnapshot(this._snapshot, {String path = '#'}) : _path = path {
    _cfm.StructuredValueReader.partialObject(_snapshot, _path, ${_fieldSet(fields)});
  }
  final _cfm.StructuredSnapshot _snapshot;
  final String _path;
  /// Original replaceable snapshot; a complete root is still nonterminal.
  _cfm.StructuredSnapshot get snapshot => _snapshot;
  /// Native completeness at this object's path.
  bool get isComplete => _snapshot.completePaths.contains(_path);
  $getters
}
''';
    final imports = _imports.entries.map((entry) => 'import ${_quote(entry.key)} as ${entry.value};').join('\n');
    return "// ignore_for_file: no_leading_underscores_for_library_prefixes, prefer_single_quotes, use_raw_strings, no_leading_underscores_for_local_identifiers, unnecessary_lambdas, avoid_redundant_argument_values, directives_ordering\nimport 'package:cupertino_fundations_models/cupertino_fundations_models.dart' as _cfm;\n$imports\n$body".trim();
  }

  ConstantReader _model(ClassElement model, {Element? owner}) {
    if (model == root) return annotation;
    final metadata = _modelChecker.firstAnnotationOf(model);
    if (metadata == null) _fail(owner ?? model, 'Nested model types require StructuredModel.');
    return ConstantReader(metadata);
  }

  ConstantReader? _field(FieldElement field) {
    final metadata = _fieldChecker.firstAnnotationOf(field);
    return metadata == null ? null : ConstantReader(metadata);
  }

  Object? _option(FieldElement field, String name) => _field(field)?.read(name).literalValue;
  String _wire(FieldElement field) => (_option(field, 'name') as String?) ?? field.name!;
  bool _required(FieldElement field) => (_option(field, 'required') as bool?) ?? !_nullable(field.type);

  List<FieldElement> _modelFields(ClassElement model) {
    if (_fields.containsKey(model)) return _fields[model]!;
    if (model.isPrivate || model.isAbstract || model.typeParameters.isNotEmpty ||
        model.supertype?.element.name != 'Object' || model.mixins.isNotEmpty) {
      _fail(model, 'Use a concrete public non-generic class without inherited fields or mixins.');
    }
    final reader = _model(model);
    final constructorName = reader.read('constructor').stringValue;
    final constructor = model.constructors.where((item) => item.name == constructorName || (constructorName.isEmpty && item.name == 'new')).firstOrNull;
    if (constructor == null || constructor.isFactory || constructor.isPrivate || constructor.formalParameters.any((p) => !p.isNamed)) {
      _fail(model, 'Select a public generative constructor with named field parameters.');
    }
    for (final member in [...model.fields.where((f) => f.isStatic), ...model.getters.where((g) => g.isOriginDeclaration), ...constructor.formalParameters]) {
      if (_fieldChecker.hasAnnotationOf(member)) _fail(member, 'Place StructuredField on a declared instance field.');
    }
    final fields = model.fields.where((field) => !field.isStatic && field.isOriginDeclaration).toList();
    if (fields.isEmpty || fields.length > 128 || fields.any((field) => field.isPrivate || !field.isFinal || field.isLate || field.isAbstract || field.isExternal || const {'snapshot', 'isComplete'}.contains(field.name))) {
      _fail(model, 'Use 1–128 public final fields, excluding reserved partial-view names snapshot/isComplete.');
    }
    final names = fields.map((field) => field.name).toSet();
    if (constructor.formalParameters.length != names.length || constructor.formalParameters.any((p) => !names.contains(p.name) || p.type != fields.firstWhere((f) => f.name == p.name).type)) {
      _fail(model, 'Every field must have one named constructor parameter of the same type.');
    }
    final wireNames = fields.map(_wire).toList();
    if (wireNames.any((name) => name.isEmpty) || wireNames.toSet().length != wireNames.length) _fail(model, 'JSON field names must be distinct and non-empty.');
    for (final field in fields) {
      if (!_nullable(field.type) && !_required(field)) _fail(field, 'Optional fields must have nullable Dart types.');
      _validateGuides(field);
    }
    final order = reader.read('propertyOrder');
    if (!order.isNull) {
      final values = order.listValue.map((value) => value.toStringValue()).toList();
      if (values.length != wireNames.length || values.toSet().length != values.length || !values.toSet().containsAll(wireNames)) _fail(model, 'propertyOrder must be a full permutation of JSON field names.');
    }
    final name = reader.read('name');
    if (!name.isNull && name.stringValue.isEmpty) _fail(model, 'Schema names cannot be empty.');
    fields.sort((a, b) => _wire(a).compareTo(_wire(b)));
    return _fields[model] = fields;
  }

  void _validateGuides(FieldElement field) {
    final type = field.type;
    final numeric = type.isDartCoreInt || type.isDartCoreDouble || type.isDartCoreNum;
    final minimum = _option(field, 'minimum') as num?;
    final maximum = _option(field, 'maximum') as num?;
    for (final bound in [minimum, maximum]) {
      if (bound == null) continue;
      if (!numeric || !bound.isFinite) _fail(field, 'Numeric guides require finite numeric fields.');
      if (type.isDartCoreInt && bound is double && (bound != bound.truncateToDouble() || bound < -9223372036854775808.0 || bound >= 9223372036854775808.0)) _fail(field, 'Integer guides require whole signed 64-bit bounds.');
      if (!type.isDartCoreInt && bound is int && BigInt.from(bound.toDouble()) != BigInt.from(bound)) _fail(field, 'Number guides must retain their value in native Double.');
    }
    if (minimum != null && maximum != null && minimum > maximum) _fail(field, 'minimum cannot exceed maximum.');
    if (_option(field, 'pattern') != null && !type.isDartCoreString) _fail(field, 'Swift patterns require String fields.');
    final min = _option(field, 'minItems') as int?;
    final max = _option(field, 'maxItems') as int?;
    final exact = _option(field, 'exactItems') as int?;
    if ([min, max, exact].any((value) => value != null) && !type.isDartCoreList) _fail(field, 'Item counts require List fields.');
    if (exact != null && (min != null || max != null)) _fail(field, 'Choose an exact count or a range.');
    if ([min, max, exact].any((value) => value != null && value < 0) || (min != null && max != null && min > max)) _fail(field, 'Array counts must be non-negative and ordered.');
  }

  String _object(ClassElement model, List<ClassElement> ancestors, int depth, {bool rootSchema = false, String? fieldDescription}) {
    if (ancestors.contains(model) || depth > 16) _fail(model, 'Model graphs must be acyclic and fit schema depth 16.');
    if (rootSchema) _nodes++;
    final fields = _modelFields(model);
    final options = _model(model);
    final properties = fields.map((field) => '${_quote(_wire(field))}: ${_schema(field.type, [...ancestors, model], depth + 1, field: field, explicitNull: options.read('explicitNulls').boolValue)}').join(',\n');
    final order = options.read('propertyOrder');
    final requiredNames = fields.where(_required).map(_wire).toSet();
    final orderedNames = order.isNull ? fields.map(_wire) : order.listValue.map((value) => value.toStringValue()!);
    final required = orderedNames.where(requiredNames.contains).map(_quote).join(',');
    final orderText = order.isNull ? '' : 'propertyOrder: [${order.listValue.map((v) => _quote(v.toStringValue()!)).join(',')}],';
    final description = options.read('description');
    final desc = fieldDescription != null ? 'description: ${_quote(fieldDescription)},' : description.isNull ? '' : 'description: ${_quote(description.stringValue)},';
    return '${rootSchema ? '_cfm.StructuredSchema' : '_cfm.SchemaProperty'}.object(${rootSchema ? 'name: ${_quote(options.read('name').isNull ? model.name! : options.read('name').stringValue)},' : ''}\nproperties: {$properties}, requiredProperties: [$required], $orderText $desc)';
  }

  String _schema(DartType type, List<ClassElement> ancestors, int depth, {FieldElement? field, bool explicitNull = true}) {
    if (depth > 16) _fail(field ?? root, 'Generated schemas must fit depth 16.');
    _nodes++;
    if (_nullable(type) && explicitNull) {
      if (depth >= 16) _fail(field ?? root, 'Nullable schemas must fit depth 16.');
      _advancedGraph = true;
      _nodes += 2;
      return '_cfm.SchemaProperty.anyOf(alternatives: [${_schemaBase(type, ancestors, depth + 1, field)}, _cfm.SchemaProperty.nullValue()])';
    }
    return _schemaBase(type, ancestors, depth, field);
  }

  String _schemaBase(DartType type, List<ClassElement> ancestors, int depth, FieldElement? field) {
    final description = field == null ? null : _option(field, 'description');
    final args = <String>[if (description != null) 'description: ${_quote(description as String)}'];
    if (field != null) {
      for (final key in ['minimum', 'maximum', 'pattern', 'minItems', 'maxItems', 'exactItems']) {
        final value = _option(field, key);
        if (value != null) args.add('$key: ${value is String ? _quote(value) : type.isDartCoreInt ? (value as num).toInt() : value}');
      }
    }
    final kind = type.isDartCoreString ? 'string' : type.isDartCoreInt ? 'integer' :
        (type.isDartCoreDouble || type.isDartCoreNum) ? 'number' : type.isDartCoreBool ? 'boolean' : null;
    if (kind != null) return '_cfm.SchemaProperty.$kind(${args.join(',')})';
    if (type is! InterfaceType) _fail(field ?? root, 'Unsupported field type ${type.getDisplayString()}.');
    if (type.isDartCoreList) {
      args.add('items: ${_schema(type.typeArguments.single, ancestors, depth + 1)}');
      return '_cfm.SchemaProperty.array(${args.join(',')})';
    }
    if (type.element is EnumElement) {
      if (type.element.isPrivate || !type.element.fields.any((field) => field.isEnumConstant)) _fail(field ?? root, 'Enum fields require public enums with declared values.');
      final values = type.element.fields.where((field) => field.isEnumConstant).map((field) => _quote(field.name!)).join(',');
      return '_cfm.SchemaProperty.string(enumValues: [$values], ${args.join(',')})';
    }
    if (type.element is ClassElement) {
      _model(type.element as ClassElement, owner: field ?? root);
      return _object(type.element as ClassElement, ancestors, depth, fieldDescription: description as String?);
    }
    _fail(field ?? root, 'Unsupported model field type.');
  }

  String _decode(DartType type, String value, String path, {required bool partial}) {
    if (_nullable(type)) return '_cfm.StructuredValueReader.nullable($value, $path, (value, path) => ${_decodeBase(type, 'value', 'path', partial: partial)})';
    return _decodeBase(type, value, path, partial: partial);
  }

  String _decodeBase(DartType type, String value, String path, {required bool partial}) {
    final kind = type.isDartCoreString ? 'string' : type.isDartCoreInt ? 'integer' : type.isDartCoreDouble ? 'doubleValue' : type.isDartCoreNum ? 'number' : type.isDartCoreBool ? 'boolean' : null;
    if (kind != null) return '_cfm.StructuredValueReader.$kind($value, $path)';
    final interface = type as InterfaceType;
    if (interface.isDartCoreList) {
      final child = interface.typeArguments.single;
      final decoder = _decode(child, 'item', 'itemPath', partial: partial);
      return partial ? '_cfm.StructuredValueReader.partialList(_snapshot, $value, $path, (item, itemPath) => $decoder, containers: ${_container(child)})' :
        '_cfm.StructuredValueReader.list($value, $path, (item, itemPath) => $decoder)';
    }
    if (interface.element is EnumElement) return '_cfm.StructuredValueReader.enumValue($value, $path, ${_named(interface.element)}.values)';
    final prefix = _import(interface.element.library.uri.toString().replaceFirst(RegExp(r'\.dart$'), '.structured.dart'));
    return partial ? '$prefix.${interface.element.name}Partial.fromSnapshot(_snapshot, path: $path)' : '$prefix.${interface.element.name}Codec.decode($value, path: $path)';
  }

  String _dartType(DartType type, {required bool partial}) {
    final suffix = _nullable(type) ? '?' : '';
    if (type.isDartCoreList) return 'List<${_dartType((type as InterfaceType).typeArguments.single, partial: partial)}>$suffix';
    if (type is InterfaceType && !type.element.library.isDartCore) {
      if (partial && type.element is ClassElement) return '${_import(type.element.library.uri.toString().replaceFirst(RegExp(r'\.dart$'), '.structured.dart'))}.${type.element.name}Partial$suffix';
      return '${_named(type.element)}$suffix';
    }
    final name = type.isDartCoreString ? 'String' : type.isDartCoreInt ? 'int' : type.isDartCoreDouble ? 'double' : type.isDartCoreNum ? 'num' : 'bool';
    return '$name$suffix';
  }

  bool _container(DartType type) => type.isDartCoreList || (type is InterfaceType && type.element is ClassElement && !type.element.library.isDartCore);
  bool _nullable(DartType type) => type.nullabilitySuffix == NullabilitySuffix.question;
  String _named(InterfaceElement type) => '${_import(type.library.uri.toString())}.${type.name}';
  String _import(String uri) {
    var importUri = uri;
    final source = root.library.uri;
    final target = Uri.parse(uri);
    if (source.scheme == 'package' && target.scheme == 'package' && source.pathSegments.first == target.pathSegments.first) {
      final directory = source.pathSegments.sublist(1, source.pathSegments.length - 1);
      final destination = target.pathSegments.sublist(1);
      var shared = 0;
      while (shared < directory.length && shared < destination.length && directory[shared] == destination[shared]) { shared++; }
      importUri = Uri(pathSegments: [...List.filled(directory.length - shared, '..'), ...destination.skip(shared)]).toString();
    }
    return _imports.putIfAbsent(importUri, () => '_i${_imports.length}');
  }
  String _fieldSet(List<FieldElement> fields) => '{${fields.map((f) => _quote(_wire(f))).join(',')}}';
  String _quote(String value) => jsonEncode(value).replaceAll(r'$', r'\$');
  Never _fail(Element element, String message) => throw InvalidGenerationSourceError(message, element: element);
}

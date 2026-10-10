import 'errors.dart';
import 'schema.dart';

/// Internal conversion of the documented JSON Schema subset to native contracts.
/// Unknown definitions fail with their input path; no network or codegen runs.
final class JsonSchemaImporter {
  /// Creates a parser with an explicit native-pattern policy.
  const JsonSchemaImporter({required this.allowSwiftPatterns, this.propertyOrders = const {}});

  /// Whether imported patterns may use native Swift rather than ECMA-262 syntax.
  final bool allowSwiftPatterns;

  /// Optional full orders keyed by input object-schema JSON Pointer.
  final Map<String, List<String>> propertyOrders;

  static const _dialect = 'https://json-schema.org/draft/2020-12/schema';
  static const _common = <String>{'type', 'title', 'description'};
  static const _types = <String>{
    'object', 'array', 'string', 'integer', 'number', 'boolean', 'null',
  };

  /// Parses one root and snapshots its descendants into existing schema classes.
  StructuredSchema parse(Map<String, Object?> schema, {String? name}) {
    final usedOrders = <String>{};
    final definitions = <String, SchemaProperty>{};
    if (schema.containsKey(r'$defs')) {
      final raw = _map(schema[r'$defs'], r'#/$defs');
      if (raw.length > 32) _fail(r'#/$defs', 'Use at most 32 local definitions.');
      for (final entry in raw.entries) {
        final path = '#/\$defs/${_pointer(entry.key)}';
        if (entry.key.trim().isEmpty) _fail(path, 'Definition names must be non-empty.');
        definitions[entry.key] = _property(entry.value, path, 0, usedOrders);
      }
    }
    final root = _property(schema, '#', 0, usedOrders);
    for (final path in propertyOrders.keys) {
      if (!usedOrders.contains(path)) _fail(path, 'An order must target a declared object schema.');
    }
    final title = schema['title'] as String?;
    final rootName = name ?? (title != null && title.trim().isNotEmpty ? title : 'Output');
    if (rootName.trim().isEmpty) {
      _fail('#', 'The output name must be non-empty.');
    }
    final registry = Map<String, SchemaProperty>.unmodifiable(definitions);
    final result = switch (root.type) {
      'object' => StructuredSchema.object(
        name: rootName, description: root.description,
        properties: root.properties!, requiredProperties: root.requiredProperties!, propertyOrder: root.propertyOrder, definitions: registry,
      ),
      'array' => StructuredSchema.array(
        name: rootName, description: root.description, items: root.items!,
        minItems: root.minItems, maxItems: root.maxItems, definitions: registry,
      ),
      'string' => StructuredSchema.string(
        name: rootName, description: root.description,
        enumValues: root.enumValues, pattern: root.pattern, definitions: registry,
      ),
      'integer' => StructuredSchema.integer(
        name: rootName, description: root.description,
        minimum: root.minimum?.toInt(), maximum: root.maximum?.toInt(), definitions: registry,
      ),
      'number' => StructuredSchema.number(
        name: rootName, description: root.description,
        minimum: root.minimum, maximum: root.maximum, definitions: registry,
      ),
      'null' => StructuredSchema.nullValue(name: rootName, description: root.description, definitions: registry),
      'anyOf' => StructuredSchema.anyOf(name: rootName, description: root.description, alternatives: root.alternatives!, definitions: registry),
      'reference' => StructuredSchema.reference(name: rootName, description: root.description, reference: root.referenceName!, definitions: registry),
      _ => StructuredSchema.boolean(name: rootName, description: root.description, definitions: registry),
    };
    try {
      result.toMap();
    // ignore: avoid_catching_errors
    } on ArgumentError catch (error) {
      var path = error.name ?? '#';
      if (path.startsWith('#/definitions/')) path = r'#/$defs/' + path.substring(14);
      if (error.message == 'Reference a declared non-empty local definition.') {
        path = path.substring(0, path.length - 10) + r'/$ref';
      }
      _fail(path.startsWith('#') ? path : '#', 'The local schema graph is unresolved, recursive or exceeds its bounds.');
    }
    return result;
  }

  SchemaProperty _property(Object? raw, String path, int depth, Set<String> usedOrders) {
    if (depth > 16) _fail(path, 'Schemas support at most 16 nesting levels.');
    final node = _map(raw, path);
    final form = node.containsKey(r'$ref') ? 'reference' : node.containsKey('anyOf') ? 'anyOf' : node['type'];
    if (form is! String || (!const {'reference', 'anyOf'}.contains(form) && !_types.contains(form))) {
      _fail('$path/type', 'Declare one supported type, anyOf or a local reference.');
    }
    final type = form;
    if (propertyOrders.containsKey(path) && type != 'object') {
      _fail(path, 'Only object schemas accept property orders.');
    }
    final specific = switch (type) {
      'object' => <String>{'properties', 'required', 'additionalProperties'},
      'array' => <String>{'items', 'minItems', 'maxItems'},
      'string' => <String>{'enum', 'pattern'},
      'integer' || 'number' => <String>{'minimum', 'maximum'},
      'anyOf' => <String>{'anyOf'},
      'reference' => <String>{r'$ref'},
      _ => <String>{},
    };
    final common = <String>{..._common};
    if (type == 'anyOf' || type == 'reference') common.remove('type');
    final allowed = <String>{...common, ...specific, if (path == '#') r'$schema', if (path == '#') r'$defs'};
    for (final key in node.keys) {
      if (!allowed.contains(key)) {
        _fail('$path/${_pointer(key)}', 'This keyword is not supported for the declared type.');
      }
    }
    if (node.containsKey(r'$schema') && node[r'$schema'] != _dialect) {
      _fail('$path/\$schema', 'Only the declared 2020-12 subset is supported.');
    }
    _string(node, 'title', path);
    final description = _string(node, 'description', path);

    switch (type) {
      case 'null':
        return SchemaProperty.nullValue(description: description);
      case 'anyOf':
        final choices = node['anyOf'];
        if (choices is! List || choices.isEmpty || choices.length > 8) {
          _fail('$path/anyOf', 'Use one to eight schema alternatives.');
        }
        return SchemaProperty.anyOf(description: description, alternatives: List<SchemaProperty>.unmodifiable([
          for (var index = 0; index < choices.length; index++) _property(choices[index], '$path/anyOf/$index', depth + 1, usedOrders),
        ]));
      case 'reference':
        final reference = node[r'$ref'];
        if (reference is! String || !reference.startsWith(r'#/$defs/')) {
          _fail('$path/\$ref', 'Only local references to root definitions are supported.');
        }
        final token = reference.substring(8);
        if (token.isEmpty || token.contains('/') || token.replaceAll('~0', '').replaceAll('~1', '').contains('~') || token.contains('%')) {
          _fail('$path/\$ref', 'Reference one escaped root-definition name without anchors or URI encoding.');
        }
        return SchemaProperty.reference(token.replaceAll('~1', '/').replaceAll('~0', '~'), description: description);
      case 'object':
        if (!node.containsKey('additionalProperties') || node['additionalProperties'] != false) {
          _fail('$path/additionalProperties', 'Every imported object must explicitly be closed with false.');
        }
        final rawProperties = node.containsKey('properties')
            ? _map(node['properties'], '$path/properties') : <String, Object?>{};
        if (rawProperties.length > 128) {
          _fail('$path/properties', 'Objects support at most 128 declared properties.');
        }
        final properties = <String, SchemaProperty>{};
        for (final entry in rawProperties.entries) {
          final childPath = '$path/properties/${_pointer(entry.key)}';
          if (entry.key.trim().isEmpty) _fail(childPath, 'Property names must be non-empty.');
          properties[entry.key] = _property(entry.value, childPath, depth + 1, usedOrders);
        }
        final required = _strings(node, 'required', path) ?? <String>[];
        for (var index = 0; index < required.length; index++) {
          if (!properties.containsKey(required[index])) {
            _fail('$path/required/$index', 'Required fields must be declared in properties.');
          }
        }
        final order = propertyOrders[path];
        if (order != null) {
          usedOrders.add(path);
          if (order.toSet().length != order.length || order.length != properties.length ||
              !properties.keys.toSet().containsAll(order)) {
            _fail(path, 'An order must contain every object property exactly once.');
          }
        }
        return SchemaProperty.object(
          description: description,
          properties: Map<String, SchemaProperty>.unmodifiable(properties),
          requiredProperties: List<String>.unmodifiable(required),
          propertyOrder: order == null ? null : List<String>.unmodifiable(order),
        );
      case 'array':
        final item = _property(node['items'], '$path/items', depth + 1, usedOrders);
        final minimum = _integer(node, 'minItems', path);
        final maximum = _integer(node, 'maxItems', path);
        if (minimum != null && minimum < 0) _fail('$path/minItems', 'Item counts must be non-negative.');
        if (maximum != null && maximum < 0) _fail('$path/maxItems', 'Item counts must be non-negative.');
        if (minimum != null && maximum != null && minimum > maximum) {
          _fail('$path/minItems', 'Minimum item count must not exceed maximum.');
        }
        return SchemaProperty.array(items: item, description: description, minItems: minimum, maxItems: maximum);
      case 'string':
        final values = _strings(node, 'enum', path);
        if (values != null && values.isEmpty) _fail('$path/enum', 'String enums must not be empty.');
        final pattern = _string(node, 'pattern', path);
        if (pattern != null && !allowSwiftPatterns) {
          _fail('$path/pattern', 'Enable allowSwiftPatterns explicitly to use native Swift regex syntax.');
        }
        return SchemaProperty.string(
          description: description,
          enumValues: values == null ? null : List<String>.unmodifiable(values),
          pattern: pattern,
        );
      case 'integer':
        final minimum = _integer(node, 'minimum', path);
        final maximum = _integer(node, 'maximum', path);
        if (minimum != null && maximum != null && minimum > maximum) {
          _fail('$path/minimum', 'Minimum must not exceed maximum.');
        }
        return SchemaProperty.integer(description: description, minimum: minimum, maximum: maximum);
      case 'number':
        final minimum = _number(node, 'minimum', path, doubleGuide: true);
        final maximum = _number(node, 'maximum', path, doubleGuide: true);
        if (minimum != null && maximum != null && minimum > maximum) {
          _fail('$path/minimum', 'Minimum must not exceed maximum.');
        }
        return SchemaProperty.number(description: description, minimum: minimum, maximum: maximum);
      default:
        return SchemaProperty.boolean(description: description);
    }
  }

  Map<String, Object?> _map(Object? value, String path) {
    if (value is! Map) _fail(path, 'A schema or property collection must be an object.');
    final result = <String, Object?>{};
    for (final entry in value.entries) {
      final key = entry.key;
      if (key is! String) _fail(path, 'Schema keys must be strings.');
      result[key] = entry.value;
    }
    return result;
  }

  String? _string(Map<String, Object?> node, String key, String path) {
    if (!node.containsKey(key)) return null;
    final value = node[key];
    if (value is! String) _fail('$path/$key', 'This annotation or pattern must be a string.');
    return value;
  }

  List<String>? _strings(Map<String, Object?> node, String key, String path) {
    if (!node.containsKey(key)) return null;
    final raw = node[key];
    if (raw is! List) _fail('$path/$key', 'This keyword must be a list of strings.');
    final result = <String>[];
    final seen = <String>{};
    for (var index = 0; index < raw.length; index++) {
      final value = raw[index];
      if (value is! String || !seen.add(value)) {
        _fail('$path/$key/$index', 'Entries must be distinct strings.');
      }
      result.add(value);
    }
    return result;
  }

  num? _number(Map<String, Object?> node, String key, String path, {bool doubleGuide = false}) {
    if (!node.containsKey(key)) return null;
    final value = node[key];
    if (value is! num || !value.isFinite) _fail('$path/$key', 'Numeric limits must be finite numbers.');
    if (doubleGuide && value is int && BigInt.from(value.toDouble()) != BigInt.from(value)) {
      _fail('$path/$key', 'Number limits must retain their value in native Double guides.');
    }
    return value;
  }

  int? _integer(Map<String, Object?> node, String key, String path) {
    final value = _number(node, key, path);
    if (value == null) return null;
    if (value is int) return value;
    if (value != value.truncateToDouble() || value < -9223372036854775808.0 || value >= 9223372036854775808.0) {
      _fail('$path/$key', 'The profile requires a whole signed 64-bit integer limit.');
    }
    return value.toInt();
  }

  String _pointer(String value) => value.replaceAll('~', '~0').replaceAll('/', '~1');

  Never _fail(String path, String message) {
    throw FoundationModelsException(
      code: FoundationModelsErrorCode.invalidRequest,
      message: message,
      recoverySuggestion: 'Use the documented JSON Schema generation subset.',
      details: <String, Object?>{'schemaPath': path, 'schemaSource': 'jsonSchema'},
    );
  }
}

import 'schema_graph.dart';
import 'schema_property_order.dart';

/// A field type and its optional native guided-generation constraints.
///
/// Numeric bounds are inclusive. Array bounds control element counts. String
/// patterns use Swift regular-expression syntax, which can differ from Dart's
/// [RegExp]. These constraints shape generation rather than validate arbitrary
/// application data. They require the same native availability as guided output.
final class SchemaProperty {
  /// Creates a property using the bridge's supported type names.
  ///
  /// Prefer the named constructors when the type is known. Bounds are valid
  /// only for numbers, [pattern] for strings, and item counts for arrays.
  /// Validation runs in [toMap] so invalid const values also fail in release.
  const SchemaProperty({
    required this.type,
    this.description,
    this.enumValues,
    this.items,
    this.properties,
    this.requiredProperties,
    this.propertyOrder,
    this.minimum,
    this.maximum,
    this.pattern,
    this.minItems,
    this.maxItems,
    this.exactItems,
    this.alternatives,
    this.referenceName,
  });

  /// Describes a string, optionally constrained to an enum or Swift regex.
  ///
  /// [pattern] is checked natively before generation. Add anchors when the
  /// entire value must match, for example `r'^SUP-[0-9]{4}$'`. When both a
  /// pattern and [enumValues] are supplied, both restrictions must hold.
  const SchemaProperty.string({
    this.description,
    this.enumValues,
    this.pattern,
  }) : type = 'string',
       items = null,
       properties = null,
       requiredProperties = null,
       propertyOrder = null,
       minimum = null,
       maximum = null,
       minItems = null,
       maxItems = null,
       exactItems = null,
       alternatives = null,
       referenceName = null;

  /// Describes an integer with optional inclusive [minimum] and [maximum].
  const SchemaProperty.integer({
    this.description,
    int? this.minimum,
    int? this.maximum,
  }) : type = 'integer',
       enumValues = null,
       items = null,
       properties = null,
       requiredProperties = null,
       propertyOrder = null,
       pattern = null,
       minItems = null,
       maxItems = null,
       exactItems = null,
       alternatives = null,
       referenceName = null;

  /// Describes a number with optional finite, inclusive numeric bounds.
  /// Integer bounds must be exactly representable by native Double guides.
  const SchemaProperty.number({
    this.description,
    this.minimum,
    this.maximum,
  }) : type = 'number',
       enumValues = null,
       items = null,
       properties = null,
       requiredProperties = null,
       propertyOrder = null,
       pattern = null,
       minItems = null,
       maxItems = null,
       exactItems = null,
       alternatives = null,
       referenceName = null;

  /// Describes a boolean value.
  const SchemaProperty.boolean({this.description})
    : type = 'boolean',
      enumValues = null,
      items = null,
      properties = null,
      requiredProperties = null,
      propertyOrder = null,
      minimum = null,
      maximum = null,
      pattern = null,
      minItems = null,
      maxItems = null,
      exactItems = null,
      alternatives = null,
      referenceName = null;

  /// Describes an array whose elements follow [items].
  ///
  /// Use [minItems]/[maxItems] for a range or [exactItems] for one length.
  /// Counts must be non-negative; zero permits an empty array. Do not combine
  /// an exact count with either range bound.
  const SchemaProperty.array({
    required this.items,
    this.description,
    this.minItems,
    this.maxItems,
    this.exactItems,
  }) : type = 'array',
       enumValues = null,
       properties = null,
       requiredProperties = null,
       propertyOrder = null,
       minimum = null,
       maximum = null,
       pattern = null,
       alternatives = null,
       referenceName = null;

  /// Describes an object with independently configurable required child fields.
  ///
  /// Omitting [requiredProperties] preserves the legacy all-required behavior.
  /// An empty list makes every child optional; a list of names requires only
  /// those children. Optional absence is not an explicit null schema.
  /// [propertyOrder] optionally sets a full permutation of these child fields.
  const SchemaProperty.object({
    required this.properties,
    this.description,
    this.requiredProperties,
    this.propertyOrder,
  })
    : type = 'object',
      enumValues = null,
      items = null,
      minimum = null,
      maximum = null,
      pattern = null,
      minItems = null,
      maxItems = null,
      exactItems = null,
      alternatives = null,
      referenceName = null;

  /// Describes an explicit null value, requiring native OS 26.4 and a compatible SDK.
  const SchemaProperty.nullValue({String? description})
      : this(type: 'null', description: description);

  /// Describes an anyOf union; overlap is allowed and no oneOf exclusivity is inferred.
  const SchemaProperty.anyOf({required List<SchemaProperty> alternatives, String? description})
      : this(type: 'anyOf', alternatives: alternatives, description: description);

  /// References a name from the StructuredSchema root's local definitions.
  const SchemaProperty.reference(String name, {String? description})
      : this(type: 'reference', referenceName: name, description: description);

  /// Native schema type, including null, anyOf and reference forms.

  final String type;

  /// Short semantic guidance for this property.
  final String? description;

  /// Allowed string values; native mapping rejects an empty or duplicate enum.
  final List<String>? enumValues;

  /// Element schema required when [type] is array.
  final SchemaProperty? items;

  /// Nested fields declared when [type] is object.
  final Map<String, SchemaProperty>? properties;

  /// Required object children; null preserves all-required native behavior.
  /// Empty means none are required, and each supplied name must be declared.
  final List<String>? requiredProperties;

  /// Full generation order of declared object fields, or null for alphabetical.
  /// Every property must appear exactly once; this does not change requiredness.
  final List<String>? propertyOrder;

  /// Inclusive lower bound for an integer or number; null leaves it unbounded.
  final num? minimum;

  /// Inclusive upper bound for an integer or number; null leaves it unbounded.
  final num? maximum;

  /// Swift regular-expression pattern for string generation.
  final String? pattern;

  /// Inclusive minimum array length, or null for the native default.
  final int? minItems;

  /// Inclusive maximum array length, or null for the native default.
  final int? maxItems;

  /// Exact array length, serialized as equal minimum and maximum counts.
  final int? exactItems;

  /// One to eight branches for anyOf; at least one branch may match.
  final List<SchemaProperty>? alternatives;

  /// Local definition name for a reference; definitions belong to the root schema.
  final String? referenceName;

  /// Serializes this property and its children for the native schema mapper.
  ///
  /// Throws [ArgumentError] for non-finite or inverted bounds, fractional
  /// integer limits, negative counts, invalid required-field lists or constraints
  /// on an incompatible type.
  /// Swift regex parsing and native schema support are checked by the bridge.
  /// With [definitions], local references are resolved and the registry is
  /// serialized at the root. Without it, standalone reference names remain
  /// unbound; complete StructuredSchema serialization always supplies a registry.
  /// Extended graphs reject cycles and allow at most 512 expanded nodes.
  Map<String, Object?> toMap({Map<String, SchemaProperty>? definitions}) {
    final graph = SchemaGraph(definitions);
    final result = _encode(graph, '#', 0);
    if (definitions != null && definitions.isNotEmpty) {
      result['definitions'] = {
        for (final entry in definitions.entries)
          entry.key: entry.value._encode(graph, '#/definitions/${SchemaGraph.pointer(entry.key)}', 0),
      };
    }
    return result;
  }

  Map<String, Object?> _encode(SchemaGraph graph, String path, int depth) {
    graph.enter(this, path, depth);
    try {
    _validateConstraints();
    if (type.toLowerCase() == 'reference') {
      final target = graph.target(referenceName, path);
      target?._encode(graph, '#/definitions/${SchemaGraph.pointer(referenceName!)}', depth + 1);
    }
    return <String, Object?>{
      'type': type,
      'description': description,
      'enumValues': enumValues,
      'items': items?._encode(graph, '$path/items', depth + 1),
      'properties': properties?.map(
        (String key, SchemaProperty value) =>
            MapEntry<String, Object?>(key, value._encode(graph, '$path/properties/${SchemaGraph.pointer(key)}', depth + 1)),
      ),
      if (requiredProperties != null) 'requiredProperties': requiredProperties,
      if (propertyOrder != null) 'propertyOrder': propertyOrder,
      if (alternatives != null) 'anyOf': [
        for (var index = 0; index < alternatives!.length; index++)
          alternatives![index]._encode(graph, '$path/anyOf/$index', depth + 1),
      ],
      if (referenceName != null) 'reference': referenceName,
      if (minimum != null) 'minimum': minimum,
      if (maximum != null) 'maximum': maximum,
      if (pattern != null) 'pattern': pattern,
      if (exactItems != null || minItems != null)
        'minItems': exactItems ?? minItems,
      if (exactItems != null || maxItems != null)
        'maxItems': exactItems ?? maxItems,
    };
    } finally {
      graph.leave(this);
    }
  }

  void _validateConstraints() {
    SchemaPropertyOrder.validate(type, properties, propertyOrder);
    final normalizedType = type.toLowerCase();
    if (const {'anyof', 'reference', 'null'}.contains(normalizedType) &&
        (items != null || properties != null || enumValues != null)) {
      throw ArgumentError('Extended forms accept only their own schema options.');
    }
    if ((alternatives != null && (normalizedType != 'anyof' || alternatives!.isEmpty || alternatives!.length > 8)) ||
        (normalizedType == 'anyof' && alternatives == null) ||
        (referenceName != null && normalizedType != 'reference') ||
        (normalizedType == 'reference' && referenceName == null)) {
      throw ArgumentError('Use one to eight anyOf alternatives or a local reference on its matching type.');
    }
    final required = requiredProperties;
    if (required != null) {
      if (normalizedType != 'object') {
        throw ArgumentError.value(type, 'type', 'Required fields need an object.');
      }
      final names = <String>{};
      for (final name in required) {
        if (!names.add(name)) {
          throw ArgumentError.value(
            required,
            'requiredProperties',
            'Required field names must be distinct.',
          );
        }
        if (!(properties?.containsKey(name) ?? false)) {
          throw ArgumentError.value(
            name,
            'requiredProperties',
            'Required fields must exist in properties.',
          );
        }
      }
    }
    if ((minimum != null || maximum != null) &&
        normalizedType != 'integer' &&
        normalizedType != 'number') {
      throw ArgumentError.value(type, 'type', 'Numeric bounds require a number.');
    }
    for (final bound in <String, num?>{
      'minimum': minimum,
      'maximum': maximum,
    }.entries) {
      final value = bound.value;
      if (value != null && !value.isFinite) {
        throw ArgumentError.value(value, bound.key, 'Must be finite.');
      }
      if (normalizedType == 'number' && value is int &&
          BigInt.from(value.toDouble()) != BigInt.from(value)) {
        throw ArgumentError.value(value, bound.key, 'Must retain its value in native Double guides.');
      }
      if (value != null &&
          normalizedType == 'integer' &&
          value != value.truncate()) {
        throw ArgumentError.value(value, bound.key, 'Must be a whole integer.');
      }
    }
    if (minimum != null && maximum != null && minimum! > maximum!) {
      throw ArgumentError.value(minimum, 'minimum', 'Must not exceed maximum.');
    }
    if (pattern != null && normalizedType != 'string') {
      throw ArgumentError.value(type, 'type', 'Patterns require a string.');
    }
    if ((minItems != null || maxItems != null || exactItems != null) &&
        normalizedType != 'array') {
      throw ArgumentError.value(type, 'type', 'Item counts require an array.');
    }
    if (exactItems != null && (minItems != null || maxItems != null)) {
      throw ArgumentError.value(
        exactItems,
        'exactItems',
        'Use an exact count or a range.',
      );
    }
    for (final count in <String, int?>{
      'minItems': minItems,
      'maxItems': maxItems,
      'exactItems': exactItems,
    }.entries) {
      if (count.value != null && count.value! < 0) {
        throw ArgumentError.value(count.value, count.key, 'Must not be negative.');
      }
    }
    if (minItems != null && maxItems != null && minItems! > maxItems!) {
      throw ArgumentError.value(minItems, 'minItems', 'Must not exceed maxItems.');
    }
  }
}


import 'json_schema_importer.dart';
import 'schema_property.dart';
import 'schema_property_order.dart';

export 'schema_property.dart';

/// Describes the root value the native model should produce through guided output.
///
/// Choose an object, array, scalar, explicit null, anyOf or local-reference root. For an
/// object, define [properties] and list required fields in [requiredProperties];
/// its default empty list keeps every root field optional. Array elements can
/// contain objects with their own required-field lists. The app still validates
/// facts and business rules after generation.
///
/// ```dart
/// const schema = StructuredSchema.object(
///   name: 'Feedback',
///   properties: {
///     'rating': SchemaProperty.integer(minimum: 1, maximum: 5),
///     'actions': SchemaProperty.array(
///       items: SchemaProperty.string(),
///       exactItems: 3,
///     ),
///   },
///   requiredProperties: ['rating', 'actions'],
/// );
/// ```
final class StructuredSchema {
  /// Imports the package's explicit JSON Schema 2020-12 generation subset.
  ///
  /// Supported schemas declare a single [type], anyOf or a local root-$defs
  /// reference, and use closed objects with
  /// `additionalProperties: false`, typed array items and the documented F01
  /// constraints. Omitted JSON `required` means no required fields at every
  /// level. This differs from the legacy manual nested-object default.
  /// Integer limits must fit signed 64-bit values; number limits must retain
  /// their decoded value in native Double guides. Nesting allows 16 edges and
  /// each object may declare up to 128 properties.
  /// Extended graphs allow 32 definitions, eight anyOf branches and 512 expanded
  /// nodes; cycles, remote references and assertion siblings on $ref are rejected.
  /// [propertyOrders] optionally maps input object-schema JSON Pointers to full
  /// property permutations, without adding nonstandard JSON Schema keywords.
  ///
  /// Unknown or invalid keywords throw a typed package failure with a
  /// `schemaPath` before native work. [name] overrides the root title; otherwise
  /// a non-empty title or Output names the result. Input collections are copied.
  ///
  /// JSON patterns use ECMA-262 in the standard. [allowSwiftPatterns] must be
  /// enabled explicitly to use them as native Swift patterns; syntax and guide
  /// support are then checked natively. This importer is not a general data
  /// validator or a full JSON Schema implementation.
  factory StructuredSchema.fromJsonSchema(
    Map<String, Object?> schema, {
    String? name,
    bool allowSwiftPatterns = false,
    Map<String, List<String>> propertyOrders = const <String, List<String>>{},
  }) {
    return JsonSchemaImporter(allowSwiftPatterns: allowSwiftPatterns, propertyOrders: propertyOrders)
        .parse(schema, name: name);
  }

  /// Creates an object-root schema without generating Dart or Swift code.
  /// [propertyOrder] must list every field once; omission keeps alphabetical order.
  const StructuredSchema.object({
    required this.name,
    required this.properties,
    this.requiredProperties = const <String>[],
    this.propertyOrder,
    this.description,
    this.definitions = const <String, SchemaProperty>{},
  }) : type = 'object',
       _items = null,
       _enumValues = null,
       _pattern = null,
       _minimum = null,
       _maximum = null,
       _minItems = null,
       _maxItems = null,
       _exactItems = null,
       _alternatives = null,
       _referenceName = null;

  /// Creates an array root whose elements follow [items].
  /// Counts use the same non-negative range/exact semantics as array properties.
  const StructuredSchema.array({
    required String name,
    required SchemaProperty items,
    String? description,
    int? minItems,
    int? maxItems,
    int? exactItems,
    Map<String, SchemaProperty> definitions = const <String, SchemaProperty>{},
  }) : this._value(
         name: name,
         type: 'array',
         definitions: definitions,
         items: items,
         description: description,
         minItems: minItems,
         maxItems: maxItems,
         exactItems: exactItems,
       );

  /// Creates a string root, optionally constrained to an enum or Swift pattern.
  const StructuredSchema.string({
    required String name,
    String? description,
    List<String>? enumValues,
    String? pattern,
    Map<String, SchemaProperty> definitions = const <String, SchemaProperty>{},
  }) : this._value(
         name: name,
         type: 'string',
         definitions: definitions,
         description: description,
         enumValues: enumValues,
         pattern: pattern,
       );

  /// Creates an integer root with optional inclusive whole-number bounds.
  const StructuredSchema.integer({
    required String name,
    String? description,
    int? minimum,
    int? maximum,
    Map<String, SchemaProperty> definitions = const <String, SchemaProperty>{},
  }) : this._value(
         name: name,
         type: 'integer',
         definitions: definitions,
         description: description,
         minimum: minimum,
         maximum: maximum,
       );

  /// Creates a numeric root with optional inclusive finite bounds.
  /// Integer bounds must retain their exact value in native Double guides.
  const StructuredSchema.number({
    required String name,
    String? description,
    num? minimum,
    num? maximum,
    Map<String, SchemaProperty> definitions = const <String, SchemaProperty>{},
  }) : this._value(
         name: name,
         type: 'number',
         definitions: definitions,
         description: description,
         minimum: minimum,
         maximum: maximum,
       );

  /// Creates a boolean root whose decoded value may legitimately be false.
  const StructuredSchema.boolean({required String name, String? description,
    Map<String, SchemaProperty> definitions = const <String, SchemaProperty>{}})
    : this._value(name: name, type: 'boolean', description: description, definitions: definitions);

  /// Creates a root whose explicit value is null, requiring native OS 26.4 support.
  const StructuredSchema.nullValue({required String name, String? description,
    Map<String, SchemaProperty> definitions = const <String, SchemaProperty>{}})
    : this._value(name: name, type: 'null', description: description, definitions: definitions);

  /// Creates an anyOf root with one to eight branches; overlap is permitted.
  const StructuredSchema.anyOf({required String name, required List<SchemaProperty> alternatives,
    String? description, Map<String, SchemaProperty> definitions = const <String, SchemaProperty>{}})
    : this._value(name: name, type: 'anyOf', alternatives: alternatives, description: description, definitions: definitions);

  /// Creates a root referencing one name in its local definitions registry.
  const StructuredSchema.reference({required String name, required String reference,
    String? description, Map<String, SchemaProperty> definitions = const <String, SchemaProperty>{}})
    : this._value(name: name, type: 'reference', referenceName: reference, description: description, definitions: definitions);

  const StructuredSchema._value({
    required this.name,
    required this.type,
    this.description,
    SchemaProperty? items,
    List<String>? enumValues,
    String? pattern,
    num? minimum,
    num? maximum,
    int? minItems,
    int? maxItems,
    int? exactItems,
    List<SchemaProperty>? alternatives,
    String? referenceName,
    this.definitions = const <String, SchemaProperty>{},
  }) : properties = const <String, SchemaProperty>{},
       requiredProperties = const <String>[],
       propertyOrder = null,
       _items = items,
       _enumValues = enumValues,
       _pattern = pattern,
       _minimum = minimum,
       _maximum = maximum,
       _minItems = minItems,
       _maxItems = maxItems,
       _exactItems = exactItems,
       _alternatives = alternatives,
       _referenceName = referenceName;

  final SchemaProperty? _items;
  final List<String>? _enumValues;
  final String? _pattern;
  final num? _minimum;
  final num? _maximum;
  final int? _minItems;
  final int? _maxItems;
  final int? _exactItems;
  final List<SchemaProperty>? _alternatives;
  final String? _referenceName;

  /// Root-scoped acyclic local schemas, shared by references in any descendant.
  final Map<String, SchemaProperty> definitions;

  /// Root type name used by the native mapper.
  final String type;

  /// Non-empty name that identifies the requested output to the model.
  final String name;

  /// Optional short description of the root's meaning.
  final String? description;

  /// Fields for an object root; empty for array and scalar roots.
  final Map<String, SchemaProperty> properties;

  /// Required object-root fields; empty and unused for array/scalar roots.
  /// Every required object field must exist in [properties].
  final List<String> requiredProperties;

  /// Full order of object-root properties; omission keeps alphabetical order.
  /// Nested object orders belong to their individual SchemaProperty.object.
  final List<String>? propertyOrder;

  /// Validates and serializes this root and its descendants for the native mapper.
  ///
  /// Throws [ArgumentError] for invalid bounds, constraint combinations or nested
  /// required-field lists.
  /// Native mapping checks schema shape and Swift regular-expression syntax,
  /// reporting a schema path when a definition cannot be used.
  Map<String, Object?> toMap() {
    SchemaPropertyOrder.validate(type, properties, propertyOrder);
    if (type != 'object') {
      return <String, Object?>{
        'name': name,
        ...SchemaProperty(
          type: type,
          description: description,
          items: _items,
          enumValues: _enumValues,
          pattern: _pattern,
          minimum: _minimum,
          maximum: _maximum,
          minItems: _minItems,
          maxItems: _maxItems,
          exactItems: _exactItems,
          alternatives: _alternatives,
          referenceName: _referenceName,
        ).toMap(definitions: definitions),
      };
    }
    final encoded = SchemaProperty.object(properties: properties, requiredProperties: requiredProperties,
        propertyOrder: propertyOrder, description: description).toMap(definitions: definitions);
    return <String, Object?>{
      'name': name,
      'description': description,
      'type': 'object',
      'properties': encoded['properties'],
      'requiredProperties': requiredProperties,
      if (propertyOrder != null) 'propertyOrder': propertyOrder,
      if (encoded.containsKey('definitions')) 'definitions': encoded['definitions'],
    };
  }
}


/// Runtime schema used for guided generation.
final class StructuredSchema {
  const StructuredSchema.object({
    required this.name,
    required this.properties,
    this.requiredProperties = const <String>[],
    this.description,
  });

  final String name;
  final String? description;
  final Map<String, SchemaProperty> properties;
  final List<String> requiredProperties;

  Map<String, Object?> toMap() {
    return <String, Object?>{
      'name': name,
      'description': description,
      'type': 'object',
      'properties': properties.map(
        (String key, SchemaProperty value) =>
            MapEntry<String, Object?>(key, value.toMap()),
      ),
      'requiredProperties': requiredProperties,
    };
  }
}

/// A single property inside a structured generation schema.
final class SchemaProperty {
  const SchemaProperty({
    required this.type,
    this.description,
    this.enumValues,
    this.items,
    this.properties,
  });

  const SchemaProperty.string({this.description, this.enumValues})
    : type = 'string',
      items = null,
      properties = null;

  const SchemaProperty.integer({this.description})
    : type = 'integer',
      enumValues = null,
      items = null,
      properties = null;

  const SchemaProperty.number({this.description})
    : type = 'number',
      enumValues = null,
      items = null,
      properties = null;

  const SchemaProperty.boolean({this.description})
    : type = 'boolean',
      enumValues = null,
      items = null,
      properties = null;

  const SchemaProperty.array({required this.items, this.description})
    : type = 'array',
      enumValues = null,
      properties = null;

  const SchemaProperty.object({required this.properties, this.description})
    : type = 'object',
      enumValues = null,
      items = null;

  final String type;
  final String? description;
  final List<String>? enumValues;
  final SchemaProperty? items;
  final Map<String, SchemaProperty>? properties;

  Map<String, Object?> toMap() {
    return <String, Object?>{
      'type': type,
      'description': description,
      'enumValues': enumValues,
      'items': items?.toMap(),
      'properties': properties?.map(
        (String key, SchemaProperty value) =>
            MapEntry<String, Object?>(key, value.toMap()),
      ),
    };
  }
}

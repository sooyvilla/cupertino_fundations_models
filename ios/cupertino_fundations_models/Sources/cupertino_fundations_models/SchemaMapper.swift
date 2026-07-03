import Foundation
#if canImport(FoundationModels)
import FoundationModels

/// Maps Dart runtime schemas to Foundation Models generation schemas.
@available(iOS 26.0, *)
enum SchemaMapper {
    static func generationSchema(from map: [String: Any]) throws -> GenerationSchema {
        let name: String = map["name"] as? String ?? "Output"
        let root: DynamicGenerationSchema = try dynamicSchema(name: name, map: map)
        return try GenerationSchema(root: root, dependencies: [])
    }

    static func dynamicSchema(name: String, map: [String: Any]) throws -> DynamicGenerationSchema {
        let type: String = (map["type"] as? String ?? "object").lowercased()
        let description: String? = map["description"] as? String

        switch type {
        case "object":
            let propertyMaps: [String: Any] = map["properties"] as? [String: Any] ?? [:]
            let required: [String] = map["requiredProperties"] as? [String]
                ?? map["required"] as? [String]
                ?? Array(propertyMaps.keys)
            var properties: [DynamicGenerationSchema.Property] = []
            for key in propertyMaps.keys.sorted() {
                let propertyMap: [String: Any] = propertyMaps[key] as? [String: Any] ?? [:]
                let schema: DynamicGenerationSchema = try dynamicSchema(name: key, map: propertyMap)
                properties.append(
                    DynamicGenerationSchema.Property(
                        name: key,
                        description: propertyMap["description"] as? String,
                        schema: schema,
                        isOptional: !required.contains(key)
                    )
                )
            }
            return DynamicGenerationSchema(name: name, description: description, properties: properties)
        case "string":
            if let enumValues: [String] = stringList(from: map["enumValues"]), !enumValues.isEmpty {
                return DynamicGenerationSchema(name: name, description: description, anyOf: enumValues)
            }
            return DynamicGenerationSchema(type: String.self)
        case "integer":
            return DynamicGenerationSchema(type: Int.self)
        case "number":
            return DynamicGenerationSchema(type: Double.self)
        case "boolean":
            return DynamicGenerationSchema(type: Bool.self)
        case "array":
            let itemsMap: [String: Any] = map["items"] as? [String: Any] ?? ["type": "string"]
            let items: DynamicGenerationSchema = try dynamicSchema(name: "\(name)Item", map: itemsMap)
            return DynamicGenerationSchema(arrayOf: items)
        default:
            return DynamicGenerationSchema(type: String.self)
        }
    }

    static func structuredValue(fromJsonString jsonString: String) -> Any {
        guard let data: Data = jsonString.data(using: .utf8),
              let decoded: Any = try? JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed]) else {
            return NSNull()
        }
        return decoded
    }

    private static func stringList(from value: Any?) -> [String]? {
        guard let list: [Any] = value as? [Any] else {
            return value as? [String]
        }
        let strings: [String] = list.compactMap { $0 as? String }
        return strings.isEmpty ? nil : strings
    }
}
#endif

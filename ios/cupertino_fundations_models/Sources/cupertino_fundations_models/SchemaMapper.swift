import Foundation
#if canImport(FoundationModels)
import FoundationModels

/// Maps Dart runtime schemas to Foundation Models generation schemas.
@available(iOS 26.0, *)
enum SchemaMapper {
    static func generationSchema(from map: [String: Any]) throws -> GenerationSchema {
        if let value = map["name"], !(value is String) {
            throw NativeSessionError.invalidSchema(path: "#/name", reason: "The schema name must be a string.")
        }
        let name: String = map["name"] as? String ?? "Output"
        guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw NativeSessionError.invalidSchema(path: "#/name", reason: "The schema name must be non-empty.")
        }
        let root: DynamicGenerationSchema = try dynamicSchema(name: "CFMRoot_" + name, map: map, path: "#")
        return try GenerationSchema(root: root, dependencies: [])
    }

    private static func dynamicSchema(name: String, map: [String: Any], path: String, depth: Int = 0) throws -> DynamicGenerationSchema {
        let map: [String: Any] = map.filter { !($0.value is NSNull) }
        guard depth <= 16, !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw NativeSessionError.invalidSchema(path: path, reason: "Schemas need non-empty names and at most 16 nesting levels.")
        }
        let supportedKeys: Set<String> = ["name", "type", "description", "properties", "requiredProperties", "required", "items", "enumValues", "enum"]
        guard Set(map.keys).isSubset(of: supportedKeys) else {
            throw NativeSessionError.invalidSchema(path: path, reason: "The schema contains unsupported constraints. Use the documented schema subset.")
        }
        guard let rawType: String = map["type"] as? String else {
            throw NativeSessionError.invalidSchema(path: path, reason: "Every schema must declare a string type.")
        }
        let type: String = rawType.lowercased()
        if let value = map["description"], !(value is String) {
            throw NativeSessionError.invalidSchema(path: path, reason: "Schema descriptions must be strings.")
        }
        if let value = map["name"] {
            guard let declaredName = value as? String,
                  !declaredName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw NativeSessionError.invalidSchema(path: "\(path)/name", reason: "Schema names must be non-empty strings.")
            }
        }
        let typeKeys: Set<String>
        switch type {
        case "object": typeKeys = ["properties", "requiredProperties", "required"]
        case "array": typeKeys = ["items"]
        case "string": typeKeys = ["enumValues", "enum"]
        default: typeKeys = []
        }
        guard Set(map.keys).isSubset(of: typeKeys.union(["name", "type", "description"])) else {
            throw NativeSessionError.invalidSchema(path: path, reason: "The schema contains constraints incompatible with its type.")
        }
        let description: String? = map["description"] as? String

        switch type {
        case "object":
            if let value = map["properties"], !(value is [String: Any]) {
                throw NativeSessionError.invalidSchema(path: path, reason: "Object properties must contain a map of schemas.")
            }
            let propertyMaps: [String: Any] = map["properties"] as? [String: Any] ?? [:]
            guard propertyMaps.count <= 128 else {
                throw NativeSessionError.invalidSchema(path: path, reason: "An object schema supports at most 128 properties.")
            }
            guard map["requiredProperties"] == nil || map["required"] == nil else {
                throw NativeSessionError.invalidSchema(path: path, reason: "Use only one required-properties field.")
            }
            let rawRequired: Any? = map["requiredProperties"] ?? map["required"]
            if let rawRequired, !(rawRequired is [String]) {
                throw NativeSessionError.invalidSchema(path: path, reason: "Required properties must be a list of names.")
            }
            let required: [String] = rawRequired as? [String] ?? Array(propertyMaps.keys)
            guard Set(required).count == required.count,
                  Set(required).isSubset(of: Set(propertyMaps.keys)) else {
                throw NativeSessionError.invalidSchema(path: path, reason: "Required schema properties must exist in properties.")
            }
            var properties: [DynamicGenerationSchema.Property] = []
            for key in propertyMaps.keys.sorted() {
                let propertyPath = "\(path)/properties/\(pointerComponent(key))"
                guard !key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                    throw NativeSessionError.invalidSchema(path: propertyPath, reason: "Property names must be non-empty strings.")
                }
                guard let propertyMap: [String: Any] = propertyMaps[key] as? [String: Any] else {
                    throw NativeSessionError.invalidSchema(path: propertyPath, reason: "Every schema property must contain a schema object.")
                }
                let schema: DynamicGenerationSchema = try dynamicSchema(name: internalName(propertyPath), map: propertyMap, path: propertyPath, depth: depth + 1)
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
            guard map["enumValues"] == nil || map["enum"] == nil else {
                throw NativeSessionError.invalidSchema(path: path, reason: "Use only one string-enum field.")
            }
            if let rawEnum: Any = map["enumValues"] ?? map["enum"], !(rawEnum is NSNull) {
                guard let enumValues: [String] = rawEnum as? [String], !enumValues.isEmpty,
                      Set(enumValues).count == enumValues.count else {
                    throw NativeSessionError.invalidSchema(path: path, reason: "String enums must contain distinct values and cannot be empty.")
                }
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
            guard let itemsMap: [String: Any] = map["items"] as? [String: Any] else {
                throw NativeSessionError.invalidSchema(path: "\(path)/items", reason: "Array schemas require an items schema.")
            }
            let itemPath = "\(path)/items"
            let items: DynamicGenerationSchema = try dynamicSchema(name: internalName(itemPath), map: itemsMap, path: itemPath, depth: depth + 1)
            return DynamicGenerationSchema(arrayOf: items)
        default:
            throw NativeSessionError.invalidSchema(path: path, reason: "Unsupported schema type: \(type).")
        }
    }

    private static func pointerComponent(_ value: String) -> String {
        value.replacingOccurrences(of: "~", with: "~0")
            .replacingOccurrences(of: "/", with: "~1")
    }

    private static func internalName(_ path: String) -> String {
        "CFM_" + path.utf8.map { String(format: "%02x", Int($0)) }.joined()
    }

    static func structuredValue(fromJsonString jsonString: String) throws -> Any {
        guard let data: Data = jsonString.data(using: .utf8),
              let decoded: Any = try? JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed]) else {
            throw NativeSessionError.modelUnavailable(
                code: "parsingFailure",
                message: "The generated structured content could not be decoded as JSON.",
                recoverySuggestion: "Simplify the schema and handle this request as a failed generation."
            )
        }
        return decoded
    }

}
#endif

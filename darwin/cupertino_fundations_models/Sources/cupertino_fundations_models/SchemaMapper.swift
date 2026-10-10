import Foundation
import CoreFoundation
#if canImport(FoundationModels)
import FoundationModels

/// Maps Dart runtime schemas to Foundation Models generation schemas.
@available(iOS 26.0, macOS 26.0, *)
enum SchemaMapper {
    static func generationSchema(from map: [String: Any], explicitNullSchema: DynamicGenerationSchema?) throws -> GenerationSchema {
        if let value = map["name"], !(value is String) {
            throw NativeSessionError.invalidSchema(path: "#/name", reason: "The schema name must be a string.")
        }
        let name: String = map["name"] as? String ?? "Output"
        guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw NativeSessionError.invalidSchema(path: "#/name", reason: "The schema name must be non-empty.")
        }
        var rootMap = map
        let rawDefinitions = rootMap.removeValue(forKey: "definitions")
        guard rawDefinitions == nil || rawDefinitions is NSNull || rawDefinitions is [String: Any] else {
            throw NativeSessionError.invalidSchema(path: "#/definitions", reason: "Definitions must be a local schema map.")
        }
        let rawRegistry = rawDefinitions as? [String: Any] ?? [:]
        guard rawRegistry.count <= 32 else {
            throw NativeSessionError.invalidSchema(path: "#/definitions", reason: "Use at most 32 local definitions.")
        }
        var definitions: [String: [String: Any]] = [:]
        for (key, value) in rawRegistry {
            guard !key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                  let schema = value as? [String: Any] else {
                throw NativeSessionError.invalidSchema(path: "#/definitions/\(pointerComponent(key))", reason: "Definitions need non-empty names and schema objects.")
            }
            definitions[key] = schema
        }
        var nodes = 0
        var extended = !definitions.isEmpty
        let root: DynamicGenerationSchema = try dynamicSchema(name: "CFMRoot_" + name, map: rootMap, path: "#", definitions: definitions,
            explicitNullSchema: explicitNullSchema, nodes: &nodes, extended: &extended)
        var dependencies: [DynamicGenerationSchema] = []
        for key in definitions.keys.sorted() {
            let path = "#/definitions/\(pointerComponent(key))"
            let inner = try dynamicSchema(name: internalName(path), map: definitions[key]!, path: path, definitions: definitions,
                explicitNullSchema: explicitNullSchema, nodes: &nodes, extended: &extended)
            dependencies.append(DynamicGenerationSchema(name: referenceName(key), anyOf: [inner]))
        }
        return try GenerationSchema(root: root, dependencies: dependencies)
    }

    private static func dynamicSchema(name: String, map: [String: Any], path: String, depth: Int = 0,
        definitions: [String: [String: Any]], explicitNullSchema: DynamicGenerationSchema?, activeReferences: Set<String> = [],
        propertyDescriptionHandled: Bool = false,
        nodes: inout Int, extended: inout Bool) throws -> DynamicGenerationSchema {
        let map: [String: Any] = map.filter { !($0.value is NSNull) }
        guard depth <= 16, !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw NativeSessionError.invalidSchema(path: path, reason: "Schemas need non-empty names and at most 16 nesting levels.")
        }
        nodes += 1
        let supportedKeys: Set<String> = ["name", "type", "description", "properties", "requiredProperties", "required", "propertyOrder", "items", "enumValues", "enum", "minimum", "maximum", "pattern", "minItems", "maxItems", "anyOf", "reference"]
        guard Set(map.keys).isSubset(of: supportedKeys) else {
            throw NativeSessionError.invalidSchema(path: path, reason: "The schema contains unsupported constraints. Use the documented schema subset.")
        }
        guard let rawType: String = map["type"] as? String else {
            throw NativeSessionError.invalidSchema(path: path, reason: "Every schema must declare a string type.")
        }
        let type: String = rawType.lowercased()
        extended = extended || ["anyof", "reference", "null"].contains(type)
        guard !extended || nodes <= 512 else {
            throw NativeSessionError.invalidSchema(path: path, reason: "Extended graphs support at most 512 expanded nodes.")
        }
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
        case "object": typeKeys = ["properties", "requiredProperties", "required", "propertyOrder"]
        case "array": typeKeys = ["items", "minItems", "maxItems"]
        case "string": typeKeys = ["enumValues", "enum", "pattern"]
        case "integer", "number": typeKeys = ["minimum", "maximum"]
        case "anyof": typeKeys = ["anyOf"]
        case "reference": typeKeys = ["reference"]
        default: typeKeys = []
        }
        guard Set(map.keys).isSubset(of: typeKeys.union(["name", "type", "description"])) else {
            throw NativeSessionError.invalidSchema(path: path, reason: "The schema contains constraints incompatible with its type.")
        }
        let description: String? = map["description"] as? String
        let valueDescription = propertyDescriptionHandled ? nil : description

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
            let propertyOrder: [String]
            if let rawOrder = map["propertyOrder"] {
                guard let order = rawOrder as? [String], Set(order).count == order.count,
                      order.count == propertyMaps.count, Set(order) == Set(propertyMaps.keys) else {
                    throw NativeSessionError.invalidSchema(path: "\(path)/propertyOrder", reason: "An order must contain every object property exactly once.")
                }
                propertyOrder = order
            } else {
                propertyOrder = propertyMaps.keys.sorted()
            }
            for key in propertyOrder {
                let propertyPath = "\(path)/properties/\(pointerComponent(key))"
                guard !key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                    throw NativeSessionError.invalidSchema(path: propertyPath, reason: "Property names must be non-empty strings.")
                }
                guard let propertyMap: [String: Any] = propertyMaps[key] as? [String: Any] else {
                    throw NativeSessionError.invalidSchema(path: propertyPath, reason: "Every schema property must contain a schema object.")
                }
                let schema: DynamicGenerationSchema = try dynamicSchema(name: internalName(propertyPath), map: propertyMap, path: propertyPath, depth: depth + 1,
                    definitions: definitions, explicitNullSchema: explicitNullSchema, activeReferences: activeReferences,
                    propertyDescriptionHandled: true, nodes: &nodes, extended: &extended)
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
            var guides: [GenerationGuide<String>] = []
            guard map["enumValues"] == nil || map["enum"] == nil else {
                throw NativeSessionError.invalidSchema(path: path, reason: "Use only one string-enum field.")
            }
            if let rawEnum: Any = map["enumValues"] ?? map["enum"], !(rawEnum is NSNull) {
                guard let enumValues: [String] = rawEnum as? [String], !enumValues.isEmpty,
                      Set(enumValues).count == enumValues.count else {
                    throw NativeSessionError.invalidSchema(path: path, reason: "String enums must contain distinct values and cannot be empty.")
                }
                if map["pattern"] == nil {
                    return DynamicGenerationSchema(name: name, description: description, anyOf: enumValues)
                }
                guides.append(.anyOf(enumValues))
            }
            if let rawPattern = map["pattern"] {
                guard let pattern = rawPattern as? String,
                      let regex = try? Regex(pattern) else {
                    throw NativeSessionError.invalidSchema(path: "\(path)/pattern", reason: "String patterns must be valid Swift regular expressions.")
                }
                guides.append(.pattern(regex))
            }
            return described(DynamicGenerationSchema(type: String.self, guides: guides), name: name, description: valueDescription)
        case "integer":
            let minimum = try integerConstraint(map, key: "minimum", path: path)
            let maximum = try integerConstraint(map, key: "maximum", path: path)
            var guides: [GenerationGuide<Int>] = []
            if let minimum, let maximum {
                guard minimum <= maximum else {
                    throw NativeSessionError.invalidSchema(path: "\(path)/minimum", reason: "Minimum must not exceed maximum.")
                }
                guides.append(.range(minimum...maximum))
            } else if let minimum {
                guides.append(.minimum(minimum))
            } else if let maximum {
                guides.append(.maximum(maximum))
            }
            return described(DynamicGenerationSchema(type: Int.self, guides: guides), name: name, description: valueDescription)
        case "number":
            let minimum = try numberConstraint(map, key: "minimum", path: path, doubleGuide: true)?.doubleValue
            let maximum = try numberConstraint(map, key: "maximum", path: path, doubleGuide: true)?.doubleValue
            var guides: [GenerationGuide<Double>] = []
            if let minimum, let maximum {
                guard minimum <= maximum else {
                    throw NativeSessionError.invalidSchema(path: "\(path)/minimum", reason: "Minimum must not exceed maximum.")
                }
                guides.append(.range(minimum...maximum))
            } else if let minimum {
                guides.append(.minimum(minimum))
            } else if let maximum {
                guides.append(.maximum(maximum))
            }
            return described(DynamicGenerationSchema(type: Double.self, guides: guides), name: name, description: valueDescription)
        case "boolean":
            return described(DynamicGenerationSchema(type: Bool.self), name: name, description: valueDescription)
        case "array":
            guard let itemsMap: [String: Any] = map["items"] as? [String: Any] else {
                throw NativeSessionError.invalidSchema(path: "\(path)/items", reason: "Array schemas require an items schema.")
            }
            let itemPath = "\(path)/items"
            let items: DynamicGenerationSchema = try dynamicSchema(name: internalName(itemPath), map: itemsMap, path: itemPath, depth: depth + 1,
                definitions: definitions, explicitNullSchema: explicitNullSchema, activeReferences: activeReferences, nodes: &nodes, extended: &extended)
            let minimum = try arrayCount(map, key: "minItems", path: path)
            let maximum = try arrayCount(map, key: "maxItems", path: path)
            if let minimum, let maximum, minimum > maximum {
                throw NativeSessionError.invalidSchema(path: "\(path)/minItems", reason: "Minimum item count must not exceed maximum item count.")
            }
            return described(DynamicGenerationSchema(arrayOf: items, minimumElements: minimum, maximumElements: maximum), name: name, description: valueDescription)
        case "null":
            guard let nullSchema = explicitNullSchema else {
                throw NativeSessionError.modelUnavailable(code: "unsupportedCapability", message: "Explicit null at \(path) requires OS 26.4 and a compatible SDK.", recoverySuggestion: "Use a compatible host or handle this feature as unavailable.")
            }
            return described(nullSchema, name: name, description: valueDescription)
        case "anyof":
            guard let choices = map["anyOf"] as? [[String: Any]], !choices.isEmpty, choices.count <= 8 else {
                throw NativeSessionError.invalidSchema(path: "\(path)/anyOf", reason: "Use one to eight schema alternatives.")
            }
            var schemas: [DynamicGenerationSchema] = []
            for (index, choice) in choices.enumerated() {
                let branchPath = "\(path)/anyOf/\(index)"
                schemas.append(try dynamicSchema(name: internalName(branchPath), map: choice, path: branchPath, depth: depth + 1,
                    definitions: definitions, explicitNullSchema: explicitNullSchema, activeReferences: activeReferences, nodes: &nodes, extended: &extended))
            }
            return DynamicGenerationSchema(name: name, description: description, anyOf: schemas)
        case "reference":
            guard let reference = map["reference"] as? String, let target = definitions[reference],
                  !activeReferences.contains(reference) else {
                throw NativeSessionError.invalidSchema(path: "\(path)/reference", reason: "References must resolve locally without cycles.")
            }
            var active = activeReferences
            active.insert(reference)
            let targetPath = "#/definitions/\(pointerComponent(reference))"
            _ = try dynamicSchema(name: internalName(targetPath), map: target, path: targetPath, depth: depth + 1,
                definitions: definitions, explicitNullSchema: explicitNullSchema, activeReferences: active, nodes: &nodes, extended: &extended)
            return described(DynamicGenerationSchema(referenceTo: referenceName(reference)), name: name, description: valueDescription)
        default:
            throw NativeSessionError.invalidSchema(path: path, reason: "Unsupported schema type: \(type).")
        }
    }

    private static func described(_ schema: DynamicGenerationSchema, name: String, description: String?) -> DynamicGenerationSchema {
        guard let description else { return schema }
        return DynamicGenerationSchema(name: name + "_Annotated", description: description, anyOf: [schema])
    }

    private static func numberConstraint(_ map: [String: Any], key: String, path: String, doubleGuide: Bool = false) throws -> NSNumber? {
        guard let raw = map[key] else { return nil }
        guard let number = raw as? NSNumber,
              CFGetTypeID(number) != CFBooleanGetTypeID(),
              number.doubleValue.isFinite else {
            throw NativeSessionError.invalidSchema(path: "\(path)/\(key)", reason: "Numeric constraints must be finite numbers, not booleans or strings.")
        }
        if doubleGuide, !["f", "d"].contains(String(cString: number.objCType)) {
            guard let original = number as? Int, let converted = Int(exactly: number.doubleValue), original == converted else {
                throw NativeSessionError.invalidSchema(path: "\(path)/\(key)", reason: "Number limits must retain their integer value in native Double guides.")
            }
        }
        return number
    }

    private static func integerConstraint(_ map: [String: Any], key: String, path: String) throws -> Int? {
        guard let number = try numberConstraint(map, key: key, path: path) else { return nil }
        guard let value = number as? Int else {
            throw NativeSessionError.invalidSchema(path: "\(path)/\(key)", reason: "Integer constraints must be whole values representable by Int.")
        }
        return value
    }

    private static func arrayCount(_ map: [String: Any], key: String, path: String) throws -> Int? {
        guard let count = try integerConstraint(map, key: key, path: path) else { return nil }
        guard count >= 0 else {
            throw NativeSessionError.invalidSchema(path: "\(path)/\(key)", reason: "Array item counts must not be negative.")
        }
        return count
    }

    private static func pointerComponent(_ value: String) -> String {
        value.replacingOccurrences(of: "~", with: "~0")
            .replacingOccurrences(of: "/", with: "~1")
    }

    private static func internalName(_ path: String) -> String {
        "CFM_" + path.utf8.map { String(format: "%02x", Int($0)) }.joined()
    }

    private static func referenceName(_ name: String) -> String {
        "CFMDefinition_" + name.utf8.map { String(format: "%02x", Int($0)) }.joined()
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

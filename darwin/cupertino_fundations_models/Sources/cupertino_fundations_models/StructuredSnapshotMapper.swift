import Foundation
#if canImport(FoundationModels)
import FoundationModels

@available(iOS 26.0, macOS 26.0, *)
enum StructuredSnapshotMapper {
    static func snapshot(from content: GeneratedContent) throws -> [String: Any] {
        var present: [String] = []
        var complete: [String] = []
        let value = try project(content, path: "#", present: &present, complete: &complete)
        return ["hasValue": value != nil, "value": value ?? NSNull(),
                "isComplete": content.isComplete, "presentPaths": present, "completePaths": complete]
    }

    private static func project(_ content: GeneratedContent, path: String, present: inout [String], complete: inout [String]) throws -> Any? {
        present.append(path)
        if content.isComplete { complete.append(path) }
        if case .structure(let properties, let orderedKeys) = content.kind {
            var projected: [String: Any] = [:]
            for key in orderedKeys {
                let component = key.replacingOccurrences(of: "~", with: "~0").replacingOccurrences(of: "/", with: "~1")
                if let value = try project(properties[key]!, path: "\(path)/\(component)", present: &present, complete: &complete) {
                    projected[key] = value
                }
            }
            return projected
        }
        if case .array(let elements) = content.kind {
            var projected: [Any] = []
            for (index, element) in elements.enumerated() {
                guard let value = try project(element, path: "\(path)/\(index)", present: &present, complete: &complete) else { break }
                projected.append(value)
            }
            return projected
        }
        guard content.isComplete else { return nil }
        return try SchemaMapper.structuredValue(fromJsonString: content.jsonString)
    }
}
#endif

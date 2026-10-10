import Foundation
#if canImport(FoundationModels)
import FoundationModels

@available(iOS 26.0, macOS 26.0, *)
enum SessionHistoryCodec {
    static func export(_ transcript: Transcript, mode: String, useCase: String,
        instructions: String?, locale: String?, tools: [[String: Any]], environment: [String: String],
        createdAt: String) throws -> [String: Any] {
        let entries = try project(transcript)
        let data = try JSONEncoder().encode(transcript)
        guard data.count <= 1_048_576, let archive = String(data: data, encoding: .utf8) else {
            throw NativeSessionError.invalidRequest("History archives must fit one MiB of UTF-8 JSON.")
        }
        return ["formatVersion": 1, "nativeFormat": "apple.transcript.codable",
            "createdAt": createdAt, "mode": mode, "useCase": useCase,
            "instructions": instructions as Any? ?? NSNull(), "localeIdentifier": locale as Any? ?? NSNull(),
            "tools": tools, "environment": environment, "entries": entries, "nativeArchive": archive]
    }

    static func restore(_ map: [String: Any], mode: String, useCase: String, tools: [[String: Any]],
        environment: [String: String]) throws -> Transcript {
        guard map["formatVersion"] as? Int == 1, map["nativeFormat"] as? String == "apple.transcript.codable",
              map["mode"] as? String == mode, map["useCase"] as? String == useCase,
              let savedEnvironment = map["environment"] as? [String: String], savedEnvironment == environment,
              environment["sdkIdentifier"] != "unknown",
              let savedTools = map["tools"] as? [[String: Any]], try canonical(savedTools) == canonical(tools),
              let archive = map["nativeArchive"] as? String, let data = archive.data(using: .utf8), data.count <= 1_048_576 else {
            throw NativeSessionError.invalidRequest("History format, route, variant, tools and known host/SDK context must match.")
        }
        let transcript: Transcript
        do {
            transcript = try JSONDecoder().decode(Transcript.self, from: data)
        } catch {
            throw unsupported("The native transcript archive cannot be decoded by this SDK.")
        }
        let projected = try project(transcript)
        let registeredNames = Set(tools.compactMap { $0["name"] as? String })
        let recordedNames = projected.flatMap { row in
            (row["toolNames"] as! [String]) + (row["toolCalls"] as! [[String: Any]]).map { $0["toolName"] as! String }
        }
        guard Set(recordedNames).isSubset(of: registeredNames) else {
            throw NativeSessionError.invalidRequest("History tools must have matching current registrations.")
        }
        guard let savedEntries = map["entries"] as? [[String: Any]],
              try canonical(savedEntries) == canonical(projected) else {
            throw NativeSessionError.invalidRequest("History entry descriptors do not match the native archive.")
        }
        return transcript
    }

    private static func project(_ transcript: Transcript) throws -> [[String: Any]] {
        guard transcript.count <= 256 else { throw NativeSessionError.invalidRequest("History supports at most 256 entries.") }
        var entries: [[String: Any]] = []
        var ids: Set<String> = []
        var pending: [String: String] = [:]
        for entry in transcript {
            guard !entry.id.isEmpty, ids.insert(entry.id).inserted else {
                throw NativeSessionError.invalidRequest("History entries need distinct non-empty IDs.")
            }
            var row: [String: Any] = ["id": entry.id, "segments": [], "toolCalls": [], "toolNames": [], "assetIDs": []]
            #if compiler(>=6.4)
            if #available(iOS 27.0, macOS 27.0, *), case .reasoning(let reasoning) = entry {
                row["kind"] = "reasoning"
                row["segments"] = try segments(reasoning.segments)
                entries.append(row)
                continue
            }
            #endif
            switch entry {
            case .instructions(let value):
                row["kind"] = "instructions"
                row["segments"] = try segments(value.segments)
                row["toolNames"] = value.toolDefinitions.map(\.name)
            case .prompt(let value):
                row["kind"] = "prompt"
                row["segments"] = try segments(value.segments)
            case .response(let value):
                row["kind"] = "response"
                row["segments"] = try segments(value.segments)
                row["assetIDs"] = value.assetIDs
            case .toolCalls(let value):
                row["kind"] = "toolCalls"
                var calls: [[String: Any]] = []
                for call in value {
                    guard call.arguments.isComplete, pending[call.id] == nil else {
                        throw unsupported("Incomplete or duplicated historical tool calls cannot be restored.")
                    }
                    pending[call.id] = call.toolName
                    calls.append(["id": call.id, "toolName": call.toolName, "argumentsJson": call.arguments.jsonString])
                }
                row["toolCalls"] = calls
            case .toolOutput(let value):
                guard pending.removeValue(forKey: value.id) == value.toolName else {
                    throw unsupported("Historical tool outputs must match their recorded calls.")
                }
                row["kind"] = "toolOutput"
                row["toolNames"] = [value.toolName]
                row["segments"] = try segments(value.segments)
            default:
                throw unsupported("Binary/data and unknown transcript entries are outside this history profile.")
            }
            entries.append(row)
        }
        guard pending.isEmpty else { throw unsupported("Pending historical tool calls cannot be resumed safely.") }
        return entries
    }

    private static func segments(_ values: [Transcript.Segment]) throws -> [[String: Any]] {
        try values.map { segment in
            switch segment {
            case .text(let value):
                return ["kind": "text", "id": value.id, "text": value.content]
            case .structure(let value):
                guard value.content.isComplete else { throw unsupported("Incomplete structured history cannot be restored.") }
                #if compiler(>=6.4)
                let schemaName = value.schemaName
                #else
                let schemaName = value.source
                #endif
                return ["kind": "structure", "id": value.id, "schemaName": schemaName, "structuredJson": value.content.jsonString]
            default:
                throw unsupported("Attachment segments require asset handling outside this history profile.")
            }
        }
    }

    private static func canonical(_ value: Any) throws -> Data {
        try JSONSerialization.data(withJSONObject: value, options: [.sortedKeys])
    }

    private static func unsupported(_ message: String) -> NativeSessionError {
        .modelUnavailable(code: "unsupportedTranscriptContent", message: message,
            recoverySuggestion: "Keep the archive in its supported host context or start a new session explicitly.")
    }
}
#endif

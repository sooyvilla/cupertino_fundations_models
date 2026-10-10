import Foundation
import FoundationModels
import UniformTypeIdentifiers
import XCTest
@testable import CupertinoSchemaContracts

final class SessionHistoryCodecTests: XCTestCase {
    private let environment = ["platform": "macOS", "osVersion": "test-os", "sdkIdentifier": "test-sdk"]
    private let tools: [[String: Any]] = [["name": "lookup", "description": "Lookup", "parameters": ["type": "object"]]]

    private func envelope(_ transcript: Transcript, tools: [[String: Any]] = []) throws -> [String: Any] {
        try SessionHistoryCodec.export(transcript, mode: "local", useCase: "general", instructions: "Keep facts.",
            locale: "en_US", tools: tools, environment: environment, createdAt: "2026-10-09T23:00:00Z")
    }

    private func text(_ id: String, _ value: String) -> Transcript.Segment {
        .text(.init(id: id, content: value))
    }

    func testEmptyHistoryKeepsNilInstructionsAndLocaleWithoutCreatingContent() throws {
        let original = Transcript(entries: [])
        let map = try SessionHistoryCodec.export(original, mode: "local", useCase: "general", instructions: nil,
            locale: nil, tools: [], environment: environment, createdAt: "2026-10-09T23:00:00Z")
        XCTAssertTrue(map["instructions"] is NSNull)
        XCTAssertTrue(map["localeIdentifier"] is NSNull)
        XCTAssertEqual(try SessionHistoryCodec.restore(map, mode: "local", useCase: "general", tools: [], environment: environment).count, 0)
    }

    func testTextStructuredOptionsFormatsAndIDsRoundTripThroughTheRealSDK() throws {
        let schema = try SchemaMapper.generationSchema(from: ["name": "Fact", "type": "object", "properties": ["ok": ["type": "boolean"]]], explicitNullSchema: nil)
        let instructions = Transcript.Instructions(id: "instructions", segments: [text("i-text", "Keep facts.")], toolDefinitions: [])
        let prompt = Transcript.Prompt(id: "prompt", segments: [text("p-text", "Question")], options: .init(maximumResponseTokens: 23), responseFormat: .init(schema: schema))
        let structured = Transcript.StructuredSegment(id: "r-value", source: "Fact", content: try GeneratedContent(json: #"{"ok":false}"#))
        let response = Transcript.Response(id: "response", assetIDs: ["asset-version"], segments: [.structure(structured)])
        let original = Transcript(entries: [.instructions(instructions), .prompt(prompt), .response(response)])
        let map = try envelope(original)
        let restored = try SessionHistoryCodec.restore(map, mode: "local", useCase: "general", tools: [], environment: environment)
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
        XCTAssertEqual(try encoder.encode(restored), try encoder.encode(original))
        XCTAssertEqual((map["entries"] as? [[String: Any]])?.map { $0["id"] as? String }, ["instructions", "prompt", "response"])
        XCTAssertEqual((map["entries"] as? [[String: Any]])?.last?["assetIDs"] as? [String], ["asset-version"])
    }

    func testCompletedToolsAreRecordedAndRestoredAsData() throws {
        let call = Transcript.ToolCall(id: "call", toolName: "lookup", arguments: try GeneratedContent(json: #"{"name":"Morgan"}"#))
        let output = Transcript.ToolOutput(id: "call", toolName: "lookup", segments: [text("tool-text", "Found")])
        let original = Transcript(entries: [.toolCalls(.init(id: "calls", [call])), .toolOutput(output),
            .response(.init(id: "response", assetIDs: [], segments: [text("r-text", "Result")]))])
        let map = try envelope(original, tools: tools)
        let restored = try SessionHistoryCodec.restore(map, mode: "local", useCase: "general", tools: tools, environment: environment)
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
        XCTAssertEqual(try encoder.encode(restored), try encoder.encode(original))
        XCTAssertThrowsError(try SessionHistoryCodec.restore(map, mode: "local", useCase: "general", tools: [], environment: environment))
        var altered = map
        altered["tools"] = []
        XCTAssertThrowsError(try SessionHistoryCodec.restore(altered, mode: "local", useCase: "general", tools: [], environment: environment))
    }

    func testReasoningMetadataAndSignaturesStayInTheNativeArchive() throws {
        #if compiler(>=6.4)
        guard #available(macOS 27.0, *) else { throw XCTSkip("Reasoning requires OS27.") }
        let reasoning = Transcript.Reasoning(id: "reasoning", metadata: ["label": "test"], segments: [text("reason-text", "SDK provided")], signature: Data([1, 2, 3]))
        let original = Transcript(entries: [.reasoning(reasoning)])
        let map = try envelope(original)
        XCTAssertEqual((map["entries"] as? [[String: Any]])?.first?["kind"] as? String, "reasoning")
        XCTAssertEqual(Array(try SessionHistoryCodec.restore(map, mode: "local", useCase: "general", tools: [], environment: environment)), Array(original))
        #endif
    }

    func testInstructionsKeepNativeToolDefinitions() throws {
        let schema = try SchemaMapper.generationSchema(from: ["type": "object", "properties": [:]], explicitNullSchema: nil)
        let original = Transcript(entries: [.instructions(.init(id: "i", segments: [], toolDefinitions: [.init(name: "lookup", description: "Lookup", parameters: schema)]))])
        let map = try envelope(original, tools: tools)
        XCTAssertEqual(Array(try SessionHistoryCodec.restore(map, mode: "local", useCase: "general", tools: tools, environment: environment)), Array(original))
    }

    func testBoundsIncompleteDataAndPendingCallsFailRatherThanBeingTrimmed() throws {
        let tooMany = Transcript(entries: (0..<257).map { .prompt(.init(id: "p\($0)", segments: [])) })
        XCTAssertThrowsError(try envelope(tooMany))
        XCTAssertThrowsError(try envelope(Transcript(entries: [.prompt(.init(id: "p", segments: [])), .prompt(.init(id: "p", segments: []))])))
        XCTAssertThrowsError(try envelope(Transcript(entries: [.prompt(.init(id: "", segments: []))])))
        let incomplete = try GeneratedContent(json: #"{"name":"open"#)
        let pending = Transcript.ToolCall(id: "call", toolName: "lookup", arguments: try GeneratedContent(json: "{}"))
        XCTAssertThrowsError(try envelope(Transcript(entries: [.toolCalls(.init(id: "calls", [pending]))])))
        let partialCall = Transcript.ToolCall(id: "call", toolName: "lookup", arguments: incomplete)
        XCTAssertThrowsError(try envelope(Transcript(entries: [.toolCalls(.init(id: "calls", [partialCall]))])))
        XCTAssertThrowsError(try envelope(Transcript(entries: [.toolCalls(.init(id: "calls", [pending, pending]))])))
        XCTAssertThrowsError(try envelope(Transcript(entries: [.toolOutput(.init(id: "orphan", toolName: "lookup", segments: []))])))
        XCTAssertThrowsError(try envelope(Transcript(entries: [.response(.init(id: "r", assetIDs: [], segments: [.structure(.init(id: "s", source: "Partial", content: incomplete))]))])))
        XCTAssertThrowsError(try envelope(Transcript(entries: [.prompt(.init(id: "p", segments: [text("big", String(repeating: "x", count: 1_048_576))]))])))
    }

    func testHostToolsFormatAndArchiveMismatchFailExplicitly() throws {
        let original = Transcript(entries: [.prompt(.init(id: "p", segments: [text("p-text", "Question")]))])
        let map = try envelope(original)
        for change: [String: Any] in [["formatVersion": 2], ["nativeFormat": "other"], ["mode": "privateCloudCompute"],
            ["useCase": "contentTagging"], ["environment": ["platform": "iOS"]], ["nativeArchive": "{"],
            ["nativeArchive": String(repeating: "x", count: 1_048_577)], ["entries": []]] {
            var changed = map
            for (key, value) in change { changed[key] = value }
            XCTAssertThrowsError(try SessionHistoryCodec.restore(changed, mode: "local", useCase: "general", tools: [], environment: environment))
        }
        var unknown = environment; unknown["sdkIdentifier"] = "unknown"
        var changed = map; changed["environment"] = unknown
        XCTAssertThrowsError(try SessionHistoryCodec.restore(changed, mode: "local", useCase: "general", tools: [], environment: unknown))
    }

    func testBinaryEntriesAndAttachmentSegmentsAreNotClaimedAsDurableHistory() throws {
        #if compiler(>=6.4)
        guard #available(macOS 27.2, *) else { throw XCTSkip("Data entries require OS27.2.") }
        let data = Data([1, 2, 3])
        let entry = Transcript.DataEntry(id: "data", contentType: .json, content: data)
        XCTAssertThrowsError(try envelope(Transcript(entries: [.data(entry)])))
        let attachment = Transcript.AttachmentSegment(id: "attachment", content: .data(.init(contentType: .json, content: data)))
        XCTAssertThrowsError(try envelope(Transcript(entries: [.prompt(.init(id: "p", segments: [.attachment(attachment)]))])))
        #endif
    }
}

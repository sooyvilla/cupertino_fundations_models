import Foundation
import FoundationModels
import XCTest
@testable import CupertinoSchemaContracts

final class StructuredSnapshotMapperTests: XCTestCase {
    func testIncompleteStringIsObservedButNeverRepairedIntoAValue() throws {
        let snapshot = try StructuredSnapshotMapper.snapshot(from: GeneratedContent(json: #"{"name":"Morg"#))
        XCTAssertFalse(snapshot["isComplete"] as! Bool)
        XCTAssertTrue((snapshot["value"] as! [String: Any]).isEmpty)
        XCTAssertEqual(snapshot["presentPaths"] as? [String], ["#", "#/name"])
        XCTAssertEqual(snapshot["completePaths"] as? [String], [])
    }

    func testCompletedFieldsAndNestedContainersProjectWithoutFinalizingTheRoot() throws {
        let content = try GeneratedContent(json: #"{"name":"Morgan","rows":[{"amount":"-3,50"},{"amount":"+2"#)
        let snapshot = try StructuredSnapshotMapper.snapshot(from: content)
        XCTAssertFalse(snapshot["isComplete"] as! Bool)
        let value = snapshot["value"] as! [String: Any]
        XCTAssertEqual(value["name"] as? String, "Morgan")
        let rows = value["rows"] as! [[String: Any]]
        XCTAssertEqual(rows.count, 2)
        XCTAssertEqual(rows[0]["amount"] as? String, "-3,50")
        XCTAssertTrue(rows[1].isEmpty)
        XCTAssertTrue((snapshot["completePaths"] as! [String]).contains("#/rows/0/amount"))
    }

    func testPartialRootLeavesAndArrayPrefixDoNotInventValues() throws {
        for json in [#""open"#, "12.", "12"] {
            let snapshot = try StructuredSnapshotMapper.snapshot(from: GeneratedContent(json: json))
            XCTAssertFalse(snapshot["hasValue"] as! Bool)
            XCTAssertTrue(snapshot["value"] is NSNull)
        }
        let snapshot = try StructuredSnapshotMapper.snapshot(from: GeneratedContent(json: #"[1,"open"#))
        XCTAssertEqual(snapshot["value"] as? [Int], [1])
        XCTAssertEqual(snapshot["presentPaths"] as? [String], ["#", "#/0", "#/1"])
    }

    func testCompleteScalarsEmptyContainersNullAndEscapedPathsRemainExact() throws {
        let cases: [(GeneratedContent, String)] = [
            (GeneratedContent(kind: .bool(false)), "false"),
            (GeneratedContent(kind: .number(0)), "0"),
            (GeneratedContent(kind: .number(0.5)), "0.5"),
            (GeneratedContent(kind: .string("")), #""""#),
            (GeneratedContent(kind: .array([])), "[]"),
            (GeneratedContent(kind: .structure(properties: [:], orderedKeys: [])), "{}"),
            (GeneratedContent(kind: .null), "null")
        ]
        for (content, json) in cases {
            let snapshot = try StructuredSnapshotMapper.snapshot(from: content)
            XCTAssertTrue(snapshot["hasValue"] as! Bool)
            XCTAssertTrue(snapshot["isComplete"] as! Bool)
            XCTAssertEqual(snapshot["completePaths"] as? [String], ["#"])
            XCTAssertEqual(try JSONSerialization.data(withJSONObject: snapshot["value"]!, options: [.fragmentsAllowed, .sortedKeys]),
                           try JSONSerialization.data(withJSONObject: SchemaMapper.structuredValue(fromJsonString: json), options: [.fragmentsAllowed, .sortedKeys]))
        }
        let snapshot = try StructuredSnapshotMapper.snapshot(from: GeneratedContent(json: #"{"a/b~c":false}"#))
        XCTAssertEqual(snapshot["completePaths"] as? [String], ["#", "#/a~1b~0c"])
    }

    func testRevisionsAreIndependentReplaceableSnapshots() throws {
        let first = try StructuredSnapshotMapper.snapshot(from: GeneratedContent(json: #"{"name":"Morgan","email":"draft"}"#))
        let next = try StructuredSnapshotMapper.snapshot(from: GeneratedContent(json: #"{"name":"Riley"}"#))
        XCTAssertEqual((first["value"] as! [String: Any])["name"] as? String, "Morgan")
        XCTAssertNil((next["value"] as! [String: Any])["email"])
        XCTAssertEqual((next["value"] as! [String: Any])["name"] as? String, "Riley")
    }

    func testObservedPathsRetainTheOrderSuppliedByNativeContent() throws {
        let properties: KeyValuePairs<String, any ConvertibleToGeneratedContent> = ["z": "early", "a": "later"]
        let snapshot = try StructuredSnapshotMapper.snapshot(from: GeneratedContent(properties: properties))
        XCTAssertEqual(snapshot["presentPaths"] as? [String], ["#", "#/z", "#/a"])
    }
}

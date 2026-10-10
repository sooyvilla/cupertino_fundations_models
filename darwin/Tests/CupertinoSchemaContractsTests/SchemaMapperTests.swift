import Foundation
import FoundationModels
import XCTest
@testable import CupertinoSchemaContracts

final class SchemaMapperTests: XCTestCase {
    func testExplicitNullAndAnyOfUseRealNativeSchemas() throws {
        guard availableNullSchema != nil else { throw XCTSkip("Explicit null needs OS 26.4 and a compatible SDK.") }
        let null = try encoded(["type": "null"])
        XCTAssertEqual(null["type"] as? String, "null")
        let union = try encoded(["name": "NullableLabel", "type": "anyOf", "anyOf": [["type": "string"], ["type": "null"]]])
        XCTAssertNotNil(union["anyOf"])
        XCTAssertThrowsError(try SchemaMapper.generationSchema(from: ["type": "null"], explicitNullSchema: nil)) { error in
            guard case NativeSessionError.modelUnavailable(let code, _, _) = error else { return XCTFail("Expected capability failure.") }
            XCTAssertEqual(code, "unsupportedCapability")
        }
    }

    func testDefinitionsResolveAcrossObjectsScalarsAndRootReferences() throws {
        let map: [String: Any] = ["type": "object", "requiredProperties": ["home", "work", "rating"],
            "properties": ["home": ["type": "reference", "reference": "Address"],
                "work": ["type": "reference", "reference": "Address"], "rating": ["type": "reference", "reference": "Rating"]],
            "definitions": ["Address": ["type": "object", "requiredProperties": ["city"], "properties": ["city": ["type": "string"]]],
                "Rating": ["type": "integer", "minimum": 1, "maximum": 5]]]
        let schema = try encoded(map)
        let root = try encoded(["type": "reference", "reference": "Address", "definitions": map["definitions"]!])
        XCTAssertNotNil(schema["properties"])
        let rootObject = try semanticSchema(root, in: root)
        XCTAssertEqual(rootObject["type"] as? String, "object")
        XCTAssertEqual(rootObject["required"] as? [String], ["city"])
        let rootFields = try XCTUnwrap(rootObject["properties"] as? [String: Any])
        XCTAssertEqual(try semanticSchema(XCTUnwrap(rootFields["city"] as? [String: Any]), in: root)["type"] as? String, "string")
        let fields = try XCTUnwrap(schema["properties"] as? [String: Any])
        for key in ["home", "work"] {
            let address = try semanticSchema(XCTUnwrap(fields[key] as? [String: Any]), in: schema)
            XCTAssertEqual(address["type"] as? String, "object")
            XCTAssertEqual(address["required"] as? [String], ["city"])
            let addressFields = try XCTUnwrap(address["properties"] as? [String: Any])
            XCTAssertEqual(try semanticSchema(XCTUnwrap(addressFields["city"] as? [String: Any]), in: schema)["type"] as? String, "string")
        }
        let rating = try semanticSchema(XCTUnwrap(fields["rating"] as? [String: Any]), in: schema)
        XCTAssertEqual(rating["type"] as? String, "integer")
        XCTAssertEqual(rating["minimum"] as? Int, 1)
        XCTAssertEqual(rating["maximum"] as? Int, 5)
        let scalarRoot = try encoded(["type": "reference", "reference": "Rating", "definitions": map["definitions"]!])
        let scalar = try semanticSchema(scalarRoot, in: scalarRoot)
        XCTAssertEqual(scalar["type"] as? String, "integer")
        XCTAssertEqual(scalar["minimum"] as? Int, 1)
        XCTAssertEqual(scalar["maximum"] as? Int, 5)
    }

    func testRequiredNullableAndOptionalFieldsRemainIndependent() throws {
        guard availableNullSchema != nil else { throw XCTSkip("Explicit null needs OS 26.4 and a compatible SDK.") }
        let nullable: [String: Any] = ["type": "anyOf", "anyOf": [["type": "string"], ["type": "null"]]]
        let schema = try encoded(["type": "object", "requiredProperties": ["requiredNullable"],
            "properties": ["requiredNullable": nullable, "optionalNullable": nullable, "optionalText": ["type": "string"]]])
        XCTAssertEqual(schema["required"] as? [String], ["requiredNullable"])
        let fields = try XCTUnwrap(schema["properties"] as? [String: Any])
        let required = try resolved(XCTUnwrap(fields["requiredNullable"] as? [String: Any]), in: schema)
        XCTAssertEqual((required["anyOf"] as? [[String: Any]])?.last?["type"] as? String, "null")
        let snapshot = try StructuredSnapshotMapper.snapshot(from: GeneratedContent(json: #"{"requiredNullable":null}"#))
        let value = try XCTUnwrap(snapshot["value"] as? [String: Any])
        XCTAssertTrue(value["requiredNullable"] is NSNull)
        XCTAssertNil(value["optionalNullable"])
    }

    func testExtendedGraphsRejectUnknownCyclesAndMistypedRegistries() throws {
        assertInvalid(["type": "reference", "reference": "Missing"], path: "#/reference")
        assertInvalid(["type": "reference", "reference": 7], path: "#/reference")
        assertInvalid(["type": "reference", "reference": "A", "definitions": ["A": ["type": "reference", "reference": "A"]]], path: "#/definitions/A/reference")
        assertInvalid(["type": "string", "definitions": 7], path: "#/definitions")
        assertInvalid(["type": "string", "definitions": [" ": ["type": "string"]]], path: "#/definitions/ ")
        assertInvalid(["type": "string", "definitions": ["A": 7]], path: "#/definitions/A")
        assertInvalid(["type": "string", "definitions": Dictionary(uniqueKeysWithValues: (0..<33).map { ("D\($0)", ["type": "string"]) })], path: "#/definitions")
        for choices: Any in [[], 7, [true], Array(repeating: ["type": "string"], count: 9)] {
            assertInvalid(["type": "anyOf", "anyOf": choices], path: "#/anyOf")
        }
        assertInvalid(["type": "anyOf", "anyOf": [["type": "string"]], "minimum": 1], path: "#")
        _ = try encoded(["type": "anyOf", "anyOf": [["type": "boolean"]]])
    }

    func testNodeBudgetAppliesToNewGraphsAndNotLegacyTrees() throws {
        let branch: [String: Any] = ["type": "object", "properties": Dictionary(uniqueKeysWithValues: (0..<128).map { ("f\($0)", ["type": "string"]) })]
        XCTAssertThrowsError(try SchemaMapper.generationSchema(from: ["type": "anyOf", "anyOf": Array(repeating: branch, count: 4)], explicitNullSchema: availableNullSchema))
        _ = try encoded(["type": "object", "properties": Dictionary(uniqueKeysWithValues: (0..<5).map { ("g\($0)", branch) })])
    }

    func testExplicitPropertyOrderReachesFoundationModels() throws {
        let schema = try encoded(["type": "object", "propertyOrder": ["z", "a"],
            "properties": ["a": ["type": "string"], "z": ["type": "integer"]]])
        XCTAssertEqual(schema["x-order"] as? [String], ["z", "a"])
        XCTAssertEqual(schema["required"] as? [String], ["z", "a"])
        let legacy = try encoded(["type": "object", "properties": ["z": ["type": "integer"], "a": ["type": "string"]]])
        XCTAssertEqual(legacy["x-order"] as? [String], ["a", "z"])
        let nested = try encoded(["type": "array", "items": ["type": "object", "propertyOrder": ["z", "a"],
            "properties": ["a": ["type": "string"], "z": ["type": "integer"]]]])
        let item = try resolved(XCTUnwrap(nested["items"] as? [String: Any]), in: nested)
        XCTAssertEqual(item["x-order"] as? [String], ["z", "a"])
        for order: Any in [["a"], ["a", "a"], ["a", "missing"], 7] {
            assertInvalid(["type": "object", "propertyOrder": order,
                "properties": ["a": ["type": "string"], "z": ["type": "integer"]]], path: "#/propertyOrder")
        }
        _ = try encoded(["type": "object", "properties": [:], "propertyOrder": []])
        assertInvalid(["type": "array", "items": ["type": "string"], "propertyOrder": []], path: "#")
        assertInvalid(["type": "array", "items": ["type": "object", "properties": ["a": ["type": "string"]], "propertyOrder": []]], path: "#/items/propertyOrder")
    }

    func testImportedContactFixtureUsesTheProductionMapperWithoutLosingConstraints() throws {
        let fixture = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .appendingPathComponent("../../../test/fixtures/import_closed_contacts.native.json")
            .standardizedFileURL
        let input = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: fixture)) as? [String: Any])
        let schema = try encoded(input)
        XCTAssertEqual(schema["type"] as? String, "array")
        XCTAssertEqual(schema["maxItems"] as? Int, 10)
        let item = try resolved(XCTUnwrap(schema["items"] as? [String: Any]), in: schema)
        XCTAssertEqual(item["additionalProperties"] as? Bool, false)
        XCTAssertEqual(item["required"] as? [String], ["name"])
        let fields = try XCTUnwrap(item["properties"] as? [String: Any])
        XCTAssertEqual((fields["rating"] as? [String: Any])?["minimum"] as? Int, 1)
        XCTAssertEqual((fields["rating"] as? [String: Any])?["maximum"] as? Int, 5)
        XCTAssertEqual((fields["confidence"] as? [String: Any])?["maximum"] as? Double, 1)
        XCTAssertEqual(try stringChoices(XCTUnwrap(fields["status"] as? [String: Any]), in: schema), Set(["active", "inactive"]))
        XCTAssertEqual((fields["aliases"] as? [String: Any])?["maxItems"] as? Int, 3)
        XCTAssertEqual((fields["active"] as? [String: Any])?["type"] as? String, "boolean")
        let address = try resolved(XCTUnwrap(fields["address"] as? [String: Any]), in: schema)
        XCTAssertEqual(address["additionalProperties"] as? Bool, false)
        XCTAssertTrue((address["required"] as? [String] ?? []).isEmpty)
    }

    func testSupportTriageConstrainsRatingIdentifiersAndSuggestedActions() throws {
        let schema = try encoded([
            "name": "SupportTriage", "type": "object",
            "requiredProperties": ["severity", "ticket", "actions"],
            "properties": [
                "severity": ["type": "integer", "minimum": 1, "maximum": 5],
                "ticket": ["type": "string", "pattern": "^SUP-[0-9]{4}$"],
                "actions": ["type": "array", "minItems": 3, "maxItems": 3,
                            "items": ["type": "string"]]
            ]
        ])
        let properties = try XCTUnwrap(schema["properties"] as? [String: Any])
        let severity = try XCTUnwrap(properties["severity"] as? [String: Any])
        XCTAssertEqual(severity["minimum"] as? Int, 1)
        XCTAssertEqual(severity["maximum"] as? Int, 5)
        let ticket = try XCTUnwrap(properties["ticket"] as? [String: Any])
        let pattern = try Regex(XCTUnwrap(ticket["pattern"] as? String))
        XCTAssertNotNil("SUP-1234".wholeMatch(of: pattern))
        XCTAssertNil("SUP-12".wholeMatch(of: pattern))
        XCTAssertNil("OTHER-1234".wholeMatch(of: pattern))
        let actions = try XCTUnwrap(properties["actions"] as? [String: Any])
        XCTAssertEqual(actions["minItems"] as? Int, 3)
        XCTAssertEqual(actions["maxItems"] as? Int, 3)
    }

    func testInvoiceLineItemsRetainBoundsOnNestedQuantitiesAndPrices() throws {
        let schema = try encoded([
            "name": "Invoice", "type": "object", "properties": [
                "lines": ["type": "array", "minItems": 1, "maxItems": 20,
                          "items": ["type": "object", "properties": [
                            "quantity": ["type": "integer", "minimum": 1],
                            "price": ["type": "number", "minimum": 0.0, "maximum": 10000.5]
                          ]]]
            ]
        ])
        let properties = try XCTUnwrap(schema["properties"] as? [String: Any])
        let lines = try XCTUnwrap(properties["lines"] as? [String: Any])
        let item = try resolved(XCTUnwrap(lines["items"] as? [String: Any]), in: schema)
        let fields = try XCTUnwrap(item["properties"] as? [String: Any])
        XCTAssertEqual((fields["quantity"] as? [String: Any])?["minimum"] as? Int, 1)
        XCTAssertEqual((fields["price"] as? [String: Any])?["maximum"] as? Double, 10000.5)
        XCTAssertEqual(lines["minItems"] as? Int, 1)
        XCTAssertEqual(lines["maxItems"] as? Int, 20)
    }

    func testRejectsInvertedRangesWithTheConstraintPath() {
        assertInvalid(["type": "integer", "minimum": 5, "maximum": 1], path: "#/minimum")
        assertInvalid(["type": "number", "minimum": 1.5, "maximum": 0.5], path: "#/minimum")
        assertInvalid(["type": "array", "items": ["type": "string"], "minItems": 3, "maxItems": 1], path: "#/minItems")
    }

    func testRejectsMistypedNonFiniteAndFractionalBounds() {
        for value: Any in [true, "1", Double.nan, Double.infinity, -Double.infinity, 1.5] {
            assertInvalid(["type": "integer", "minimum": value], path: "#/minimum")
        }
        for value: Any in [true, "1", Double.nan, Double.infinity, -Double.infinity] {
            assertInvalid(["type": "number", "maximum": value], path: "#/maximum")
        }
        for value: Any in [true, "3", -1, 1.5] {
            assertInvalid(["type": "array", "items": ["type": "string"], "minItems": value], path: "#/minItems")
        }
    }

    func testRejectsMalformedPatternsInsteadOfDroppingTheConstraint() {
        assertInvalid(["type": "string", "pattern": "["], path: "#/pattern")
        assertInvalid(["type": "string", "pattern": 7], path: "#/pattern")
    }

    func testOneSidedAndEqualBoundsArePreserved() throws {
        let cases: [([String: Any], String, Double)] = [
            (["type": "integer", "minimum": -5], "minimum", -5),
            (["type": "integer", "maximum": 0], "maximum", 0),
            (["type": "integer", "minimum": 2, "maximum": 2], "maximum", 2),
            (["type": "number", "minimum": -0.25], "minimum", -0.25),
            (["type": "number", "maximum": 0.75], "maximum", 0.75),
            (["type": "number", "minimum": 0.5, "maximum": 0.5], "minimum", 0.5)
        ]
        for (input, key, value) in cases {
            XCTAssertEqual((try encoded(input)[key] as? NSNumber)?.doubleValue, value)
        }
    }

    func testIntegerBoundsRetainThePlatformIntegerExtremes() throws {
        let lower = try encoded(["type": "integer", "minimum": Int.min])
        let upper = try encoded(["type": "integer", "maximum": Int.max])
        XCTAssertEqual(lower["minimum"] as? Int, Int.min)
        XCTAssertEqual(upper["maximum"] as? Int, Int.max)
        assertInvalid(["type": "integer", "maximum": UInt64.max], path: "#/maximum")
    }

    func testNumberGuidesRejectIntegerPrecisionLossWithoutNarrowingIntegerSchemas() throws {
        assertInvalid(["type": "number", "maximum": UInt64.max], path: "#/maximum")
        for value in [9_007_199_254_740_993, -9_007_199_254_740_993, Int.max] {
            assertInvalid(["type": "number", "minimum": value], path: "#/minimum")
            assertInvalid(["type": "number", "maximum": value], path: "#/maximum")
        }
        for value in [9_007_199_254_740_992, 9_007_199_254_740_994, Int.min] {
            let schema = try encoded(["type": "number", "minimum": value])
            XCTAssertEqual((schema["minimum"] as? NSNumber)?.doubleValue, Double(value))
        }
        let beyondInteger = try encoded(["type": "number", "maximum": 9_223_372_036_854_775_808.0])
        XCTAssertEqual((beyondInteger["maximum"] as? NSNumber)?.doubleValue, 9_223_372_036_854_775_808.0)
    }

    func testRootDescriptionsReachNativeGuidanceForEverySupportedRoot() throws {
        let description = "Extract only the supplied value."
        let object = try encoded(["type": "object", "properties": [:], "description": description])
        XCTAssertEqual(object["description"] as? String, description)
        var roots: [[String: Any]] = [
            ["type": "string"], ["type": "string", "enumValues": ["yes", "no"]],
            ["type": "string", "enumValues": ["yes", "no"], "pattern": "^[a-z]+$"],
            ["type": "integer", "minimum": 1, "maximum": 5],
            ["type": "number", "minimum": 0.25], ["type": "boolean"],
            ["type": "array", "items": ["type": "string"], "maxItems": 3],
            ["type": "anyOf", "anyOf": [["type": "boolean"], ["type": "integer"]]],
            ["type": "reference", "reference": "Score", "definitions": ["Score": ["type": "integer", "minimum": 1]]]
        ]
        if availableNullSchema != nil { roots.append(["type": "null"]) }
        for var input in roots {
            input["description"] = description
            let schema = try encoded(input)
            XCTAssertEqual(schema["description"] as? String, description, "Root: \(input["type"]!)")
        }
        let scalar = try encoded(["type": "integer", "description": description, "minimum": 1, "maximum": 5])
        let scalarChoice = try resolved(XCTUnwrap((scalar["anyOf"] as? [[String: Any]])?.first), in: scalar)
        XCTAssertEqual(scalarChoice["type"] as? String, "integer")
        XCTAssertEqual(scalarChoice["minimum"] as? Int, 1)
        XCTAssertEqual(scalarChoice["maximum"] as? Int, 5)
        let array = try encoded(["type": "array", "description": description, "items": ["type": "boolean"], "maxItems": 3])
        let arrayChoice = try resolved(XCTUnwrap((array["anyOf"] as? [[String: Any]])?.first), in: array)
        XCTAssertEqual(arrayChoice["type"] as? String, "array")
        XCTAssertEqual(arrayChoice["maxItems"] as? Int, 3)
        let manualString = try encoded(["type": "string", "description": description, "enumValues": NSNull(), "pattern": NSNull()])
        XCTAssertEqual(manualString["description"] as? String, description)
        let enumAlias = try encoded(["type": "string", "description": description, "enum": ["yes", "no"], "pattern": NSNull()])
        XCTAssertEqual(enumAlias["description"] as? String, description)
    }

    func testUnnamedNestedDescriptionsRemainGuidanceWithoutChangingItemConstraints() throws {
        let array = try encoded(["type": "array", "items": ["type": "integer", "description": "Supplied score", "minimum": 1]])
        let item = try resolved(XCTUnwrap(array["items"] as? [String: Any]), in: array)
        XCTAssertEqual(item["description"] as? String, "Supplied score")
        let itemValue = try resolved(XCTUnwrap((item["anyOf"] as? [[String: Any]])?.first), in: array)
        XCTAssertEqual(itemValue["minimum"] as? Int, 1)
        let union = try encoded(["type": "anyOf", "anyOf": [["type": "boolean", "description": "Explicit approval"], ["type": "integer"]]])
        let choice = try resolved(XCTUnwrap((union["anyOf"] as? [[String: Any]])?.first), in: union)
        XCTAssertEqual(choice["description"] as? String, "Explicit approval")
        let reference = try encoded(["type": "array", "items": ["type": "reference", "reference": "Score", "description": "Each supplied score"],
            "definitions": ["Score": ["type": "integer", "description": "Score definition", "minimum": 1]]])
        let referenceItem = try resolved(XCTUnwrap(reference["items"] as? [String: Any]), in: reference)
        XCTAssertEqual(referenceItem["description"] as? String, "Each supplied score")
        let alias = try resolved(XCTUnwrap((referenceItem["anyOf"] as? [[String: Any]])?.first), in: reference)
        let definition = try resolved(XCTUnwrap((alias["anyOf"] as? [[String: Any]])?.first), in: reference)
        XCTAssertEqual(definition["description"] as? String, "Score definition")
    }

    func testEmptyAndOneSidedArrayCountsRemainExpressible() throws {
        for key in ["minItems", "maxItems"] {
            let schema = try encoded(["type": "array", "items": ["type": "boolean"], key: 0])
            XCTAssertEqual(schema[key] as? Int, 0)
        }
        let exact = try encoded(["type": "array", "items": ["type": "string"], "minItems": 0, "maxItems": 0])
        XCTAssertEqual(exact["maxItems"] as? Int, 0)
        assertInvalid(["type": "array", "items": ["type": "string"], "maxItems": -1], path: "#/maxItems")
    }

    func testEnumsAndPatternsCanBeCombined() throws {
        let schema = try encoded(["type": "string", "enumValues": ["a", "b"], "pattern": "^[ab]$"])
        XCTAssertEqual(schema["enum"] as? [String], ["a", "b"])
        XCTAssertNotNil(schema["pattern"])
        _ = try encoded(["type": "string", "pattern": ""])
    }

    func testLegacyUnboundedTypesAndNullMetadataStillMap() throws {
        for type in ["string", "integer", "number", "boolean"] {
            let schema = try encoded(["type": type, "description": NSNull(), "minimum": NSNull()])
            XCTAssertEqual(schema["type"] as? String, type)
        }
        let schema = try encoded(["type": "array", "items": ["type": "string"]])
        XCTAssertNil(schema["maxItems"])
        let levels = try encoded(["type": "string", "enum": ["low", "high"]])
        XCTAssertEqual(try stringChoices(levels, in: levels), Set(["low", "high"]))
    }

    func testIndependentNestedObjectsWithRepeatedFieldNamesHaveUniqueTypes() throws {
        let nested: [String: Any] = ["type": "object", "properties": ["status": ["type": "string", "enumValues": ["open", "closed"]]]]
        let schema = try encoded(["name": "TwoObjects", "type": "object", "properties": ["first": nested, "second": nested]])
        let properties = try XCTUnwrap(schema["properties"] as? [String: Any])
        XCTAssertNotNil(properties["first"])
        XCTAssertNotNil(properties["second"])
    }

    func testInvalidNestedConstraintsReportEscapedPropertyPaths() {
        assertInvalid(["type": "object", "properties": ["a/b~c": ["type": "number", "minimum": true]]], path: "#/properties/a~1b~0c/minimum")
    }

    func testRejectsUnknownTypesKeywordsAndConstraintsOnWrongTypes() {
        for input: [String: Any] in [
            ["type": "future"], ["type": "string", "format": "email"],
            ["type": "string", "minimum": 1], ["type": "boolean", "pattern": "x"],
            ["type": "integer", "minItems": 1]
        ] {
            assertInvalid(input, path: "#")
        }
    }

    func testMalformedSchemaMetadataIsRejectedBeforeNativeGeneration() {
        assertInvalid(["name": 7, "type": "object"], path: "#/name")
        assertInvalid(["name": " ", "type": "object"], path: "#/name")
        assertInvalid(["description": true, "type": "string"], path: "#")
        assertInvalid(["name": "x"], path: "#")
        assertInvalid(["type": 7], path: "#")
        assertInvalid(["type": "object", "properties": ["x": ["type": "string", "name": 7]]], path: "#/properties/x/name")
        assertInvalid(["type": "object", "properties": ["x": ["type": "string", "name": " "]]], path: "#/properties/x/name")
    }

    func testObjectShapeAndRequiredFieldsRemainChecked() throws {
        assertInvalid(["type": "object", "properties": 7], path: "#")
        assertInvalid(["type": "object", "properties": [" ": ["type": "string"]]], path: "#/properties/ ")
        assertInvalid(["type": "object", "properties": ["x": 7]], path: "#/properties/x")
        assertInvalid(["type": "object", "required": ["missing"]], path: "#")
        assertInvalid(["type": "object", "required": 7], path: "#")
        assertInvalid(["type": "object", "required": ["x", "x"], "properties": ["x": ["type": "string"]]], path: "#")
        assertInvalid(["type": "object", "required": [], "requiredProperties": []], path: "#")
        let optional = try encoded(["type": "object", "properties": ["x": ["type": "string"]], "requiredProperties": []])
        XCTAssertFalse((optional["required"] as? [String] ?? []).contains("x"))
        let required = try encoded(["type": "object", "properties": ["x": ["type": "string"]], "required": ["x"]])
        XCTAssertEqual(required["required"] as? [String], ["x"])
    }

    func testObjectSizeAndDepthRemainBounded() throws {
        var properties: [String: Any] = [:]
        for index in 0..<129 { properties["field\(index)"] = ["type": "string"] }
        assertInvalid(["type": "object", "properties": properties], path: "#")
        var nested: [String: Any] = ["type": "string"]
        for _ in 0..<17 { nested = ["type": "array", "items": nested] }
        assertInvalid(nested, path: "#" + String(repeating: "/items", count: 17))
    }

    func testEnumsRejectDuplicatesEmptyListsAndConflictingAliases() {
        for input: [String: Any] in [
            ["type": "string", "enumValues": []],
            ["type": "string", "enumValues": ["a", "a"]],
            ["type": "string", "enumValues": [7]],
            ["type": "string", "enumValues": ["a"], "enum": ["a"]]
        ] { assertInvalid(input, path: "#") }
        assertInvalid(["type": "array"], path: "#/items")
        assertInvalid(["type": "array", "items": 7], path: "#/items")
    }

    func testStructuredValuesPreserveValidObjectsArraysAndScalars() throws {
        let object = try SchemaMapper.structuredValue(fromJsonString: "{\"items\":[1,true,null]}")
        XCTAssertNotNil((object as? [String: Any])?["items"] as? [Any])
        XCTAssertEqual(try SchemaMapper.structuredValue(fromJsonString: "[1,2]") as? [Int], [1, 2])
        XCTAssertEqual(try SchemaMapper.structuredValue(fromJsonString: "3") as? Int, 3)
        XCTAssertEqual(try SchemaMapper.structuredValue(fromJsonString: "\"value\"") as? String, "value")
        XCTAssertTrue(try SchemaMapper.structuredValue(fromJsonString: "null") is NSNull)
    }

    func testIncompleteOrMalformedStructuredValuesFailInsteadOfBeingRepaired() {
        for json in ["{", "{\"x\":}", "NaN", "", "[1,"] {
            XCTAssertThrowsError(try SchemaMapper.structuredValue(fromJsonString: json)) { error in
                guard case NativeSessionError.modelUnavailable(let code, _, _) = error else {
                    return XCTFail("Expected parsingFailure, got \(error)")
                }
                XCTAssertEqual(code, "parsingFailure")
            }
        }
    }

    private var availableNullSchema: DynamicGenerationSchema? {
        #if compiler(>=6.3)
        if #available(macOS 26.4, *) { return .null }
        #endif
        return nil
    }

    private func encoded(_ map: [String: Any]) throws -> [String: Any] {
        let schema = try SchemaMapper.generationSchema(from: map, explicitNullSchema: availableNullSchema)
        let json = try JSONSerialization.jsonObject(with: JSONEncoder().encode(schema))
        return try XCTUnwrap(json as? [String: Any])
    }

    func testArrayRootContactsRetainNestedRequiredAndOptionalChoices() throws {
        let schema = try encoded([
            "name": "Contacts", "type": "array", "minItems": 0, "maxItems": 10,
            "items": ["type": "object", "requiredProperties": ["name"], "properties": [
                "name": ["type": "string"],
                "email": ["type": "string"],
                "address": ["type": "object", "requiredProperties": [], "properties": ["city": ["type": "string"]]]
            ]]
        ])
        XCTAssertEqual(schema["type"] as? String, "array")
        let item = try resolved(XCTUnwrap(schema["items"] as? [String: Any]), in: schema)
        XCTAssertEqual(item["required"] as? [String], ["name"])
        let fields = try XCTUnwrap(item["properties"] as? [String: Any])
        let address = try resolved(XCTUnwrap(fields["address"] as? [String: Any]), in: schema)
        XCTAssertTrue((address["required"] as? [String] ?? []).isEmpty)
        XCTAssertEqual(schema["maxItems"] as? Int, 10)
    }

    func testOmittedNestedRequiredPreservesAllRequiredLegacyShape() throws {
        let schema = try encoded([
            "type": "object", "requiredProperties": [], "properties": [
                "contact": ["type": "object", "properties": ["name": ["type": "string"], "email": ["type": "string"]]]
            ]
        ])
        XCTAssertTrue((schema["required"] as? [String] ?? []).isEmpty)
        let fields = try XCTUnwrap(schema["properties"] as? [String: Any])
        let contact = try resolved(XCTUnwrap(fields["contact"] as? [String: Any]), in: schema)
        XCTAssertEqual(Set(contact["required"] as? [String] ?? []), Set(["name", "email"]))
    }

    func testFalseZeroEmptyStringAndEmptyArrayAreValidFinalRootValues() throws {
        XCTAssertEqual(try SchemaMapper.structuredValue(fromJsonString: "false") as? Bool, false)
        XCTAssertEqual(try SchemaMapper.structuredValue(fromJsonString: "0") as? Int, 0)
        XCTAssertEqual(try SchemaMapper.structuredValue(fromJsonString: "0.0") as? Double, 0.0)
        XCTAssertEqual(try SchemaMapper.structuredValue(fromJsonString: "\"\"") as? String, "")
        XCTAssertEqual((try SchemaMapper.structuredValue(fromJsonString: "[]") as? [Any])?.count, 0)
    }

    func testNestedRequiredErrorsKeepTheObjectLocation() {
        for required: Any in [["missing"], ["name", "name"], 7] {
            assertInvalid(["type": "array", "items": ["type": "object", "requiredProperties": required,
                "properties": ["name": ["type": "string"]]]], path: "#/items")
        }
    }

    private func resolved(_ node: [String: Any], in document: [String: Any]) throws -> [String: Any] {
        guard let reference = node["$ref"] as? String else { return node }
        XCTAssertTrue(reference.hasPrefix("#/"))
        var value: Any = document
        for component in reference.dropFirst(2).split(separator: "/") {
            let key = String(component).replacingOccurrences(of: "~1", with: "/").replacingOccurrences(of: "~0", with: "~")
            value = try XCTUnwrap((value as? [String: Any])?[key], "Missing \(key) while resolving \(reference) in native schema: \(document)")
        }
        return try XCTUnwrap(value as? [String: Any])
    }

    private func semanticSchema(_ node: [String: Any], in document: [String: Any]) throws -> [String: Any] {
        var current = node
        for _ in 0..<64 {
            if current["$ref"] != nil { current = try resolved(current, in: document); continue }
            if let choices = current["anyOf"] as? [[String: Any]], choices.count == 1 {
                current = choices[0]; continue
            }
            return current
        }
        XCTFail("Native schema references did not resolve within the bounded graph.")
        return [:]
    }

    private func stringChoices(_ node: [String: Any], in document: [String: Any], depth: Int = 0) throws -> Set<String> {
        guard depth < 64 else { XCTFail("Native string choices exceeded the bounded graph."); return [] }
        if node["$ref"] != nil { return try stringChoices(resolved(node, in: document), in: document, depth: depth + 1) }
        if let values = node["enum"] as? [String] { return Set(values) }
        if let value = node["const"] as? String { return [value] }
        let choices = try XCTUnwrap(node["anyOf"] as? [[String: Any]], "Expected bounded native string choices.")
        XCTAssertFalse(choices.isEmpty)
        var values: Set<String> = []
        for choice in choices { values.formUnion(try stringChoices(choice, in: document, depth: depth + 1)) }
        return values
    }

    private func assertInvalid(_ map: [String: Any], path: String, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertThrowsError(try SchemaMapper.generationSchema(from: map, explicitNullSchema: availableNullSchema), file: file, line: line) { error in
            guard case NativeSessionError.invalidSchema(let actualPath, _) = error else {
                return XCTFail("Expected invalidSchema, got \(error)", file: file, line: line)
            }
            XCTAssertEqual(actualPath, path, file: file, line: line)
        }
    }
}

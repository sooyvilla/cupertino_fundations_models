import Foundation
import XCTest
@testable import CupertinoSchemaContracts

final class TextModelLanguageMapperTests: XCTestCase {
    func testAdvertisedTextLanguagesAreSortedAndLabeledWithoutSpeechState() {
        let languages: Set<Locale.Language> = [Locale.Language(identifier: "zh-Hans"), Locale.Language(identifier: "es"), Locale.Language(identifier: "en")]
        let rows = TextModelLanguageMapper.rows(languages, displayLocale: Locale(identifier: "en"))
        XCTAssertEqual(rows.map { $0["identifier"] as! String }, languages.map(\.minimalIdentifier).sorted())
        XCTAssertEqual(rows.first?["languageCode"] as? String, "en")
        XCTAssertEqual(rows.first?["displayName"] as? String, "English")
        XCTAssertEqual(rows[1]["nativeDisplayName"] as? String, "español")
        XCTAssertFalse(rows.contains { $0["isTranscriptionAssetInstalled"] != nil })
        XCTAssertTrue(TextModelLanguageMapper.rows([]).isEmpty)
    }

    func testUnknownLanguageLabelsKeepTheirIdentifiersWithoutInventingSupport() {
        let languages = Set(["", "und", "qzz", "x-private", "zxx"].map { Locale.Language(identifier: $0) })
        let rows = TextModelLanguageMapper.rows(languages, displayLocale: Locale(identifier: "qzz"))
        XCTAssertEqual(rows.count, languages.count)
        for row in rows {
            XCTAssertNotNil(row["identifier"] as? String)
            XCTAssertNotNil(row["languageCode"] as? String)
            XCTAssertNotNil(row["displayName"] as? String)
            XCTAssertNotNil(row["nativeDisplayName"] as? String)
        }
    }
}

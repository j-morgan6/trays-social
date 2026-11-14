@testable import TraysSocial
import XCTest

private struct VectorFile: Decodable {
    let schemaVersion: Int
    let fallback: String
    let abbreviations: [String]
    let whitespace: [String]
    let lineBreaks: [String]
    let ruleTags: [String: String]
    let vectors: [Vector]

    /// Explicit keys, not .convertFromSnakeCase, which would also rewrite
    /// the rule tags used as dictionary keys ("dotted_initial").
    enum CodingKeys: String, CodingKey {
        case schemaVersion = "schema_version"
        case fallback, abbreviations, whitespace, vectors
        case lineBreaks = "line_breaks"
        case ruleTags = "rule_tags"
    }
}

private struct Vector: Decodable {
    let rule: String
    let caption: String?
    let title: String
    let note: String
}

/// W267: the shared recipe title and note vectors. tray_formatting_test.exs
/// reads the same Fixtures/recipe-title-vectors.json, so iOS and web are held
/// to one list instead of two hand-copied ones.
final class RecipeTitleVectorTests: XCTestCase {
    /// Fails loudly when the resource is missing, so a for-loop over zero
    /// vectors can never pass silently.
    private func loadVectorFile() throws -> VectorFile {
        let url = try XCTUnwrap(
            Bundle(for: RecipeTitleVectorTests.self).url(forResource: "recipe-title-vectors", withExtension: "json"),
            "recipe-title-vectors.json is not in the test bundle; run scripts/regen-xcodeproj.sh"
        )
        return try JSONDecoder().decode(VectorFile.self, from: Data(contentsOf: url))
    }

    private func characters(_ strings: [String]) -> Set<Character> {
        Set(strings.compactMap { $0.count == 1 ? $0.first : nil })
    }

    func test_vectorFileIsBundled() throws {
        let file = try loadVectorFile()
        XCTAssertEqual(file.schemaVersion, 1)
        XCTAssertEqual(file.fallback, "Untitled recipe")
        XCTAssertFalse(file.vectors.isEmpty)
        XCTAssertEqual(Set(file.vectors.map(\.rule)), Set(file.ruleTags.keys))
    }

    func test_everySharedVectorMatches() throws {
        let file = try loadVectorFile()
        XCTAssertFalse(file.vectors.isEmpty)
        for vector in file.vectors {
            let label = String(reflecting: vector.caption)
            XCTAssertEqual(
                RecipeTitle.from(caption: vector.caption, fallback: file.fallback),
                vector.title,
                "title of \(label)"
            )
            XCTAssertEqual(RecipeTitle.note(caption: vector.caption), vector.note, "note of \(label)")
        }
    }

    func test_ruleSetsMatchTheVectorFile() throws {
        let file = try loadVectorFile()
        XCTAssertEqual(Set(file.abbreviations), RecipeTitle.abbreviations)
        XCTAssertEqual(file.abbreviations.count, 12)
        // Every entry is one Character, so none is dropped by the conversion.
        XCTAssertEqual(file.whitespace.filter { $0.count != 1 }, [])
        XCTAssertEqual(file.lineBreaks.filter { $0.count != 1 }, [])
        XCTAssertEqual(characters(file.whitespace), RecipeTitle.whitespace)
        XCTAssertEqual(characters(file.lineBreaks), RecipeTitle.lineBreaks)
    }
}

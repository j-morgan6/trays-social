@testable import TraysSocial
import XCTest

@MainActor
final class IngredientSearchTests: XCTestCase {
    /// Matches APIClient's decoder configuration (Services/APIClient.swift).
    private var decoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }

    private func postJSON(id: Int) -> String {
        """
        {"id": \(id), "type": "recipe", "caption": "Adobo", "cooking_time_minutes": 40,
         "servings": 4, "like_count": 0, "comment_count": 0, "liked_by_current_user": false,
         "bookmarked_by_current_user": false, "inserted_at": "2026-10-01T12:00:00Z",
         "user": {"id": 2, "username": "maria", "profile_photo_url": null},
         "photos": [], "ingredients": [], "cooking_steps": [], "tools": [], "tags": []}
        """
    }

    func test_decodesGroupedResults() throws {
        let json = """
        {"data": {"everything": [{"post": \(postJSON(id: 1)), "missing": [], "scope": "mine"}],
                  "almost": [{"post": \(postJSON(id: 2)), "missing": ["soy sauce"], "scope": "following"}]}}
        """
        let response = try decoder.decode(
            DataResponse<IngredientSearchResults>.self, from: Data(json.utf8)
        )
        XCTAssertEqual(response.data.everything.map(\.id), [1])
        XCTAssertEqual(response.data.almost.first?.missing, ["soy sauce"])
        XCTAssertEqual(response.data.almost.first?.scope, "following")
    }

    func test_addingTrimsLowercasesAndDedupes() {
        var chips = IngredientChips.adding("  Chicken ", to: [])
        chips = IngredientChips.adding("chicken", to: chips)
        chips = IngredientChips.adding("Rice", to: chips)
        XCTAssertEqual(chips, ["chicken", "rice"])
    }

    func test_addingIgnoresBlankAndCapsAtTen() {
        var chips = (1 ... 10).map { "item\($0)" }
        chips = IngredientChips.adding("eleven", to: chips)
        chips = IngredientChips.adding("   ", to: chips)
        XCTAssertEqual(chips.count, 10)
        XCTAssertFalse(chips.contains("eleven"))
        XCTAssertEqual(IngredientChips.adding("   ", to: []), [])
    }

    /// The server rejects a term over 50 characters with 422, which would
    /// silently fail the whole search, so the client clamps the chip.
    func test_addingClampsChipToServerTermLimit() {
        let chips = IngredientChips.adding(String(repeating: "a", count: 60), to: [])
        XCTAssertEqual(chips.first?.count, IngredientChips.maxTermLength)
    }

    func test_queryItemsUseBracketedHaveKey() {
        let items = IngredientChips.queryItems(for: ["chicken", "rice"])
        XCTAssertEqual(items.map(\.name), ["have[]", "have[]"])
        XCTAssertEqual(items.map(\.value), ["chicken", "rice"])
    }
}

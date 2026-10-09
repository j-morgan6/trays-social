@testable import TraysSocial
import XCTest

@MainActor
final class SearchQueryTests: XCTestCase {
    /// Matches APIClient's decoder configuration (Services/APIClient.swift).
    private var decoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }

    private func postJSON(id: Int) -> String {
        """
        {"id": \(id), "type": "recipe", "caption": "Tacos", "cooking_time_minutes": 30,
         "servings": 4, "like_count": 0, "comment_count": 0, "liked_by_current_user": false,
         "bookmarked_by_current_user": false, "inserted_at": "2026-10-01T12:00:00Z",
         "user": {"id": 2, "username": "maria", "profile_photo_url": null},
         "photos": [], "ingredients": [], "cooking_steps": [], "tools": [], "tags": []}
        """
    }

    func test_groupedQueryWithText() {
        let items = SearchQuery.grouped(text: "tacos", categoryKey: nil)
        XCTAssertEqual(items, [.init(name: "grouped", value: "true"), .init(name: "q", value: "tacos")])
    }

    func test_groupedQueryWithCategory() {
        let items = SearchQuery.grouped(text: "", categoryKey: "quick_dinners")
        XCTAssertEqual(items, [
            .init(name: "grouped", value: "true"),
            .init(name: "category", value: "quick_dinners"),
        ])
    }

    func test_groupPageQueryCarriesCursor() {
        let route = SearchGroupRoute(group: .everyone, query: "tacos", categoryKey: nil)
        let items = SearchQuery.groupPage(route, cursor: "abc")
        XCTAssertEqual(items, [
            .init(name: "group", value: "everyone"),
            .init(name: "q", value: "tacos"),
            .init(name: "cursor", value: "abc"),
        ])

        // A Browse tile's See all: category, no q.
        let categoryRoute = SearchGroupRoute(group: .tray, query: "", categoryKey: "quick_dinners")
        XCTAssertEqual(SearchQuery.groupPage(categoryRoute, cursor: "abc"), [
            .init(name: "group", value: "tray"),
            .init(name: "category", value: "quick_dinners"),
            .init(name: "cursor", value: "abc"),
        ])
    }

    func test_typingAfterSelectingCategoryDropsCategory() {
        let selected = BrowseCategory(key: "quick_dinners", label: "Quick dinners")
        XCTAssertNil(SearchQuery.category(afterTyping: "tacos", selected: selected))
        XCTAssertEqual(SearchQuery.category(afterTyping: "", selected: selected), selected)
        XCTAssertEqual(SearchQuery.category(afterTyping: "   ", selected: selected), selected)
    }

    func test_decodesGroupedResponse() throws {
        let json = """
        {"data": {"users": [], "tray": [\(postJSON(id: 1))], "following": [],
                  "everyone": [{"type": "post", "post": \(postJSON(id: 2))},
                               {"type": "ad", "ad": {"slot": 0, "placement": "find"}}]},
         "cursor": "c1", "ad_config": {"enabled": true, "frequency": 8}}
        """
        let response = try decoder.decode(
            AdAwarePaginatedResponse<GroupedSearchResults>.self, from: Data(json.utf8)
        )
        XCTAssertEqual(response.data.tray.map(\.id), [1])
        XCTAssertEqual(response.data.everyone.compactMap(\.post?.id), [2])
        XCTAssertEqual(response.data.everyone.count, 2)
        XCTAssertEqual(response.cursor, "c1")
    }

    func test_decodesBrowseAndLocalizesKnownKeys() throws {
        let json = """
        {"data": {"categories": [{"key": "quick_dinners", "label": "Quick dinners"},
                                 {"key": "new_thing", "label": "New thing"}],
                  "most_saved": [{"type": "post", "post": \(postJSON(id: 3))}]}}
        """
        let browse = try decoder.decode(AdAwarePaginatedResponse<BrowsePayload>.self, from: Data(json.utf8)).data
        XCTAssertEqual(browse.categories.map(\.key), ["quick_dinners", "new_thing"])
        XCTAssertEqual(browse.categories[0].displayLabel, String(localized: "Quick dinners"))
        XCTAssertEqual(browse.categories[1].displayLabel, "New thing")
        XCTAssertEqual(browse.mostSaved.compactMap(\.post?.id), [3])
    }
}

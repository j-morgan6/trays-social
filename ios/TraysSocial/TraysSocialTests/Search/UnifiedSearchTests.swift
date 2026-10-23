@testable import TraysSocial
import XCTest

/// W205: one search box. The chips plus the typed text decide whether the box
/// runs the normal (grouped) search or ingredient matching.
@MainActor
final class UnifiedSearchTests: XCTestCase {
    // MARK: - Routing

    func test_nothingIsIdle() {
        XCTAssertEqual(UnifiedSearch.route(chips: [], text: ""), .idle)
        XCTAssertEqual(UnifiedSearch.route(chips: [], text: "   "), .idle)
    }

    func test_oneTermRoutesToGroupedSearch() {
        XCTAssertEqual(UnifiedSearch.route(chips: [], text: " Chicken curry "), .term("Chicken curry"))
        XCTAssertEqual(UnifiedSearch.route(chips: ["chicken"], text: ""), .term("chicken"))
    }

    func test_twoChipsRouteToIngredientSearch() {
        XCTAssertEqual(
            UnifiedSearch.route(chips: ["chicken", "rice"], text: ""),
            .ingredients(["chicken", "rice"])
        )
    }

    func test_oneChipPlusTypedTextIsTwoIngredients() {
        XCTAssertEqual(UnifiedSearch.route(chips: ["chicken"], text: "rice"), .ingredients(["chicken", "rice"]))
    }

    func test_typedTextRepeatingAChipDoesNotCountTwice() {
        XCTAssertEqual(UnifiedSearch.route(chips: ["chicken"], text: "Chicken"), .term("chicken"))
    }

    func test_typedTextIsIgnoredOnceTheChipRowIsFull() {
        let chips = (1 ... IngredientChips.maxCount).map { "item\($0)" }
        XCTAssertEqual(UnifiedSearch.route(chips: chips, text: "eleven"), .ingredients(chips))
    }

    // MARK: - View model

    private struct Offline: Error {}

    private func emptyResults() throws -> IngredientSearchResults {
        try JSONDecoder().decode(IngredientSearchResults.self, from: Data(#"{"everything": [], "almost": []}"#.utf8))
    }

    private func makeViewModel(
        debounce: Duration = .zero,
        onFetch: @escaping ([String]) -> Void
    ) throws -> IngredientSearchViewModel {
        let defaults = UserDefaults(suiteName: "UnifiedSearchTests")!
        defaults.removePersistentDomain(forName: "UnifiedSearchTests")
        let results = try emptyResults()
        return IngredientSearchViewModel(
            preferences: SearchPreferences(defaults: defaults),
            debounce: debounce,
            fetch: { terms in
                onFetch(terms)
                return results
            }
        )
    }

    func test_oneTermHandsTheTermToGroupedSearchWithoutAnIngredientFetch() async throws {
        var calls: [[String]] = []
        let viewModel = try makeViewModel { calls.append($0) }

        viewModel.draft = "chicken"
        viewModel.draftChanged()
        await viewModel.waitForSearch()
        XCTAssertEqual(viewModel.searchTerm, "chicken")

        viewModel.submitDraft()
        await viewModel.waitForSearch()

        XCTAssertEqual(viewModel.chips, ["chicken"])
        XCTAssertEqual(viewModel.draft, "")
        XCTAssertEqual(viewModel.searchTerm, "chicken")
        XCTAssertFalse(viewModel.isMatchingIngredients)
        XCTAssertEqual(calls, [])
        XCTAssertNil(viewModel.results)
    }

    func test_twoChipsFetchIngredientMatches() async throws {
        var calls: [[String]] = []
        let viewModel = try makeViewModel { calls.append($0) }

        viewModel.addChip("chicken")
        viewModel.draft = "rice"
        viewModel.draftChanged()
        await viewModel.waitForSearch()

        XCTAssertTrue(viewModel.isMatchingIngredients)
        XCTAssertEqual(viewModel.searchTerm, "")
        XCTAssertEqual(calls, [["chicken", "rice"]])
        XCTAssertNotNil(viewModel.results)
    }

    /// Typing after one chip drives ingredient search from every keystroke;
    /// the debounce must coalesce them into one fetch for the final terms.
    func test_keystrokesAfterAChipCoalesceIntoOneFetch() async throws {
        var calls: [[String]] = []
        let viewModel = try makeViewModel(debounce: .milliseconds(50)) { calls.append($0) }
        viewModel.addChip("chicken")

        // Yielding between keystrokes lets each pending search start, so only
        // the debounce (not cancellation alone) keeps it from fetching.
        for text in ["r", "ri", "ric", "rice"] {
            viewModel.draft = text
            viewModel.draftChanged()
            await Task.yield()
        }
        await viewModel.waitForSearch()

        XCTAssertEqual(calls, [["chicken", "rice"]])
    }

    func test_removingBackToOneChipReturnsToGroupedSearch() async throws {
        var calls: [[String]] = []
        let viewModel = try makeViewModel { calls.append($0) }
        viewModel.addChip("chicken")
        viewModel.addChip("rice")
        await viewModel.waitForSearch()
        XCTAssertNotNil(viewModel.results)

        viewModel.removeChip("rice")
        await viewModel.waitForSearch()

        XCTAssertFalse(viewModel.isMatchingIngredients)
        XCTAssertEqual(viewModel.searchTerm, "chicken")
        XCTAssertNil(viewModel.results)
    }

    func test_clearEmptiesChipsDraftAndResults() async throws {
        let viewModel = try makeViewModel { _ in }
        viewModel.addChip("chicken")
        viewModel.addChip("rice")
        await viewModel.waitForSearch()

        viewModel.draft = "egg"
        viewModel.clear()

        XCTAssertEqual(viewModel.route, .idle)
        XCTAssertEqual(viewModel.chips, [])
        XCTAssertEqual(viewModel.draft, "")
        XCTAssertNil(viewModel.results)
    }

    func test_addedChipsAreRememberedAsRecent() throws {
        let viewModel = try makeViewModel { _ in }

        viewModel.addChip("chicken")
        viewModel.addChip("rice")

        XCTAssertEqual(viewModel.recentIngredients, ["rice", "chicken"])
    }
}

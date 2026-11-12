@testable import TraysSocial
import XCTest

/// W243: the pure copy and styling rules behind the restyled Search screen.
final class SearchFormattingTests: XCTestCase {
    private let english = Locale(identifier: "en_US")

    // MARK: - Ingredient summary

    func test_titleListsUpToThreeIngredients() {
        XCTAssertEqual(
            IngredientSummary.title(chips: ["chicken", "rice"], locale: english),
            "With chicken and rice, you can make…"
        )
        XCTAssertEqual(
            IngredientSummary.title(chips: ["chicken", "rice", "garlic"], locale: english),
            "With chicken, rice, and garlic, you can make…"
        )
    }

    func test_titleCountsPastThreeIngredients() {
        XCTAssertEqual(
            IngredientSummary.title(chips: ["a", "b", "c", "d"], locale: english),
            "With your 4 ingredients"
        )
    }

    func test_subtitleCountsReadyAndAlmost() {
        XCTAssertEqual(IngredientSummary.subtitle(ready: 2, almost: 3), "2 ready now · 3 almost there")
    }

    func test_subtitleSaysNothingCompleteWhenNoneAreReady() {
        XCTAssertEqual(IngredientSummary.subtitle(ready: 0, almost: 1), "Nothing complete yet · 1 almost there")
    }

    // MARK: - Uses line

    func test_usesListsTheChipsTheRecipeContains() {
        let ingredients = [
            Ingredient(name: "Chicken thighs", quantity: "6", unit: nil),
            Ingredient(name: "Jasmine rice", quantity: "1", unit: "cup"),
        ]
        XCTAssertEqual(
            IngredientUses.line(chips: ["chicken", "rice", "lemon"], in: ingredients),
            "Uses chicken, rice"
        )
    }

    func test_usesIsNilWhenNoChipMatches() {
        let ingredients = [Ingredient(name: "Lemon", quantity: nil, unit: nil)]
        XCTAssertNil(IngredientUses.line(chips: ["chicken"], in: ingredients))
    }

    // MARK: - Category tile fills

    func test_tileFillsCycleCreamAmberMint() {
        let fills = (0 ..< 6).map(CategoryTileFill.at)
        XCTAssertEqual(fills, [.cream, .amber, .mint, .cream, .amber, .mint])
    }

    // MARK: - Most saved ranks

    func test_onlyTheFirstThreePostsAreRanked() {
        let ranks = MostSavedRank.ranks(postIDs: [40, 41, 42, 43])
        XCTAssertEqual(ranks, [40: 1, 41: 2, 42: 3])
        XCTAssertNil(ranks[43])
    }

    // MARK: - Browse failure

    func test_browseFailsOnlyAfterAFinishedEmptyLoad() {
        XCTAssertTrue(SearchBrowseState.failed(attempted: true, hasBrowse: false, isLoading: false))
        XCTAssertFalse(SearchBrowseState.failed(attempted: false, hasBrowse: false, isLoading: false))
        XCTAssertFalse(SearchBrowseState.failed(attempted: true, hasBrowse: true, isLoading: false))
    }

    func test_retryInFlightShowsLoadingNotTheError() {
        XCTAssertFalse(SearchBrowseState.failed(attempted: true, hasBrowse: false, isLoading: true))
    }
}

@testable import TraysSocial
import XCTest

/// W245: which state My Tray, a collection and a profile show, and the
/// counted copy on those screens.
final class MyTrayStateTests: XCTestCase {
    func test_contentWinsOverLoadingAndFailure() {
        XCTAssertEqual(
            ContentLoadState.decide(hasContent: true, hasLoaded: true, isLoading: true, loadFailed: true),
            .content
        )
    }

    func test_beforeTheFirstLoadFinishesShowsLoading() {
        XCTAssertEqual(
            ContentLoadState.decide(hasContent: false, hasLoaded: false, isLoading: false, loadFailed: false),
            .loading
        )
    }

    func test_failedLoadShowsError() {
        XCTAssertEqual(
            ContentLoadState.decide(hasContent: false, hasLoaded: true, isLoading: false, loadFailed: true),
            .error
        )
    }

    func test_retryInFlightShowsLoadingNotError() {
        XCTAssertEqual(
            ContentLoadState.decide(hasContent: false, hasLoaded: true, isLoading: true, loadFailed: true),
            .loading
        )
    }

    func test_finishedLoadWithNothingIsEmpty() {
        XCTAssertEqual(
            ContentLoadState.decide(hasContent: false, hasLoaded: true, isLoading: false, loadFailed: false),
            .empty
        )
    }

    func test_headerSubtitleCountsBothLists() {
        XCTAssertEqual(
            MyTrayCopy.headerSubtitle(recipes: 7, saved: 8),
            [String(localized: "7 recipes"), String(localized: "8 saved")].joined(separator: " · ")
        )
        XCTAssertEqual(
            MyTrayCopy.headerSubtitle(recipes: 1, saved: 0),
            [String(localized: "1 recipe"), String(localized: "0 saved")].joined(separator: " · ")
        )
    }

    func test_headerSubtitleForAnEmptyTrayIsTheNewUserLine() {
        XCTAssertEqual(
            MyTrayCopy.headerSubtitle(recipes: 0, saved: 0),
            String(localized: "Recipes you post and save live here.")
        )
    }

    func test_collectionSubtitleNeedsAFullCount() {
        let privacy = String(localized: "Only you can see this")
        XCTAssertEqual(MyTrayCopy.collectionSubtitle(count: nil), privacy)
        XCTAssertEqual(
            MyTrayCopy.collectionSubtitle(count: 18),
            [String(localized: "18 recipes"), privacy].joined(separator: " · ")
        )
        XCTAssertEqual(
            MyTrayCopy.collectionSubtitle(count: 0),
            [String(localized: "No recipes yet"), privacy].joined(separator: " · ")
        )
    }

    func test_planSummaryCoversNoneSomeAndAll() {
        XCTAssertEqual(
            MyTrayCopy.planSummary(plannedDays: 0, totalDays: 7),
            String(localized: "Nothing planned yet. Pick a dinner for each day.")
        )
        XCTAssertEqual(
            MyTrayCopy.planSummary(plannedDays: 3, totalDays: 7),
            String(localized: "3 of 7 dinners planned.")
        )
        XCTAssertEqual(
            MyTrayCopy.planSummary(plannedDays: 7, totalDays: 7),
            String(localized: "Every dinner this week is planned.")
        )
    }

    func test_missingCollectionSaysItIsGoneWithNoRetry() {
        let copy = CollectionLoadErrorCopy.decide(notFound: true)
        XCTAssertEqual(copy.title, "This collection is gone.")
        XCTAssertEqual(copy.subtitle, "It may have been deleted.")
        XCTAssertFalse(copy.allowsRetry)
    }

    func test_otherCollectionFailuresOfferRetry() {
        let copy = CollectionLoadErrorCopy.decide(notFound: false)
        XCTAssertEqual(copy.title, "Couldn't load this collection")
        XCTAssertTrue(copy.allowsRetry)
    }
}

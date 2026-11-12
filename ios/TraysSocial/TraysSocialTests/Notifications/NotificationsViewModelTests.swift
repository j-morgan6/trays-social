@testable import TraysSocial
import XCTest

/// W253: the load-failure state behind the restyled notifications screen.
///
/// Drives the failure seams directly rather than `load()`: `APIClient` is a
/// hardcoded singleton with no protocol seam (see MealPlannerViewModelTests).
@MainActor
final class NotificationsViewModelTests: XCTestCase {
    func test_aFailedRead_flagsTheLoadFailure() {
        let viewModel = NotificationsViewModel()

        viewModel.recordLoadFailure(URLError(.notConnectedToInternet))

        XCTAssertTrue(viewModel.loadFailed)
    }

    func test_aCancelledRead_isNotAFailure() {
        let viewModel = NotificationsViewModel()

        viewModel.recordLoadFailure(CancellationError())

        XCTAssertFalse(viewModel.loadFailed)
    }

    func test_beforeAnyLoadFinishes_theScreenShowsLoadingNotEmpty() {
        let viewModel = NotificationsViewModel()

        XCTAssertEqual(state(of: viewModel), .loading)
    }

    func test_aFinishedFailedLoad_showsTheErrorBlock() {
        let viewModel = NotificationsViewModel()

        viewModel.recordLoadFailure(URLError(.timedOut))
        viewModel.finishLoad()

        XCTAssertTrue(viewModel.hasLoaded)
        XCTAssertFalse(viewModel.isLoading)
        XCTAssertEqual(state(of: viewModel), .error)
    }

    func test_aFinishedLoadWithNothing_showsTheEmptyBlock() {
        let viewModel = NotificationsViewModel()

        viewModel.finishLoad()

        XCTAssertEqual(state(of: viewModel), .empty)
    }

    /// The same decision `NotificationsView.content` makes.
    private func state(of viewModel: NotificationsViewModel) -> ContentLoadState {
        ContentLoadState.decide(
            hasContent: !viewModel.notifications.isEmpty,
            hasLoaded: viewModel.hasLoaded,
            isLoading: viewModel.isLoading,
            loadFailed: viewModel.loadFailed
        )
    }
}

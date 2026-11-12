@testable import TraysSocial
import XCTest

/// W247: Cook mode's stepping rules.
final class CookProgressTests: XCTestCase {
    func test_startsOnStepOneOfN() {
        let progress = CookProgress(stepCount: 4)
        XCTAssertEqual(progress.stepNumber, 1)
        XCTAssertTrue(progress.isFirstStep)
        XCTAssertFalse(progress.canGoBack)
        XCTAssertEqual(progress.segments, [.current, .upcoming, .upcoming, .upcoming])
    }

    func test_nextMovesOneStepAndFillsTheSegmentsBehind() {
        var progress = CookProgress(stepCount: 4)
        progress.advance()
        progress.advance()
        XCTAssertEqual(progress.current, 2)
        XCTAssertEqual(progress.stepNumber, 3)
        XCTAssertEqual(progress.segments, [.done, .done, .current, .upcoming])
        XCTAssertFalse(progress.isComplete)
    }

    func test_doneOnTheLastStepCompletesAndFillsEverySegment() {
        var progress = CookProgress(stepCount: 2, current: 1)
        XCTAssertTrue(progress.isLastStep)
        progress.advance()
        XCTAssertTrue(progress.isComplete)
        XCTAssertEqual(progress.current, 1)
        XCTAssertEqual(progress.segments, [.done, .done])
    }

    func test_backStopsAtTheFirstStep() {
        var progress = CookProgress(stepCount: 3, current: 1)
        progress.goBack()
        progress.goBack()
        XCTAssertEqual(progress.current, 0)
    }

    func test_swipeForwardStopsOnTheLastStepWithoutCompleting() {
        var progress = CookProgress(stepCount: 2)
        progress.swipeForward()
        progress.swipeForward()
        XCTAssertEqual(progress.current, 1)
        XCTAssertFalse(progress.isComplete)
    }

    func test_nothingMovesOnceComplete() {
        var progress = CookProgress(stepCount: 3, current: 2, isComplete: true)
        progress.goBack()
        progress.swipeForward()
        progress.advance()
        XCTAssertEqual(progress.current, 2)
        XCTAssertTrue(progress.isComplete)
        XCTAssertFalse(progress.canGoBack)
    }

    func test_aRecipeWithNoStepsHasNoSegmentsAndNeverCompletes() {
        var progress = CookProgress(stepCount: 0)
        progress.advance()
        XCTAssertEqual(progress.segments, [])
        XCTAssertEqual(progress.stepNumber, 0)
        XCTAssertFalse(progress.isComplete)
    }

    func test_aStartingStepPastTheEndIsClampedToTheLastStep() {
        let progress = CookProgress(stepCount: 3, current: 9)
        XCTAssertEqual(progress.current, 2)
    }

    /// Components token map: amber for done and current segments, a strong
    /// hairline for the steps still to come.
    @MainActor
    func test_segmentsAreAmberThroughTheCurrentStepAndHairlineAfter() {
        XCTAssertEqual(CookProgressSegments.fill(for: .done), Theme.accent)
        XCTAssertEqual(CookProgressSegments.fill(for: .current), Theme.accent)
        XCTAssertEqual(CookProgressSegments.fill(for: .upcoming), Theme.hairlineStrong)
    }
}

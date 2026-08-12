@testable import TraysSocial
import XCTest

/// Paywall routing: write-failure outcomes, the locked-plan intent, and the My Tray entry gate.
///
/// Pure state-transition tests, matching every other ViewModel test in this
/// project: `APIClient` is a hardcoded actor singleton with no protocol seam
/// and the team has deliberately not mocked it, so these drive the optimistic
/// apply / confirm / rollback seams directly rather than through the network.
/// Driving a public write method here would spawn a real request whose failure
/// toasts on a bus shared with every other test in the process.
///
/// Fixtures live in `PlannerFixtures` — this file was split off
/// `MealPlannerViewModelTests` when that grew past the project's 400-line limit.
@MainActor
final class MealPlannerIntentTests: XCTestCase {
    // MARK: - 403 -> paywall

    func test_writeOutcome_subscriptionRequired_presentsPaywall() {
        XCTAssertEqual(
            MealPlanWriteOutcome.decide(for: APIError.subscriptionRequired(message: "nope")),
            .presentPaywall
        )
    }

    /// The recipe is neither owned nor bookmarked. A paywall here would sell a
    /// subscription that does not fix the problem.
    func test_writeOutcome_bareForbidden_toasts() {
        XCTAssertEqual(MealPlanWriteOutcome.decide(for: APIError.forbidden), .toast)
    }

    func test_writeOutcome_networkError_toasts() {
        XCTAssertEqual(MealPlanWriteOutcome.decide(for: URLError(.notConnectedToInternet)), .toast)
    }

    func test_handleWriteFailure_subscriptionRequired_setsNeedsPaywall_andTakesOnlyThatBranch() {
        let viewModel = PlannerFixtures.makeViewModel()

        let outcome = viewModel.handleWriteFailure(
            APIError.subscriptionRequired(message: "nope"), operation: "add", toast: .mealPlanAddFailed
        )

        XCTAssertEqual(outcome, .presentPaywall)
        XCTAssertTrue(viewModel.needsPaywall)
    }

    func test_handleWriteFailure_otherError_leavesNeedsPaywallFalse() {
        let viewModel = PlannerFixtures.makeViewModel()

        let outcome = viewModel.handleWriteFailure(
            APIError.forbidden, operation: "add", toast: .mealPlanAddFailed
        )

        XCTAssertEqual(outcome, .toast)
        XCTAssertFalse(viewModel.needsPaywall)
    }

    /// The optimistic card must be gone before the paywall covers it, or it is
    /// still sitting there when the sheet dismisses.
    func test_gatedAddFailure_rollsBackTheCardAndPresentsPaywall() {
        let viewModel = PlannerFixtures.makeViewModel()
        let pendingID = viewModel.beginAdd(PlannerFixtures.post(id: 10), on: viewModel.days[0]).pendingID

        viewModel.rollbackAdd(pendingID: pendingID ?? 0)
        viewModel.handleWriteFailure(
            APIError.subscriptionRequired(message: "nope"), operation: "add", toast: .mealPlanAddFailed
        )

        XCTAssertTrue(viewModel.entries.isEmpty)
        XCTAssertTrue(viewModel.needsPaywall)
    }

    // MARK: - Locked intent

    /// The mid-session lapse: `PlusGate` passed on cached entitlement, only the
    /// server knew the subscription had ended. Nothing else can remember the
    /// pick, so without this hand-off the user subscribes and watches it vanish.
    func test_gatedAddFailure_remembersDayAndRecipe_andOpensThePaywall() {
        let viewModel = PlannerFixtures.makeViewModel()
        let day = viewModel.days[3]

        let outcome = viewModel.handleAddFailure(
            APIError.subscriptionRequired(message: "nope"), post: PlannerFixtures.post(id: 10), on: day
        )

        XCTAssertEqual(outcome, .presentPaywall)
        XCTAssertTrue(viewModel.needsPaywall)
        XCTAssertEqual(viewModel.pendingPlan?.dayKey, day.key)
        XCTAssertEqual(viewModel.pendingPlan?.post.id, 10)
    }

    /// A toast-worthy failure must NOT leave an intent behind: nothing will
    /// consume it, and the next unrelated unlock would plan a recipe nobody
    /// asked for.
    func test_nonGatedAddFailure_remembersNothing() {
        let viewModel = PlannerFixtures.makeViewModel()

        let outcome = viewModel.handleAddFailure(
            APIError.forbidden, post: PlannerFixtures.post(id: 10), on: viewModel.days[0]
        )

        XCTAssertEqual(outcome, .toast)
        XCTAssertNil(viewModel.pendingPlan)
        XCTAssertFalse(viewModel.needsPaywall)
    }

    /// The whole point of the intent: after the paywall unlocks, the pick the
    /// user already made lands on the day they chose.
    func test_replayPendingPlan_afterUnlock_targetsTheRememberedDay() {
        let viewModel = PlannerFixtures.makeViewModel()
        let day = viewModel.days[3]
        viewModel.handleAddFailure(
            APIError.subscriptionRequired(message: "nope"), post: PlannerFixtures.post(id: 10), on: day
        )

        XCTAssertTrue(viewModel.replayPendingPlan())
        XCTAssertEqual(viewModel.entries(on: day).map(\.post.id), [10])
        XCTAssertNil(viewModel.pendingPlan)
    }

    /// A replayed add must not re-arm the intent. If the server keeps refusing
    /// while `/auth/me` still says subscriber, re-arming would make the paywall
    /// replay, fail, and re-present with no exit but leaving the screen.
    func test_replayedAddFailure_doesNotReArmTheIntent() {
        let viewModel = PlannerFixtures.makeViewModel()
        let day = viewModel.days[0]

        viewModel.handleAddFailure(
            APIError.subscriptionRequired(message: "still lapsed"),
            post: PlannerFixtures.post(id: 10), on: day, rearm: false
        )

        XCTAssertTrue(viewModel.needsPaywall, "the failure still surfaces")
        XCTAssertNil(viewModel.pendingPlan, "but the intent must not come back")
        XCTAssertFalse(viewModel.replayPendingPlan())
    }

    func test_consumePendingPlan_clearsTheIntent() {
        let viewModel = PlannerFixtures.makeViewModel()
        viewModel.handleAddFailure(
            APIError.subscriptionRequired(message: "n"), post: PlannerFixtures.post(id: 10), on: viewModel.days[0]
        )

        XCTAssertNotNil(viewModel.consumePendingPlan())
        XCTAssertNil(viewModel.pendingPlan)
        XCTAssertNil(viewModel.consumePendingPlan())
    }

    /// Planning onto a day that is no longer on screen is worse than doing
    /// nothing.
    func test_replayPendingPlan_afterTheWeekChanged_dropsTheIntent() {
        let viewModel = PlannerFixtures.makeViewModel()
        viewModel.handleAddFailure(
            APIError.subscriptionRequired(message: "n"), post: PlannerFixtures.post(id: 10), on: viewModel.days[0]
        )
        viewModel.setWeek(viewModel.week.next, today: PlannerFixtures.today)

        XCTAssertFalse(viewModel.replayPendingPlan())
        XCTAssertNil(viewModel.pendingPlan)
        XCTAssertTrue(viewModel.entries.isEmpty)
    }

    func test_cancelPendingPlan_dropsTheIntent() {
        let viewModel = PlannerFixtures.makeViewModel()
        viewModel.handleAddFailure(
            APIError.subscriptionRequired(message: "n"), post: PlannerFixtures.post(id: 10), on: viewModel.days[0]
        )

        viewModel.cancelPendingPlan()

        XCTAssertNil(viewModel.pendingPlan)
        XCTAssertFalse(viewModel.replayPendingPlan())
    }

    // MARK: - Entry-mode gate (AC 1 vs AC 5)

    func test_plannerEntry_subscriber_opensDirectly() {
        XCTAssertEqual(PlannerEntryMode.decide(isPlus: true, hasPlan: false), .open)
    }

    func test_plannerEntry_freeUserWithNoPlan_isGated() {
        XCTAssertEqual(PlannerEntryMode.decide(isPlus: false, hasPlan: false), .gated)
    }

    /// The AC-5 linchpin: a lapsed subscriber's existing plan must stay
    /// readable, not be stranded behind the paywall.
    func test_plannerEntry_lapsedSubscriberWithAPlan_opensDirectly() {
        XCTAssertEqual(PlannerEntryMode.decide(isPlus: false, hasPlan: true), .open)
    }
}

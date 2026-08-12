@testable import TraysSocial
import XCTest

/// Week state, entry add/remove, and the edge cases from the task brief.
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
final class MealPlannerViewModelTests: XCTestCase {
    // MARK: - Week state

    func test_freshViewModel_hasSevenEmptyDays() {
        let viewModel = PlannerFixtures.makeViewModel()

        XCTAssertEqual(viewModel.days.count, 7)
        XCTAssertFalse(viewModel.hasAnyEntries)
        XCTAssertTrue(viewModel.days.allSatisfy { viewModel.entries(on: $0).isEmpty })
    }

    func test_setWeek_sendsTheMondayOnTheWire() {
        let viewModel = PlannerFixtures.makeViewModel()

        XCTAssertEqual(viewModel.week.wireKey, "2026-03-02")
        XCTAssertEqual(viewModel.canonicalWeekStart, "2026-03-02")
    }

    /// The integration form of `PlannerWeekTests`' locale guard: a user whose
    /// device starts weeks on Sunday, opening the planner on a Sunday, must
    /// still key the week to the preceding Monday.
    func test_sundayWeekStartLocale_stillKeysTheWeekToMonday() {
        let viewModel = MealPlannerViewModel(
            week: .containing(PlannerFixtures.date("2026-03-08")),
            today: PlannerFixtures.date("2026-03-08")
        )

        XCTAssertEqual(viewModel.week.wireKey, "2026-03-02")
    }

    func test_goToNextWeek_advancesTheWeekAndClearsBothLists() {
        let viewModel = PlannerFixtures.makeViewModel()
        viewModel.entries = [PlannerFixtures.entry(id: 1, date: "2026-03-02", postID: 10)]
        viewModel.groceryGroups = [PlannerFixtures.group(postID: 10, keys: ["10:1"])]

        viewModel.setWeek(viewModel.week.next, today: PlannerFixtures.today)

        XCTAssertEqual(viewModel.week.wireKey, "2026-03-09")
        XCTAssertTrue(viewModel.entries.isEmpty)
        XCTAssertTrue(viewModel.groceryGroups.isEmpty)
        XCTAssertEqual(viewModel.days.first?.key, "2026-03-09")
    }

    func test_weekNavigation_bumpsTheGeneration_soAnInFlightResponseIsDropped() {
        let viewModel = PlannerFixtures.makeViewModel()
        let stale = viewModel.weekGeneration

        viewModel.setWeek(viewModel.week.next, today: PlannerFixtures.today)
        viewModel.applyWeek(
            MealPlanWeekPayload(
                weekStart: "2026-03-02",
                entries: [PlannerFixtures.entry(id: 1, date: "2026-03-02", postID: 10)]
            ),
            generation: stale
        )

        XCTAssertTrue(viewModel.entries.isEmpty, "a response for the previous week must be dropped")
        XCTAssertEqual(viewModel.canonicalWeekStart, "2026-03-09")
    }

    func test_applyWeek_adoptsTheServersEchoedWeekStart() {
        let viewModel = PlannerFixtures.makeViewModel()

        viewModel.applyWeek(
            MealPlanWeekPayload(weekStart: "2026-03-02", entries: []),
            generation: viewModel.weekGeneration
        )

        XCTAssertEqual(viewModel.canonicalWeekStart, viewModel.week.wireKey)
    }

    func test_weekRangeLabel_readsThisWeekForTheCurrentWeek() {
        let viewModel = MealPlannerViewModel(week: .containing(PlannerFixtures.today), today: PlannerFixtures.today)

        XCTAssertEqual(viewModel.weekRangeLabel, String(localized: "This week"))
    }

    func test_weekRangeLabel_showsARangeForAnotherWeek() {
        let viewModel = PlannerFixtures.makeViewModel()
        viewModel.setWeek(viewModel.week.next, today: PlannerFixtures.today)

        XCTAssertNotEqual(viewModel.weekRangeLabel, String(localized: "This week"))
        XCTAssertFalse(viewModel.weekRangeLabel.isEmpty)
    }

    // MARK: - Add: optimistic + rollback

    func test_beginAdd_insertsPendingEntryOnTheTargetDay_withNegativeID() {
        let viewModel = PlannerFixtures.makeViewModel()
        let day = viewModel.days[2]

        let result = viewModel.beginAdd(PlannerFixtures.post(id: 10), on: day)

        XCTAssertEqual(result.validation, .valid)
        XCTAssertEqual(result.pendingID, -1)
        XCTAssertEqual(viewModel.entries(on: day).map(\.post.id), [10])
        XCTAssertTrue(viewModel.entries(on: day)[0].isPending)
    }

    func test_beginAdd_assignsDecreasingPendingIDs() {
        let viewModel = PlannerFixtures.makeViewModel()

        let first = viewModel.beginAdd(PlannerFixtures.post(id: 10), on: viewModel.days[0])
        let second = viewModel.beginAdd(PlannerFixtures.post(id: 11), on: viewModel.days[0])

        XCTAssertEqual(first.pendingID, -1)
        XCTAssertEqual(second.pendingID, -2)
    }

    /// Mirrors `unique_index(:meal_plan_entries, [:user_id, :date, :post_id])`.
    /// Catching it here means no optimistic card appears and then vanishes on
    /// the 422.
    func test_beginAdd_sameRecipeTwiceOnOneDay_isRefusedAsDuplicate() {
        let viewModel = PlannerFixtures.makeViewModel()
        let day = viewModel.days[0]
        viewModel.beginAdd(PlannerFixtures.post(id: 10), on: day)

        let second = viewModel.beginAdd(PlannerFixtures.post(id: 10), on: day)

        XCTAssertEqual(second.validation, .duplicate)
        XCTAssertNil(second.pendingID)
        XCTAssertEqual(viewModel.entries(on: day).count, 1)
    }

    func test_beginAdd_sameRecipeOnTwoDifferentDays_isAllowed() {
        let viewModel = PlannerFixtures.makeViewModel()
        viewModel.beginAdd(PlannerFixtures.post(id: 10), on: viewModel.days[0])

        let second = viewModel.beginAdd(PlannerFixtures.post(id: 10), on: viewModel.days[1])

        XCTAssertEqual(second.validation, .valid)
        XCTAssertEqual(viewModel.entries.count, 2)
    }

    func test_beginAdd_outsideTheDisplayedWeek_isRefused() {
        let viewModel = PlannerFixtures.makeViewModel()
        let foreign = PlannerWeek.containing(PlannerFixtures.date("2026-04-06"))
            .days(today: PlannerFixtures.today)[0]

        let result = viewModel.beginAdd(PlannerFixtures.post(id: 10), on: foreign)

        XCTAssertEqual(result.validation, .outsideWeek)
        XCTAssertTrue(viewModel.entries.isEmpty)
    }

    func test_confirmAdd_replacesThePendingEntryInPlace_withTheServerIDAndDate() {
        let viewModel = PlannerFixtures.makeViewModel()
        let day = viewModel.days[0]
        let pendingID = viewModel.beginAdd(PlannerFixtures.post(id: 10), on: day).pendingID

        viewModel.confirmAdd(
            pendingID: pendingID ?? 0,
            with: PlannerFixtures.entry(id: 77, date: day.key, postID: 10)
        )

        XCTAssertEqual(viewModel.entries.count, 1, "confirm replaces, never appends")
        XCTAssertEqual(viewModel.entries[0].id, 77)
        XCTAssertFalse(viewModel.entries[0].isPending)
        XCTAssertTrue(viewModel.groceryIsStale)
    }

    func test_confirmAdd_afterAWeekChange_isANoop() {
        let viewModel = PlannerFixtures.makeViewModel()
        let pendingID = viewModel.beginAdd(PlannerFixtures.post(id: 10), on: viewModel.days[0]).pendingID
        viewModel.setWeek(viewModel.week.next, today: PlannerFixtures.today)

        viewModel.confirmAdd(
            pendingID: pendingID ?? 0,
            with: PlannerFixtures.entry(id: 77, date: "2026-03-02", postID: 10)
        )

        XCTAssertTrue(viewModel.entries.isEmpty)
    }

    func test_rollbackAdd_removesOnlyThePendingEntry_leavingOthers() {
        let viewModel = PlannerFixtures.makeViewModel()
        let day = viewModel.days[0]
        viewModel.entries = [PlannerFixtures.entry(id: 5, date: day.key, postID: 99)]
        let pendingID = viewModel.beginAdd(PlannerFixtures.post(id: 10), on: day).pendingID

        viewModel.rollbackAdd(pendingID: pendingID ?? 0)

        XCTAssertEqual(viewModel.entries.map(\.id), [5])
    }

    // MARK: - Remove: optimistic + rollback

    func test_beginRemove_removesTheCardImmediately() {
        let viewModel = PlannerFixtures.makeViewModel()
        viewModel.entries = [PlannerFixtures.entry(id: 5, date: "2026-03-02", postID: 10)]

        XCTAssertTrue(viewModel.beginRemove(id: 5))
        XCTAssertTrue(viewModel.entries.isEmpty)
    }

    func test_beginRemove_ofAnUnknownEntry_isRefused() {
        let viewModel = PlannerFixtures.makeViewModel()

        XCTAssertFalse(viewModel.beginRemove(id: 5))
    }

    /// There is no server row to `DELETE /meal-plan/entries/-1`.
    func test_beginRemove_ofAPendingEntry_isRefused() {
        let viewModel = PlannerFixtures.makeViewModel()
        let pendingID = viewModel.beginAdd(PlannerFixtures.post(id: 10), on: viewModel.days[0]).pendingID

        XCTAssertFalse(viewModel.beginRemove(id: pendingID ?? 0))
        XCTAssertEqual(viewModel.entries.count, 1)
    }

    func test_rollbackRemove_reinsertsAtTheOriginalIndex() {
        let viewModel = PlannerFixtures.makeViewModel()
        viewModel.entries = [
            PlannerFixtures.entry(id: 1, date: "2026-03-02", postID: 10),
            PlannerFixtures.entry(id: 2, date: "2026-03-03", postID: 11),
            PlannerFixtures.entry(id: 3, date: "2026-03-04", postID: 12),
        ]
        viewModel.beginRemove(id: 2)

        viewModel.rollbackRemove(id: 2)

        XCTAssertEqual(viewModel.entries.map(\.id), [1, 2, 3])
    }

    func test_rollbackRemove_clampsWhenTheListShrank() {
        let viewModel = PlannerFixtures.makeViewModel()
        viewModel.entries = [
            PlannerFixtures.entry(id: 1, date: "2026-03-02", postID: 10),
            PlannerFixtures.entry(id: 2, date: "2026-03-03", postID: 11),
        ]
        viewModel.beginRemove(id: 2)
        viewModel.entries = []

        viewModel.rollbackRemove(id: 2)

        XCTAssertEqual(viewModel.entries.map(\.id), [2])
    }

    func test_confirmRemove_thenRollback_isANoop() {
        let viewModel = PlannerFixtures.makeViewModel()
        viewModel.entries = [PlannerFixtures.entry(id: 1, date: "2026-03-02", postID: 10)]
        viewModel.beginRemove(id: 1)
        viewModel.confirmRemove(id: 1)

        viewModel.rollbackRemove(id: 1)

        XCTAssertTrue(viewModel.entries.isEmpty)
        XCTAssertTrue(viewModel.groceryIsStale)
    }

    // MARK: - Edge cases

    func test_emptyWeek_hasSevenDaysAndNoEntries() {
        let viewModel = PlannerFixtures.makeViewModel()

        viewModel.applyWeek(
            MealPlanWeekPayload(weekStart: "2026-03-02", entries: []),
            generation: viewModel.weekGeneration
        )

        XCTAssertEqual(viewModel.days.count, 7)
        XCTAssertFalse(viewModel.hasAnyEntries)
    }

    /// A planned recipe with no ingredient lines gets its own empty state — the
    /// generic "plan a recipe" copy would be wrong, since they already did.
    func test_recipeWithNoIngredients_isPlannedButAbsentFromTheGroceryList() {
        let viewModel = PlannerFixtures.makeViewModel()
        viewModel.entries = [PlannerFixtures.entry(id: 1, date: "2026-03-02", postID: 10)]

        viewModel.applyGrocery(
            GroceryListPayload(weekStart: "2026-03-02", recipes: [PlannerFixtures.group(postID: 10, keys: [])]),
            generation: viewModel.weekGeneration
        )

        XCTAssertTrue(viewModel.hasAnyEntries)
        XCTAssertFalse(viewModel.groceryGroups.isEmpty)
        XCTAssertFalse(viewModel.hasGroceryItems)
    }

    /// The server keeps an entry whose recipe was later unbookmarked, so the
    /// plan row survives a refetch. Only a *new* add would be refused.
    func test_recipeUnbookmarkedAfterPlanning_staysInTheWeek() {
        let viewModel = PlannerFixtures.makeViewModel()

        viewModel.applyWeek(
            MealPlanWeekPayload(
                weekStart: "2026-03-02",
                entries: [PlannerFixtures.entry(id: 1, date: "2026-03-02", postID: 10)]
            ),
            generation: viewModel.weekGeneration
        )

        XCTAssertEqual(viewModel.entries.map(\.post.id), [10])
    }

    func test_postDeletedServerSide_disappearsOnRefetch() {
        let viewModel = PlannerFixtures.makeViewModel()
        viewModel.entries = [PlannerFixtures.entry(id: 1, date: "2026-03-02", postID: 10)]

        viewModel.applyWeek(
            MealPlanWeekPayload(weekStart: "2026-03-02", entries: []),
            generation: viewModel.weekGeneration
        )

        XCTAssertTrue(viewModel.entries.isEmpty)
    }
}

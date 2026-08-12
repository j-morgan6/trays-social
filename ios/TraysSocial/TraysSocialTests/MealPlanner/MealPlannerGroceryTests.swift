@testable import TraysSocial
import XCTest

/// The derived grocery checklist: check toggles, staleness, and refetch races.
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
final class MealPlannerGroceryTests: XCTestCase {
    // MARK: - Grocery checks: optimistic + rollback

    func test_beginToggleCheck_flipsTheItem_andReturnsThePreviousValue() {
        let viewModel = PlannerFixtures.makeViewModel()
        viewModel.groceryGroups = [PlannerFixtures.group(postID: 10, keys: ["10:1", "10:2"])]

        let previous = viewModel.beginToggleCheck(itemKey: "10:1", to: true)

        XCTAssertEqual(previous, false)
        XCTAssertTrue(PlannerFixtures.checked(viewModel, "10:1") ?? false)
    }

    func test_rollbackToggleCheck_restoresThePreviousValue() {
        let viewModel = PlannerFixtures.makeViewModel()
        viewModel.groceryGroups = [PlannerFixtures.group(postID: 10, keys: ["10:1"])]
        let previous = viewModel.beginToggleCheck(itemKey: "10:1", to: true)

        viewModel.rollbackCheck(itemKey: "10:1", to: previous ?? false)

        XCTAssertEqual(PlannerFixtures.checked(viewModel, "10:1"), false)
    }

    func test_beginToggleCheck_unknownItemKey_returnsNil_andChangesNothing() {
        let viewModel = PlannerFixtures.makeViewModel()
        viewModel.groceryGroups = [PlannerFixtures.group(postID: 10, keys: ["10:1"])]

        XCTAssertNil(viewModel.beginToggleCheck(itemKey: "99:9", to: true))
        XCTAssertEqual(PlannerFixtures.checked(viewModel, "10:1"), false)
    }

    /// Two recipes can both list "salt" — only the tapped key may flip.
    func test_toggleCheck_affectsOnlyTheMatchingItemKey() {
        let viewModel = PlannerFixtures.makeViewModel()
        viewModel.groceryGroups = [
            PlannerFixtures.group(postID: 10, keys: ["10:1"]),
            PlannerFixtures.group(postID: 11, keys: ["11:1"]),
        ]

        viewModel.beginToggleCheck(itemKey: "10:1", to: true)

        XCTAssertEqual(PlannerFixtures.checked(viewModel, "10:1"), true)
        XCTAssertEqual(PlannerFixtures.checked(viewModel, "11:1"), false)
    }

    func test_checkedState_survivesARefetch() {
        let viewModel = PlannerFixtures.makeViewModel()

        viewModel.applyGrocery(
            GroceryListPayload(weekStart: "2026-03-02", recipes: [
                PlannerFixtures.group(postID: 10, keys: ["10:1"], checked: true),
            ]),
            generation: viewModel.weekGeneration
        )

        XCTAssertEqual(PlannerFixtures.checked(viewModel, "10:1"), true)
    }

    /// A refetch landing between the optimistic flip and the write completing
    /// must not repaint the box at its pre-toggle value.
    func test_inFlightCheck_isNotClobberedByAConcurrentRefetch() {
        let viewModel = PlannerFixtures.makeViewModel()
        viewModel.groceryGroups = [PlannerFixtures.group(postID: 10, keys: ["10:1"])]
        viewModel.beginToggleCheck(itemKey: "10:1", to: true)

        viewModel.applyGrocery(
            GroceryListPayload(weekStart: "2026-03-02", recipes: [
                PlannerFixtures.group(postID: 10, keys: ["10:1"], checked: false),
            ]),
            generation: viewModel.weekGeneration
        )

        XCTAssertEqual(PlannerFixtures.checked(viewModel, "10:1"), true)
    }

    func test_confirmedCheck_isThenTakenFromTheServerOnRefetch() {
        let viewModel = PlannerFixtures.makeViewModel()
        viewModel.groceryGroups = [PlannerFixtures.group(postID: 10, keys: ["10:1"])]
        viewModel.beginToggleCheck(itemKey: "10:1", to: true)
        viewModel.confirmCheck(itemKey: "10:1")

        viewModel.applyGrocery(
            GroceryListPayload(weekStart: "2026-03-02", recipes: [
                PlannerFixtures.group(postID: 10, keys: ["10:1"], checked: false),
            ]),
            generation: viewModel.weekGeneration
        )

        XCTAssertEqual(PlannerFixtures.checked(viewModel, "10:1"), false)
    }

    func test_applyGrocery_staleGeneration_isDropped() {
        let viewModel = PlannerFixtures.makeViewModel()
        let stale = viewModel.weekGeneration
        viewModel.setWeek(viewModel.week.next, today: PlannerFixtures.today)

        viewModel.applyGrocery(
            GroceryListPayload(weekStart: "2026-03-02", recipes: [
                PlannerFixtures.group(postID: 10, keys: ["10:1"]),
            ]),
            generation: stale
        )

        XCTAssertTrue(viewModel.groceryGroups.isEmpty)
    }

    // MARK: - Integration (composed flows, driven at the seams)

    /// The strategy's "plan two recipes, grocery renders grouped, toggle
    /// persists across refetch" flow, composed end to end without a network.
    func test_flow_planTwoRecipes_groceryRendersGrouped_andAToggleSurvivesRefetch() {
        let viewModel = PlannerFixtures.makeViewModel()
        let monday = viewModel.days[0]
        let tuesday = viewModel.days[1]

        let first = viewModel.beginAdd(PlannerFixtures.post(id: 10), on: monday)
        let second = viewModel.beginAdd(PlannerFixtures.post(id: 11), on: tuesday)
        viewModel.confirmAdd(
            pendingID: first.pendingID ?? 0, with: PlannerFixtures.entry(id: 51, date: monday.key, postID: 10)
        )
        viewModel.confirmAdd(
            pendingID: second.pendingID ?? 0, with: PlannerFixtures.entry(id: 52, date: tuesday.key, postID: 11)
        )

        XCTAssertTrue(viewModel.groceryIsStale, "planning invalidates the derived list")

        viewModel.applyGrocery(
            GroceryListPayload(weekStart: "2026-03-02", recipes: [
                PlannerFixtures.group(postID: 10, keys: ["10:1", "10:2"]),
                PlannerFixtures.group(postID: 11, keys: ["11:1"]),
            ]),
            generation: viewModel.weekGeneration,
            entryRevision: viewModel.entryRevision
        )

        XCTAssertFalse(viewModel.groceryIsStale)
        XCTAssertEqual(viewModel.groceryGroups.map(\.post.id), [10, 11], "grouped per recipe, not merged")
        XCTAssertEqual(viewModel.groceryGroups.map(\.items.count), [2, 1])

        viewModel.beginToggleCheck(itemKey: "10:2", to: true)
        viewModel.confirmCheck(itemKey: "10:2")

        // The server now persists it, so a refetch echoes it back checked.
        viewModel.applyGrocery(
            GroceryListPayload(weekStart: "2026-03-02", recipes: [
                GroceryGroup(post: PlannerFixtures.plannedPost(id: 10), items: [
                    GroceryItem(itemKey: "10:1", name: "Salt", quantity: nil, unit: nil, checked: false),
                    GroceryItem(itemKey: "10:2", name: "Flour", quantity: "2", unit: "cups", checked: true),
                ]),
            ]),
            generation: viewModel.weekGeneration,
            entryRevision: viewModel.entryRevision
        )

        XCTAssertEqual(PlannerFixtures.checked(viewModel, "10:2"), true)
    }

    /// Week navigation must invalidate BOTH lists, so neither can be shown
    /// under the wrong header while the refetch is in flight.
    func test_flow_weekNavigation_clearsAndRefetchesBothLists() {
        let viewModel = PlannerFixtures.makeViewModel()
        viewModel.applyWeek(
            MealPlanWeekPayload(
                weekStart: "2026-03-02",
                entries: [PlannerFixtures.entry(id: 1, date: "2026-03-02", postID: 10)]
            ),
            generation: viewModel.weekGeneration
        )
        viewModel.applyGrocery(
            GroceryListPayload(weekStart: "2026-03-02", recipes: [PlannerFixtures.group(postID: 10, keys: ["10:1"])]),
            generation: viewModel.weekGeneration
        )

        viewModel.setWeek(viewModel.week.next, today: PlannerFixtures.today)

        XCTAssertTrue(viewModel.entries.isEmpty)
        XCTAssertTrue(viewModel.groceryGroups.isEmpty)

        viewModel.applyWeek(
            MealPlanWeekPayload(
                weekStart: "2026-03-09",
                entries: [PlannerFixtures.entry(id: 2, date: "2026-03-09", postID: 20)]
            ),
            generation: viewModel.weekGeneration
        )
        viewModel.applyGrocery(
            GroceryListPayload(weekStart: "2026-03-09", recipes: [PlannerFixtures.group(postID: 20, keys: ["20:1"])]),
            generation: viewModel.weekGeneration
        )

        XCTAssertEqual(viewModel.entries.map(\.post.id), [20])
        XCTAssertEqual(viewModel.groceryGroups.map(\.post.id), [20])
        XCTAssertEqual(viewModel.canonicalWeekStart, "2026-03-09")
    }

    /// A grocery response issued BEFORE an entry change must not clear the
    /// staleness that change created, or the tab silently omits the new recipe.
    func test_groceryResponsePredatingAnEntryChange_doesNotClearStaleness() {
        let viewModel = PlannerFixtures.makeViewModel()
        let inFlightRevision = viewModel.entryRevision

        viewModel.entries = [PlannerFixtures.entry(id: 1, date: "2026-03-02", postID: 10)]
        viewModel.confirmRemove(id: 1)
        XCTAssertTrue(viewModel.groceryIsStale)

        viewModel.applyGrocery(
            GroceryListPayload(weekStart: "2026-03-02", recipes: [PlannerFixtures.group(postID: 10, keys: ["10:1"])]),
            generation: viewModel.weekGeneration,
            entryRevision: inFlightRevision
        )

        XCTAssertTrue(viewModel.groceryIsStale, "a pre-change response must not mark the list fresh")
    }

    /// The probe must retry after a failure, or one dropped request gates a
    /// lapsed subscriber out of their own plan for the whole session.
    func test_hasLoadedOnce_isNotSetUntilTheWeekLoadActuallySucceeds() {
        let viewModel = PlannerFixtures.makeViewModel()

        XCTAssertFalse(viewModel.hasLoadedOnce, "a ViewModel that never loaded must not claim it did")

        viewModel.applyWeek(
            MealPlanWeekPayload(weekStart: "2026-03-02", entries: []),
            generation: viewModel.weekGeneration
        )

        XCTAssertFalse(
            viewModel.hasLoadedOnce,
            "applying a payload is not the success signal — only loadWeekEntries sets it"
        )
    }
}

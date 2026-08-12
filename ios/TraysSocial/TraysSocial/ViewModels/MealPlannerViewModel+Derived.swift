import SwiftUI

/// Read-only views over the planner's state, split out of
/// `MealPlannerViewModel.swift` to give that file headroom under swiftlint's
/// 400-line limit — it was sitting one line short, which puts the next person
/// who adds a comment in the position of shaving design rationale to stay
/// green.
///
/// This extension deliberately touches only `internal` members, so unlike the
/// `+Loading` split it required no access relaxation at all.
extension MealPlannerViewModel {
    var hasAnyEntries: Bool {
        !entries.isEmpty
    }

    /// False while groups are present means the planned recipes carry no
    /// ingredient lines — a distinct empty state from "nothing planned yet",
    /// because the user cannot act on it.
    var hasGroceryItems: Bool {
        groceryGroups.contains { !$0.items.isEmpty }
    }

    func entries(on day: PlannerDay) -> [MealPlanEntry] {
        entries.filter { $0.date == day.key }
    }
}

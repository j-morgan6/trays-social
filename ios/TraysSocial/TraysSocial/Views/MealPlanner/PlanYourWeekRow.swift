import SwiftUI

/// The "Plan your week" card in My Tray (W245 restyle of the W178 row).
///
/// Gating is conditional, via `PlannerEntryMode`. A hard `PlusGate` would
/// satisfy AC 1 (free users see the paywall) but break AC 5 (a lapsed
/// subscriber can still read their plan) — it would strand an existing plan
/// behind a wall the user cannot get past without paying again. The server
/// takes the same position: `GET /meal-plan` is never gated, only
/// `POST /entries` is, so an open card can never reveal content the user is
/// not entitled to see. `.open` draws the week; `.gated` draws the locked
/// teaser.
struct PlanYourWeekRow: View {
    @Environment(AppState.self) private var appState

    let viewModel: MealPlannerViewModel

    @State private var showPaywall = false

    /// Every tap target calls `open()` rather than switching between a
    /// `NavigationLink` and a `PlusGate`.
    ///
    /// Swapping the two swaps view identity when the `hasPlan` probe lands, and
    /// `PlusGate` owns its paywall sheet internally — so a flip to `.open`
    /// while that sheet is up removes the button and tears the sheet down
    /// mid-presentation. Owning the sheet here, on a view that never leaves the
    /// hierarchy, removes the hazard entirely.
    ///
    /// `viewModel.loadIfNeeded()` is deliberately NOT called here. The probe
    /// lives on `MyTrayView`'s root.
    var body: some View {
        PlanWeekCard(mode: mode, days: days, onOpen: open)
            .plusPaywall(isPresented: $showPaywall, feature: .mealPlanner) {
                appState.navigationPath.append(MealPlannerRoute())
            }
    }

    private var mode: PlannerEntryMode {
        PlannerEntryMode.decide(isPlus: appState.isPlus, hasPlan: viewModel.hasAnyEntries)
    }

    private var days: [PlanWeekCard.Day] {
        viewModel.days.map { day in
            let entry = viewModel.entries(on: day).first
            return PlanWeekCard.Day(
                id: day.key,
                label: day.isToday ? String(localized: "Today") : day.weekdayLabel,
                isToday: day.isToday,
                title: entry?.post.title,
                photoURL: entry?.post.thumbURL
            )
        }
    }

    private func open() {
        switch mode {
        case .open: appState.navigationPath.append(MealPlannerRoute())
        case .gated: showPaywall = true
        }
    }
}

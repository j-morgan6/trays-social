import SwiftUI

/// The "Plan your week" entry point in My Tray.
///
/// Gating is conditional, via `PlannerEntryMode`. A hard `PlusGate` would
/// satisfy AC 1 (free users see the paywall) but break AC 5 (a lapsed
/// subscriber can still read their plan) — it would strand an existing plan
/// behind a wall the user cannot get past without paying again. The server
/// takes the same position: `GET /meal-plan` is never gated, only
/// `POST /entries` is, so an open row can never reveal content the user is not
/// entitled to see.
struct PlanYourWeekRow: View {
    @Environment(AppState.self) private var appState
    @Environment(\.colorScheme) private var colorScheme

    let viewModel: MealPlannerViewModel

    @State private var showPaywall = false

    /// One `Button` for both modes rather than switching between a
    /// `NavigationLink` and a `PlusGate`.
    ///
    /// Swapping the two swaps view identity when the `hasPlan` probe lands, and
    /// `PlusGate` owns its paywall sheet internally — so a flip to `.open`
    /// while that sheet is up removes the button and tears the sheet down
    /// mid-presentation. Owning the sheet here, on a view that never leaves the
    /// hierarchy, removes the hazard entirely.
    ///
    /// `viewModel.loadIfNeeded()` is deliberately NOT called here: this row
    /// renders only in My Tray's populated branch, so probing from here could
    /// never populate the empty-state guard that decides which branch runs.
    /// The probe lives on `MyTrayView`'s root.
    var body: some View {
        Button {
            switch PlannerEntryMode.decide(isPlus: appState.isPlus, hasPlan: viewModel.hasAnyEntries) {
            case .open: appState.navigationPath.append(MealPlannerRoute())
            case .gated: showPaywall = true
            }
        } label: {
            label
        }
        .buttonStyle(.borderless)
        .plusPaywall(isPresented: $showPaywall, feature: .mealPlanner) {
            appState.navigationPath.append(MealPlannerRoute())
        }
    }

    private var label: some View {
        HStack(spacing: 12) {
            Image(systemName: "calendar")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(Theme.accentInk(for: colorScheme))
                .frame(width: 34, height: 34)
                .background(
                    Circle().fill(Theme.accent.opacity(colorScheme == .dark ? 0.18 : 0.14))
                )

            VStack(alignment: .leading, spacing: 2) {
                Text("Plan your week")
                    .font(.system(size: 15, weight: .semibold))
                    .tracking(-0.3)
                    .foregroundStyle(colorScheme == .dark ? Theme.textDark : Theme.textLight)
                Text(subtitle)
                    .font(.system(size: 12.5))
                    .foregroundStyle(Theme.muted(for: colorScheme))
                    .lineLimit(1)
            }

            Spacer(minLength: 0)

            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Theme.muted(for: colorScheme))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(colorScheme == .dark ? Color.white.opacity(0.05) : Color.black.opacity(0.03))
        )
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }

    private var subtitle: String {
        viewModel.hasAnyEntries
            ? String(localized: "Meals planned and your grocery list")
            : String(localized: "Plan meals and build a grocery list")
    }
}

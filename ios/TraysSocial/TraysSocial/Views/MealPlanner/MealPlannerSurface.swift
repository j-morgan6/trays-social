import SwiftUI

/// Every presentation and load the planner screen needs, bundled as one
/// modifier on `MealPlannerView`'s root ScrollView.
///
/// A `ViewModifier` for the same two reasons `CollectionsSurface` is one: it
/// keeps `MealPlannerView.body` under swiftlint's limit, and it keeps the
/// sheets together on the root view where they actually present.
///
/// Note this attaches to the **planner's** root, never My Tray's. My Tray
/// already carries `CollectionsSurface` with its own `.plusPaywall`; a second
/// paywall sheet on that same view is a presentation conflict, and the
/// planner's picker has no reason to live there anyway.
struct MealPlannerSurface: ViewModifier {
    @Environment(AppState.self) private var appState

    let viewModel: MealPlannerViewModel
    let tray: MyTrayViewModel
    @Binding var tab: PlannerTab
    @Binding var pickerTarget: PlannerDay?

    func body(content: Content) -> some View {
        content
            .task {
                await viewModel.loadIfNeeded()
                await tray.load(currentUsername: appState.currentUser?.username)
            }
            .refreshable { await viewModel.reload() }
            // Entry changes invalidate the derived checklist. Refetching on tab
            // entry rather than on every change means planning five recipes in
            // a row costs one grocery fetch, not five.
            .onChange(of: tab) { _, newTab in
                guard newTab == .grocery else { return }
                Task { await viewModel.refreshGroceryIfStale() }
            }
            .sheet(item: $pickerTarget) { day in
                RecipePickerSheet(
                    day: day,
                    recipes: tray.savedRecipes,
                    isLoading: tray.isLoading,
                    alreadyPlanned: plannedIDs(on: day),
                    onPick: { post in
                        // A refused add must say why. Discarding this made a
                        // duplicate or out-of-week pick an unexplained no-op,
                        // and left `PlanValidation.message`'s two localized
                        // strings unreachable.
                        let validation = viewModel.addEntry(post, on: day)
                        if let message = validation.message {
                            Toast.custom(message).show()
                        }
                    }
                )
            }
            // The server can still refuse the gated write if entitlement lapsed
            // mid-session; the ViewModel flips needsPaywall and the paywall
            // presents here, in context, rather than as an error toast.
            .plusPaywall(
                isPresented: paywallBinding,
                feature: .mealPlanner,
                onUnlocked: unlocked
            )
    }

    private func plannedIDs(on day: PlannerDay) -> Set<Int> {
        Set(viewModel.entries(on: day).map(\.post.id))
    }

    private var paywallBinding: Binding<Bool> {
        Binding(
            get: { viewModel.needsPaywall },
            set: { presented in
                viewModel.needsPaywall = presented
                // Closed without subscribing: `onUnlocked` will not run, so a
                // remembered plan would otherwise outlive the interaction and
                // fire on some later, unrelated unlock.
                if !presented, !appState.isPlus {
                    viewModel.cancelPendingPlan()
                }
            }
        )
    }

    /// Finish what the user was doing before the paywall interrupted them.
    /// Unlike collections there is no ambiguity to resolve — the target day is
    /// known — so the replay just re-issues the add.
    private func unlocked() {
        viewModel.replayPendingPlan()
    }
}

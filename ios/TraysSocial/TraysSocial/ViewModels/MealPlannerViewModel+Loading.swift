import OSLog
import SwiftUI

/// The planner's network reads, split out of `MealPlannerViewModel.swift` to
/// keep that file under swiftlint's length limit.
///
/// A real seam, not an arbitrary cut: everything here is I/O plus the D95
/// rule that a failed read logs and stays silent. The pure state transitions
/// the tests drive live in the main file and need none of this.
///
/// Two members it touches are `internal` rather than `private` solely because
/// this extension lives in another file: `log` and `hasLoadedOnce`. Both are
/// documented at their declarations.
extension MealPlannerViewModel {
    // MARK: - Reads (D95: log only, never toast)

    /// One fetch per session for the My Tray entry row's `hasPlan` probe. The
    /// planner then opens with data already present.
    func loadIfNeeded() async {
        guard !hasLoadedOnce, !isLoadingWeek else { return }
        await reload()
    }

    func reload() async {
        let generation = weekGeneration
        async let plan: Void = loadWeekEntries(generation: generation)
        async let grocery: Void = loadGrocery(generation: generation)
        _ = await (plan, grocery)
    }

    func loadWeekEntries(generation: Int) async {
        isLoadingWeek = true
        do {
            let response: DataResponse<MealPlanWeekPayload> = try await APIClient.shared.get(
                path: "/meal-plan",
                queryItems: [URLQueryItem(name: "week_start", value: week.wireKey)]
            )
            applyWeek(response.data, generation: generation)
            // ONLY on success. Setting this unconditionally would make one
            // dropped request permanent for the session: `loadIfNeeded` would
            // refuse to retry, `hasAnyEntries` would stay false, and a lapsed
            // subscriber's existing plan would be gated behind the paywall with
            // no way back — the opposite of graceful re-lock.
            markWeekLoadSucceeded()
        } catch {
            Self.log.error("week load failed: \(String(describing: error), privacy: .public)")
        }
        isLoadingWeek = false
    }

    func loadGrocery(generation: Int) async {
        isLoadingGrocery = true
        // Snapshot BEFORE the request: an entry change that lands while this is
        // in flight must not have its staleness cleared by a response that
        // predates it.
        let requestRevision = entryRevision
        do {
            let response: DataResponse<GroceryListPayload> = try await APIClient.shared.get(
                path: "/meal-plan/grocery-list",
                queryItems: [URLQueryItem(name: "week_start", value: week.wireKey)]
            )
            applyGrocery(response.data, generation: generation, entryRevision: requestRevision)
        } catch {
            Self.log.error("grocery load failed: \(String(describing: error), privacy: .public)")
        }
        isLoadingGrocery = false
    }

    func refreshGroceryIfStale() async {
        guard groceryIsStale, !isLoadingGrocery else { return }
        await loadGrocery(generation: weekGeneration)
    }
}

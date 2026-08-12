import OSLog
import SwiftUI

/// Owns the weekly meal planner and its derived grocery checklist.
///
/// **One ViewModel for both screens, not two.** They share the week — and a
/// week mirrored across two objects desynchronizes silently, showing last
/// week's groceries under this week's header. The check write needs the week
/// key too, and an entry change invalidates the grocery list, which one object
/// can mark directly instead of via a `NotificationCenter` hop. Both faces also
/// live on the same pushed screen, so their lifetimes are identical (unlike
/// `CollectionsViewModel` vs `CollectionDetailViewModel`, which are split
/// precisely because the detail screen outlives its shelf).
///
/// Reads are silent (D95: log via `os.Logger`, never toast); writes either
/// toast or present the paywall, never both. Networking goes straight through
/// `APIClient.shared` — there is deliberately no service seam.
@MainActor
@Observable
final class MealPlannerViewModel {
    private(set) var week: PlannerWeek = .current
    /// Monday-first, chronological. Recomputed only in `setWeek` — `body` runs
    /// constantly and these labels cannot change until the week does.
    private(set) var days: [PlannerDay] = []
    private(set) var weekRangeLabel = ""
    /// The server's echoed `week_start`. Sent verbatim on check writes so the
    /// client and server can never disagree about which week a check belongs to.
    private(set) var canonicalWeekStart = ""

    var entries: [MealPlanEntry] = []
    var groceryGroups: [GroceryGroup] = []
    var isLoadingWeek = false
    var isLoadingGrocery = false
    /// Flipped by a server 403 `subscription_required` on the gated write, and
    /// by the locked-user branch of the day's add button.
    var needsPaywall = false

    private(set) var pendingPlan: PlannedIntent?
    /// Set ONLY via `markWeekLoadSucceeded()`, and only when a week load
    /// actually succeeded — a failed probe must stay retryable, or one dropped
    /// request gates a lapsed subscriber out of their own plan for the session.
    private(set) var hasLoadedOnce = false
    /// An entry changed, so the derived checklist is out of date. Refetched
    /// when the user actually opens the grocery tab — planning five recipes in
    /// a row costs one grocery fetch, not five.
    private(set) var groceryIsStale = false

    /// Bumped by `setWeek`. Responses carrying an older value are dropped, so a
    /// fast prev -> prev -> next can never paint one week's data under
    /// another's header.
    private(set) var weekGeneration = 0
    /// Bumped whenever a confirmed entry change invalidates the grocery list.
    /// A grocery response that predates the bump may still render, but must not
    /// clear `groceryIsStale`.
    private(set) var entryRevision = 0

    private var nextPendingID = -1
    private var pendingRemovals: [Int: (index: Int, entry: MealPlanEntry)] = [:]
    /// Check writes that have not yet been confirmed. A refetch landing
    /// mid-write must not repaint these at their pre-toggle value.
    private var inFlightChecks: Set<String> = []

    /// Internal rather than private so `+Loading.swift` can log read failures.
    static let log = Logger(subsystem: "com.trays.social", category: "mealplanner")

    init(week: PlannerWeek = .current, today: Date = Date()) {
        setWeek(week, today: today)
    }

    // MARK: - Week navigation

    /// Pure. Clears both lists so a stale week is never briefly visible under
    /// the new header, and invalidates any in-flight response.
    func setWeek(_ newWeek: PlannerWeek, today: Date = Date()) {
        week = newWeek
        weekGeneration += 1
        entries = []
        groceryGroups = []
        pendingRemovals.removeAll()
        inFlightChecks.removeAll()
        groceryIsStale = false
        canonicalWeekStart = newWeek.wireKey
        days = newWeek.days(today: today)
        weekRangeLabel = newWeek == PlannerWeek.containing(today)
            ? String(localized: "This week")
            : newWeek.rangeLabel
    }

    func goToNextWeek() {
        setWeek(week.next)
        Task { await reload() }
    }

    func goToPreviousWeek() {
        setWeek(week.previous)
        Task { await reload() }
    }

    /// Adopts the server's echoed `week_start` alongside the locally computed
    /// Monday. Both are kept deliberately: the local value is what the UI is
    /// built from, the echo is what goes back on the wire, and a test asserts
    /// they agree.
    func applyWeek(_ payload: MealPlanWeekPayload, generation: Int) {
        guard generation == weekGeneration else { return }
        entries = payload.entries
        canonicalWeekStart = payload.weekStart
    }

    /// `entryRevision` is the value captured when the request was issued. When
    /// it has since advanced, the payload is still worth showing (it is this
    /// week's data) but it predates the entry change, so the stale flag must
    /// survive or the grocery tab would silently omit the recipe just planned.
    func applyGrocery(_ payload: GroceryListPayload, generation: Int, entryRevision: Int? = nil) {
        guard generation == weekGeneration else { return }
        let local = localCheckValues()
        groceryGroups = inFlightChecks.isEmpty
            ? payload.recipes
            : payload.recipes.map { $0.preservingChecks(from: local, keys: inFlightChecks) }
        canonicalWeekStart = payload.weekStart
        if (entryRevision ?? self.entryRevision) == self.entryRevision {
            groceryIsStale = false
        }
    }

    private func localCheckValues() -> [String: Bool] {
        var values: [String: Bool] = [:]
        for group in groceryGroups {
            for item in group.items where inFlightChecks.contains(item.itemKey) {
                values[item.itemKey] = item.checked
            }
        }
        return values
    }
}

// MARK: - Entry writes

//
// Extensions keep each type body under swiftlint's limit; `private` is
// file-scoped, so they still reach the bookkeeping above without widening it.

extension MealPlannerViewModel {
    /// The optimistic half of a plan, with no network. Split out so the state
    /// transition is testable on its own: driving `addEntry` from a test would
    /// spawn a real request whose failure toasts on a bus shared with every
    /// other test in the process.
    ///
    /// Appends rather than sorting — the week view filters by day, so global
    /// array order is invisible and confirm/rollback stay index-free.
    @discardableResult
    func beginAdd(_ post: Post, on day: PlannerDay) -> (validation: PlanValidation, pendingID: Int?) {
        guard week.contains(dayKey: day.key) else { return (.outsideWeek, nil) }
        // Client mirror of `unique_index(:meal_plan_entries, [:user_id, :date, :post_id])`.
        // Without it the user gets an optimistic card that vanishes on the 422.
        guard !entries.contains(where: { $0.date == day.key && $0.post.id == post.id }) else {
            return (.duplicate, nil)
        }
        let pendingID = nextPendingID
        nextPendingID -= 1
        entries.append(MealPlanEntry(id: pendingID, date: day.key, post: PlannedPost(from: post)))
        return (.valid, pendingID)
    }

    /// `isReplay` marks the one add issued by `replayPendingPlan`. A replayed
    /// add must never re-arm the intent: if the server keeps refusing while
    /// `/auth/me` still reports a subscriber, the paywall's `onUnlocked` would
    /// replay, fail, re-arm, and re-present with no exit but leaving the screen.
    @discardableResult
    func addEntry(_ post: Post, on day: PlannerDay, isReplay: Bool = false) -> PlanValidation {
        let (validation, pendingID) = beginAdd(post, on: day)
        guard let pendingID, validation == .valid else { return validation }

        Task { [weak self] in
            do {
                let response: DataResponse<MealPlanEntry> = try await APIClient.shared.post(
                    path: "/meal-plan/entries",
                    // The exact day, not the week's Monday.
                    body: CreateEntryBody(date: day.key, postId: post.id)
                )
                self?.confirmAdd(pendingID: pendingID, with: response.data)
            } catch {
                // Rollback BEFORE the paywall: the optimistic card must be gone
                // before the sheet covers it, or it is still sitting there when
                // the sheet dismisses.
                self?.rollbackAdd(pendingID: pendingID)
                self?.handleAddFailure(error, post: post, on: day, rearm: !isReplay)
            }
        }
        return validation
    }

    /// Replaces the pending row **in place**. Never appends: a concurrent
    /// `reload()` may already have replaced the array, and appending would show
    /// the recipe twice.
    func confirmAdd(pendingID: Int, with server: MealPlanEntry) {
        guard let index = entries.firstIndex(where: { $0.id == pendingID }) else { return }
        entries[index] = server
        markGroceryStale()
    }

    func rollbackAdd(pendingID: Int) {
        entries.removeAll { $0.id == pendingID }
    }

    /// `false` means there was nothing to remove. A pending (negative-id) entry
    /// is refused: there is no server row to `DELETE /meal-plan/entries/-1`.
    @discardableResult
    func beginRemove(id: Int) -> Bool {
        guard id > 0, let index = entries.firstIndex(where: { $0.id == id }) else { return false }
        pendingRemovals[id] = (index: index, entry: entries[index])
        entries.remove(at: index)
        return true
    }

    /// Never gated server-side — a lapsed subscriber can still prune their plan.
    func removeEntry(id: Int) {
        guard beginRemove(id: id) else { return }

        Task { [weak self] in
            do {
                _ = try await APIClient.shared.delete(path: "/meal-plan/entries/\(id)")
                self?.confirmRemove(id: id)
            } catch {
                self?.rollbackRemove(id: id)
                self?.handleWriteFailure(error, operation: "remove", toast: .mealPlanRemoveFailed)
            }
        }
    }

    func confirmRemove(id: Int) {
        pendingRemovals.removeValue(forKey: id)
        markGroceryStale()
    }

    /// The only way to set `hasLoadedOnce`. Exists so the "successful week load
    /// only" invariant stays under the compiler's control even though the
    /// caller lives in `+Loading.swift`.
    func markWeekLoadSucceeded() {
        hasLoadedOnce = true
    }

    /// The derived checklist no longer matches the plan. Bumping the revision
    /// alongside the flag is what stops an older in-flight grocery response
    /// from clearing it.
    func markGroceryStale() {
        entryRevision += 1
        groceryIsStale = true
    }

    func rollbackRemove(id: Int) {
        guard let stashed = pendingRemovals.removeValue(forKey: id) else { return }
        entries.insert(stashed.entry, at: min(stashed.index, entries.count))
    }
}

// MARK: - Grocery checks

extension MealPlannerViewModel {
    /// Returns the **previous** value for rollback; nil when the key is unknown.
    /// Identity is the server's opaque `item_key`, which is already unique
    /// within the week — no post/index pairing needed.
    @discardableResult
    func beginToggleCheck(itemKey: String, to checked: Bool) -> Bool? {
        guard let groupIndex = groceryGroups.firstIndex(where: { group in
            group.items.contains { $0.itemKey == itemKey }
        }),
            let previous = groceryGroups[groupIndex].items.first(where: { $0.itemKey == itemKey })?.checked
        else {
            return nil
        }
        groceryGroups[groupIndex] = groceryGroups[groupIndex].replacingItem(key: itemKey, checked: checked)
        inFlightChecks.insert(itemKey)
        return previous
    }

    /// Never gated server-side — checking items keeps working after a lapse.
    func toggleCheck(itemKey: String, to checked: Bool) {
        guard let previous = beginToggleCheck(itemKey: itemKey, to: checked) else { return }
        let weekKey = canonicalWeekStart

        Task { [weak self] in
            do {
                let _: EmptyResponse = try await APIClient.shared.put(
                    path: "/meal-plan/grocery-checks",
                    body: GroceryCheckBody(weekStart: weekKey, itemKey: itemKey, checked: checked)
                )
                self?.confirmCheck(itemKey: itemKey)
            } catch {
                self?.rollbackCheck(itemKey: itemKey, to: previous)
                self?.handleWriteFailure(error, operation: "check", toast: .groceryCheckFailed)
            }
        }
    }

    func confirmCheck(itemKey: String) {
        inFlightChecks.remove(itemKey)
    }

    func rollbackCheck(itemKey: String, to previous: Bool) {
        inFlightChecks.remove(itemKey)
        guard let groupIndex = groceryGroups.firstIndex(where: { group in
            group.items.contains { $0.itemKey == itemKey }
        }) else {
            return
        }
        groceryGroups[groupIndex] = groceryGroups[groupIndex].replacingItem(key: itemKey, checked: previous)
    }
}

// MARK: - Locked intent + failure funnel

extension MealPlannerViewModel {
    /// The add failed. Toast or paywall as usual — and when it is the paywall,
    /// remember what the user was trying to plan.
    ///
    /// This is the ONLY producer of `pendingPlan`, and it exists because
    /// `PlusGate` cannot cover this case: the gate ran and passed (entitlement
    /// was still cached as valid), and only the server knew the subscription
    /// had lapsed. Without the hand-off, a user who subscribes at that paywall
    /// watches their pick vanish — the rollback already removed the card and
    /// `PlusGate.onUnlocked` never fires, because the gate was never what
    /// presented the sheet.
    @discardableResult
    func handleAddFailure(
        _ error: Error,
        post: Post,
        on day: PlannerDay,
        rearm: Bool = true
    ) -> MealPlanWriteOutcome {
        let outcome = handleWriteFailure(error, operation: "add", toast: .mealPlanAddFailed)
        if outcome == .presentPaywall, rearm {
            pendingPlan = PlannedIntent(dayKey: day.key, post: post)
        }
        return outcome
    }

    /// Called after the paywall dismisses having actually unlocked. Drops the
    /// intent if the user navigated to another week while the sheet was up —
    /// planning a recipe onto an invisible day is worse than doing nothing.
    @discardableResult
    func replayPendingPlan() -> Bool {
        guard let intent = consumePendingPlan(),
              let day = days.first(where: { $0.key == intent.dayKey })
        else {
            return false
        }
        addEntry(intent.post, on: day, isReplay: true)
        return true
    }

    /// Takes the remembered plan, if any, and clears it. Split from the callers
    /// so the hand-off is assertable without issuing a request.
    func consumePendingPlan() -> PlannedIntent? {
        defer { pendingPlan = nil }
        return pendingPlan
    }

    /// The user backed out. The intent must die with the interaction that
    /// created it, or it outlives the sheet and fires on some later, unrelated
    /// unlock.
    func cancelPendingPlan() {
        pendingPlan = nil
    }

    /// Single funnel for every write. Guarantees the 403-is-a-paywall rule
    /// holds everywhere, and that a paywall never *also* fires a toast.
    ///
    /// Returns the branch it took, which is what lets a test assert *which* one
    /// ran without watching the global `ErrorReporter` bus — that bus is shared
    /// with every in-flight mutation, so "no toast was posted" is not a claim a
    /// test can make about one call.
    @discardableResult
    func handleWriteFailure(_ error: Error, operation: String, toast: Toast) -> MealPlanWriteOutcome {
        Self.log.error(
            "\(operation, privacy: .public) failed: \(String(describing: error), privacy: .public)"
        )
        let outcome = MealPlanWriteOutcome.decide(for: error)
        switch outcome {
        case .presentPaywall: needsPaywall = true
        case .toast: toast.show()
        }
        return outcome
    }
}

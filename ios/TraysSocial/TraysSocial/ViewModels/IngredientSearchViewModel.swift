import OSLog
import SwiftUI

/// "What I have" search: a row of ingredient chips, debounced against
/// `GET /search/ingredients?have[]=...`. Read failures are silent (D95):
/// the last results stay on screen and the error is logged only.
@MainActor
@Observable
final class IngredientSearchViewModel {
    private(set) var chips: [String] = []
    private(set) var results: IngredientSearchResults?
    private(set) var isSearching = false
    private(set) var recentIngredients: [String]
    var draft = ""

    /// Fetches results for a chip set. Injected so tests can fail or
    /// count requests; production uses `GET /search/ingredients`.
    typealias Fetch = @MainActor ([String]) async throws -> IngredientSearchResults

    @ObservationIgnored private let preferences: SearchPreferences
    @ObservationIgnored private let fetch: Fetch
    @ObservationIgnored private let debounce: Duration
    @ObservationIgnored private var searchTask: Task<Void, Never>?
    /// The chip set the last successful search answered, so a search
    /// cancelled by navigating away can be re-run on return.
    @ObservationIgnored private var lastCompletedQuery: [String] = []
    private static let log = Logger(subsystem: "com.trays.social", category: "ingredient-search")

    init(
        preferences: SearchPreferences = SearchPreferences(),
        debounce: Duration = .milliseconds(300),
        fetch: @escaping Fetch = IngredientSearchViewModel.liveFetch
    ) {
        self.preferences = preferences
        self.debounce = debounce
        self.fetch = fetch
        recentIngredients = preferences.recentIngredients
    }

    static func liveFetch(_ chips: [String]) async throws -> IngredientSearchResults {
        let response: DataResponse<IngredientSearchResults> = try await APIClient.shared.get(
            path: "/search/ingredients",
            queryItems: IngredientChips.queryItems(for: chips)
        )
        return response.data
    }

    var canAddMore: Bool {
        chips.count < IngredientChips.maxCount
    }

    /// Recently used chips that are not already in the row.
    var suggestions: [String] {
        recentIngredients.filter { !chips.contains($0) }
    }

    func submitDraft() {
        addChip(draft)
        draft = ""
    }

    func addChip(_ raw: String) {
        let updated = IngredientChips.adding(raw, to: chips)
        guard updated != chips else { return }
        chips = updated
        search()
    }

    func removeChip(_ chip: String) {
        chips.removeAll { $0 == chip }
        search()
    }

    func cancelInFlight() {
        searchTask?.cancel()
        searchTask = nil
        isSearching = false
    }

    /// Re-runs a search that `cancelInFlight()` dropped (the section
    /// disappeared mid-debounce or mid-request), so chips and results agree.
    func resumeIfNeeded() {
        guard searchTask == nil, !chips.isEmpty, chips != lastCompletedQuery else { return }
        search()
    }

    /// Awaits the current debounced search, if any. Used by tests.
    func waitForSearch() async {
        await searchTask?.value
    }

    private func search() {
        searchTask?.cancel()
        guard !chips.isEmpty else {
            searchTask = nil
            results = nil
            isSearching = false
            return
        }
        let query = chips
        searchTask = Task {
            try? await Task.sleep(for: debounce)
            guard !Task.isCancelled else { return }
            isSearching = true
            defer {
                if !Task.isCancelled {
                    isSearching = false
                }
            }
            do {
                let found = try await fetch(query)
                guard !Task.isCancelled else { return }
                results = found
                lastCompletedQuery = query
                preferences.recordRecent(query)
                recentIngredients = preferences.recentIngredients
            } catch is CancellationError {
                // ok: a newer chip edit cancelled this request; its own
                // debounced search takes over.
            } catch {
                // D95: read-path failures stay silent; keep the last results.
                // URLSession reports a superseded request as URLError(.cancelled),
                // not CancellationError, so only log real failures.
                if !Task.isCancelled {
                    Self.log.error("ingredient search failed: \(String(describing: error), privacy: .public)")
                }
            }
        }
    }
}

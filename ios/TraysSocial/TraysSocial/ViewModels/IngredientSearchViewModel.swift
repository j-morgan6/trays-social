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

    @ObservationIgnored private let preferences: SearchPreferences
    @ObservationIgnored private var searchTask: Task<Void, Never>?
    private static let log = Logger(subsystem: "com.trays.social", category: "ingredient-search")

    init(preferences: SearchPreferences = SearchPreferences()) {
        self.preferences = preferences
        recentIngredients = preferences.recentIngredients
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
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled else { return }
            isSearching = true
            defer {
                if !Task.isCancelled {
                    isSearching = false
                }
            }
            do {
                let response: DataResponse<IngredientSearchResults> = try await APIClient.shared.get(
                    path: "/search/ingredients",
                    queryItems: IngredientChips.queryItems(for: query)
                )
                guard !Task.isCancelled else { return }
                results = response.data
                preferences.recordRecent(query)
                recentIngredients = preferences.recentIngredients
            } catch is CancellationError {
                // ok: a newer chip edit cancelled this request; its own
                // debounced search takes over.
            } catch {
                // D95: read-path failures stay silent; keep the last results.
                Self.log.error("ingredient search failed: \(String(describing: error), privacy: .public)")
            }
        }
    }
}

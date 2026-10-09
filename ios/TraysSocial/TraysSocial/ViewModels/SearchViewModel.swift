import OSLog
import SwiftUI

/// Recipes mode of the recipe-first Search tab: Browse tiles and Most saved
/// before typing, grouped results (`GET /search?grouped=true`) after.
///
/// Read failures are silent (D95): the last results stay on screen and the
/// error is logged only.
@MainActor
@Observable
final class SearchViewModel {
    var searchText = ""
    private(set) var category: BrowseCategory?
    private(set) var browse: BrowsePayload?
    private(set) var results: GroupedSearchResults?
    private(set) var isSearching = false
    private(set) var isLoadingBrowse = false

    @ObservationIgnored private var searchTask: Task<Void, Never>?
    /// The query the last successful search answered, so a search cancelled
    /// by navigating away can be re-run on return.
    @ObservationIgnored private var lastCompletedItems: [URLQueryItem]?
    private static let log = Logger(subsystem: "com.trays.social", category: "search")

    private var trimmedText: String {
        searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var showsResults: Bool {
        !trimmedText.isEmpty || category != nil
    }

    private var currentItems: [URLQueryItem] {
        SearchQuery.grouped(text: trimmedText, categoryKey: category?.key)
    }

    func loadBrowse() async {
        isLoadingBrowse = true
        defer { isLoadingBrowse = false }
        do {
            let response: AdAwarePaginatedResponse<BrowsePayload> = try await APIClient.shared.get(
                path: "/search/browse"
            )
            browse = response.data
            AdSettings.shared.config = response.adConfig
        } catch {
            // D95: read-path failures stay silent; keep whatever Browse showed.
            if !Task.isCancelled {
                Self.log.error("loadBrowse failed: \(String(describing: error), privacy: .public)")
            }
        }
    }

    /// Loads Browse once; pull-to-refresh calls `loadBrowse()` directly.
    func loadBrowseIfNeeded() async {
        guard browse == nil, !isLoadingBrowse else { return }
        await loadBrowse()
    }

    func select(_ category: BrowseCategory) {
        searchText = ""
        self.category = category
        search()
    }

    /// Called on every keystroke; typing replaces any selected category.
    func textChanged() {
        category = SearchQuery.category(afterTyping: searchText, selected: category)
        search()
    }

    func clear() {
        searchTask?.cancel()
        searchTask = nil
        searchText = ""
        category = nil
        results = nil
        lastCompletedItems = nil
        isSearching = false
    }

    func cancelInFlight() {
        searchTask?.cancel()
        searchTask = nil
        isSearching = false
    }

    /// Re-runs a search that `cancelInFlight()` dropped (the view disappeared
    /// mid-debounce or mid-request), so the field and the results agree.
    func resumeIfNeeded() {
        guard searchTask == nil, showsResults, currentItems != lastCompletedItems else { return }
        search()
    }

    private func search() {
        searchTask?.cancel()
        guard showsResults else {
            searchTask = nil
            results = nil
            lastCompletedItems = nil
            isSearching = false
            return
        }
        let items = currentItems
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
                let response: AdAwarePaginatedResponse<GroupedSearchResults> = try await APIClient.shared.get(
                    path: "/search", queryItems: items
                )
                guard !Task.isCancelled else { return }
                results = response.data
                lastCompletedItems = items
                AdSettings.shared.config = response.adConfig
            } catch is CancellationError {
                // ok: a newer keystroke cancelled this request; its own
                // debounced search takes over.
            } catch {
                // D95: keep the last results. URLSession reports a superseded
                // request as URLError(.cancelled), so only log real failures.
                if !Task.isCancelled {
                    Self.log.error("grouped search failed: \(String(describing: error), privacy: .public)")
                }
            }
        }
    }
}

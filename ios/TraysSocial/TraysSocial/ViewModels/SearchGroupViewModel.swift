import OSLog
import SwiftUI

/// One "See all" group (`GET /search?group=...`), paged by cursor.
/// Read failures are silent (D95): loaded pages stay and the error is logged.
@MainActor
@Observable
final class SearchGroupViewModel {
    private(set) var items: [FeedItem] = []
    private(set) var isLoading = false
    private(set) var hasLoaded = false
    @ObservationIgnored private var cursor: String?
    @ObservationIgnored private var reachedEnd = false

    private static let log = Logger(subsystem: "com.trays.social", category: "search-group")

    var isEmpty: Bool {
        hasLoaded && items.isEmpty
    }

    /// First page only. `.task` re-fires when a pushed post detail pops back,
    /// so this must not append another page each time.
    func loadInitial(_ route: SearchGroupRoute) async {
        guard items.isEmpty, !reachedEnd else { return }
        await loadMore(route)
    }

    func loadMore(_ route: SearchGroupRoute) async {
        guard !isLoading, !reachedEnd else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            let response: AdAwarePaginatedResponse<SearchGroupPage> = try await APIClient.shared.get(
                path: "/search", queryItems: SearchQuery.groupPage(route, cursor: cursor)
            )
            items += response.data.posts
            cursor = response.cursor
            reachedEnd = response.cursor == nil || response.data.posts.isEmpty
            hasLoaded = true
            AdSettings.shared.config = response.adConfig
        } catch {
            if !Task.isCancelled {
                Self.log.error("group page failed: \(String(describing: error), privacy: .public)")
            }
        }
    }
}

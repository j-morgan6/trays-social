import OSLog
import SwiftUI

@MainActor
@Observable
final class FeedViewModel {
    /// W158: the feed is a discriminated union now — posts interleaved
    /// with server-placed ad slots. Post-mutation helpers below index
    /// via `$0.post?.id`, which skips ad/unknown items naturally.
    var items: [FeedItem] = []
    var isLoading = false
    var isLoadingMore = false
    var cursor: String?
    var hasMore = true
    var errorMessage: String?

    private static let log = Logger(subsystem: "com.trays.social", category: "feed")

    /// W170: bumped by refresh(). An in-flight loadMore captures the
    /// generation before awaiting; if a refresh resets the feed while the
    /// page is in flight, the stale page is discarded instead of being
    /// appended onto fresh page 1 (which also overwrote the cursor).
    private var loadGeneration = 0

    /// Loads the first page. D95: read-path failures stay silent — they
    /// log via os.Logger and the screen falls back to its existing
    /// empty / skeleton state. The pull-to-refresh spinner stopping is
    /// the user-visible feedback; a toast on top reads as alarmist.
    /// Toasts are reserved for write-path mutations (see
    /// `ErrorReporter` doc comment).
    func loadFeed() async {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil

        do {
            let response: AdAwarePaginatedResponse<[FeedItem]> = try await APIClient.shared.get(
                path: "/feed"
            )
            items = response.data
            cursor = response.cursor
            hasMore = response.cursor != nil
            AdSettings.shared.config = response.adConfig
        } catch {
            Self.log.error("loadFeed failed: \(String(describing: error), privacy: .public)")
            errorMessage = "Failed to load feed."
        }

        isLoading = false
    }

    func loadMore() async {
        guard !isLoadingMore, hasMore, let cursor else { return }
        isLoadingMore = true
        let generation = loadGeneration

        do {
            let response: AdAwarePaginatedResponse<[FeedItem]> = try await APIClient.shared.get(
                path: "/feed",
                queryItems: [.init(name: "cursor", value: cursor)]
            )
            if generation == loadGeneration {
                items.append(contentsOf: response.data)
                self.cursor = response.cursor
                hasMore = response.cursor != nil
                AdSettings.shared.config = response.adConfig
            }
        } catch {
            // ok: pagination silently fails — existing content stays
            // visible and refresh-to-retry is one swipe away. Surfacing
            // a toast for an infinite-scroll blip would feel noisy.
        }

        isLoadingMore = false
    }

    func refresh() async {
        loadGeneration += 1
        cursor = nil
        hasMore = true
        await loadFeed()
    }

    /// Replace a post in the feed with an updated version (e.g. after the user mutates it in PostDetailView).
    /// No-op if the post is no longer in the loaded page (user paginated past it). Ad slots are skipped.
    func applyPostUpdate(_ post: Post) {
        if let index = items.firstIndex(where: { $0.post?.id == post.id }) {
            items[index] = .post(post)
        }
    }

    // W148: optimistic-delete rollback. Stash a removed row (with its index)
    // so a failed delete can re-insert it at its original position.
    private var pendingDeletions: [Int: (index: Int, post: Post)] = [:]

    func removePost(id: Int) {
        guard let index = items.firstIndex(where: { $0.post?.id == id }),
              let post = items[index].post else { return }
        pendingDeletions[id] = (index, post)
        items.remove(at: index)
    }

    /// Assumes the list is stable while a delete is in flight; min(index, count)
    /// guards against a shrunk list, but a concurrent reload could land the
    /// restored row at a slightly different spot (acceptable for a rare failure).
    func restorePost(id: Int) {
        guard let stashed = pendingDeletions.removeValue(forKey: id) else { return }
        items.insert(.post(stashed.post), at: min(stashed.index, items.count))
    }
}

import OSLog
import SwiftUI

@MainActor
@Observable
final class FeedViewModel {
    var posts: [Post] = []
    var isLoading = false
    var isLoadingMore = false
    var cursor: String?
    var hasMore = true
    var errorMessage: String?

    private static let log = Logger(subsystem: "com.trays.social", category: "feed")

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
            let response: PaginatedResponse<[Post]> = try await APIClient.shared.get(
                path: "/feed"
            )
            posts = response.data
            cursor = response.cursor
            hasMore = response.cursor != nil
        } catch {
            Self.log.error("loadFeed failed: \(String(describing: error), privacy: .public)")
            errorMessage = "Failed to load feed."
        }

        isLoading = false
    }

    func loadMore() async {
        guard !isLoadingMore, hasMore, let cursor else { return }
        isLoadingMore = true

        do {
            let response: PaginatedResponse<[Post]> = try await APIClient.shared.get(
                path: "/feed",
                queryItems: [.init(name: "cursor", value: cursor)]
            )
            posts.append(contentsOf: response.data)
            self.cursor = response.cursor
            hasMore = response.cursor != nil
        } catch {
            // ok: pagination silently fails — existing content stays
            // visible and refresh-to-retry is one swipe away. Surfacing
            // a toast for an infinite-scroll blip would feel noisy.
        }

        isLoadingMore = false
    }

    func refresh() async {
        cursor = nil
        hasMore = true
        await loadFeed()
    }

    /// Replace a post in the feed with an updated version (e.g. after the user mutates it in PostDetailView).
    /// No-op if the post is no longer in the loaded page (user paginated past it).
    func applyPostUpdate(_ post: Post) {
        if let index = posts.firstIndex(where: { $0.id == post.id }) {
            posts[index] = post
        }
    }
}

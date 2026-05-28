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

    /// Loads the first page. `userInitiated` distinguishes the on-appear
    /// auto-load from a pull-to-refresh: when the auto-load fails but
    /// the user already has posts on screen, the failure is logged but
    /// no toast is surfaced — the existing feed remains usable and a
    /// transient network blip would otherwise toast on every cold
    /// launch. User-initiated refreshes and empty-state failures still
    /// surface a toast so the user gets feedback.
    func loadFeed(userInitiated: Bool = false) async {
        guard !isLoading else { return }
        let hadPosts = !posts.isEmpty
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
            if userInitiated || !hadPosts {
                ErrorReporter.report(error, fallback: "Couldn't load your feed.")
            }
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
        await loadFeed(userInitiated: true)
    }

    /// Replace a post in the feed with an updated version (e.g. after the user mutates it in PostDetailView).
    /// No-op if the post is no longer in the loaded page (user paginated past it).
    func applyPostUpdate(_ post: Post) {
        if let index = posts.firstIndex(where: { $0.id == post.id }) {
            posts[index] = post
        }
    }
}

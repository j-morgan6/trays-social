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
            // Silently fail on pagination — existing content still visible
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

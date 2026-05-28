import OSLog
import SwiftUI

@MainActor
@Observable
final class MyTrayViewModel {
    var posts: [Post] = []
    var isLoading = false
    var cursor: String?

    private static let log = Logger(subsystem: "com.trays.social", category: "mytray")

    /// Recipes saved by the current user (Post.isRecipe == true).
    /// Derived view of `posts` so existing fetch + remove logic stays
    /// single-source-of-truth.
    var savedRecipes: [Post] {
        posts.filter(\.isRecipe)
    }

    /// Non-recipe posts saved by the current user.
    var savedPosts: [Post] {
        posts.filter { !$0.isRecipe }
    }

    /// True when both partitions are empty. Drives MyTrayView's switch
    /// to the dashed-amber empty state. Loading is handled separately
    /// via `isLoading` — an in-flight first load is NOT "empty".
    var isEmpty: Bool {
        savedRecipes.isEmpty && savedPosts.isEmpty
    }

    /// Loads bookmarks. D95: read-path failures stay silent — log via
    /// os.Logger and let the existing skeleton / empty-state surface
    /// handle the no-content case. The pull-to-refresh spinner stopping
    /// is the user-visible feedback. Toasts are reserved for write-path
    /// mutations (see `ErrorReporter` doc comment).
    func load() async {
        guard !isLoading else { return }
        isLoading = true

        do {
            let response: PaginatedResponse<[Post]> = try await APIClient.shared.get(path: "/bookmarks")
            posts = response.data
            cursor = response.cursor
        } catch {
            Self.log.error("load failed: \(String(describing: error), privacy: .public)")
        }

        isLoading = false
    }

    func removeBookmark(at index: Int) {
        guard index < posts.count else { return }
        let post = posts.remove(at: index)
        Task {
            try? await APIClient.shared.delete(path: "/bookmarks/\(post.id)")
        }
    }

    func refresh() async {
        cursor = nil
        await load()
    }

    /// D94: reconcile a bookmark toggle from elsewhere (Feed, PostDetail)
    /// in place so the just-saved post appears immediately without a
    /// manual refresh. Mirrors `FeedViewModel.applyPostUpdate` in spirit
    /// but routes by bookmark state — toggling on inserts at the top of
    /// the appropriate section, toggling off removes by id. Idempotent
    /// by post id so rapid taps + optimistic-UI lag don't duplicate.
    func applyPostUpdate(_ post: Post) {
        if post.bookmarkedByCurrentUser == true {
            if !posts.contains(where: { $0.id == post.id }) {
                posts.insert(post, at: 0)
            } else if let index = posts.firstIndex(where: { $0.id == post.id }) {
                posts[index] = post
            }
        } else {
            posts.removeAll(where: { $0.id == post.id })
        }
    }
}

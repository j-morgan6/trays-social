import OSLog
import SwiftUI

@MainActor
@Observable
final class MyTrayViewModel {
    var posts: [Post] = []
    var isLoading = false
    var cursor: String?

    private static let log = Logger(subsystem: "com.trays.social", category: "mytray")

    #if DEBUG
        /// D99: exposed so MyTrayView's .onReceive handler can timestamp
        /// the broadcast landing time without instantiating a separate
        /// Logger. Debug-only — wrapped in #if DEBUG so it's stripped
        /// from release builds.
        static let debugLog = Logger(subsystem: "com.trays.social", category: "mytray.timing")
    #endif

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

    /// D98: loads the user's own posts AND their bookmarked posts,
    /// merges deduped by id, and surfaces them via the existing
    /// savedRecipes/savedPosts partitions. `currentUsername` enables
    /// the own-posts fetch — when nil (signed-out edge case) only
    /// bookmarks are pulled.
    ///
    /// D95: read-path failures stay silent — log via os.Logger and let
    /// the existing skeleton / empty-state surface handle the no-content
    /// case. Toasts are reserved for write-path mutations.
    func load(currentUsername: String? = nil) async {
        guard !isLoading else { return }
        isLoading = true

        async let bookmarksTask: PaginatedResponse<[Post]> = APIClient.shared.get(path: "/bookmarks")
        async let ownPostsTask: PaginatedResponse<[Post]>? = ownPosts(username: currentUsername)

        do {
            let bookmarks = try await bookmarksTask
            cursor = bookmarks.cursor

            let ownPostsResponse = try await ownPostsTask
            let own = ownPostsResponse?.data ?? []

            // Merge deduped by post.id, sort by insertedAt desc so the
            // existing visual order (newest first) is preserved across
            // both sources.
            var byId: [Int: Post] = [:]
            for p in bookmarks.data {
                byId[p.id] = p
            }
            for p in own {
                byId[p.id] = p
            }
            posts = byId.values.sorted(by: { $0.insertedAt > $1.insertedAt })
        } catch {
            Self.log.error("load failed: \(String(describing: error), privacy: .public)")
        }

        isLoading = false
    }

    /// Helper so the optional `currentUsername` doesn't litter load()
    /// with conditional async-let machinery. Returns nil when there's
    /// no username — the caller treats that as 'no own posts to merge'.
    private func ownPosts(username: String?) async throws -> PaginatedResponse<[Post]>? {
        guard let username, !username.isEmpty else { return nil }
        return try await APIClient.shared.get(path: "/users/\(username)/posts")
    }

    func removeBookmark(at index: Int) {
        guard index < posts.count else { return }
        let post = posts.remove(at: index)
        Task {
            try? await APIClient.shared.delete(path: "/bookmarks/\(post.id)")
        }
    }

    func refresh(currentUsername: String? = nil) async {
        cursor = nil
        await load(currentUsername: currentUsername)
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

    // W148: drop an owner-deleted post from the tray (own posts appear here
    // per D98), stashing it so a failed delete re-inserts it in place.
    private var pendingDeletions: [Int: (index: Int, post: Post)] = [:]

    func removePost(id: Int) {
        guard let index = posts.firstIndex(where: { $0.id == id }) else { return }
        pendingDeletions[id] = (index, posts[index])
        posts.remove(at: index)
    }

    func restorePost(id: Int) {
        guard let stashed = pendingDeletions.removeValue(forKey: id) else { return }
        posts.insert(stashed.post, at: min(stashed.index, posts.count))
    }
}

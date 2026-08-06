import OSLog
import SwiftUI

/// The posts inside one collection. Pagination mirrors `FeedViewModel`
/// (cursor + generation guard); read failures stay silent per D95.
///
/// Deliberately separate from `CollectionsViewModel`: the detail screen is
/// pushed onto the *root* navigation stack, so it is not in My Tray's
/// environment subtree and cannot share that instance. Item-count changes
/// travel back over `NotificationCenter`, the same way post mutations already
/// sync between Feed, My Tray, and PostDetail.
@MainActor
@Observable
final class CollectionDetailViewModel {
    let collectionID: Int

    var posts: [Post] = []
    var isLoading = false
    var isLoadingMore = false
    var cursor: String?
    var hasMore = true

    private var loadGeneration = 0
    private var pendingRemovals: [Int: (index: Int, post: Post)] = [:]
    private static let log = Logger(subsystem: "com.trays.social", category: "collections.detail")

    init(collectionID: Int) {
        self.collectionID = collectionID
    }

    var isEmpty: Bool {
        posts.isEmpty
    }

    // MARK: - Read (D95: silent)

    func load() async {
        guard !isLoading else { return }
        isLoading = true
        do {
            let response: PaginatedResponse<[Post]> = try await APIClient.shared.get(
                path: "/collections/\(collectionID)"
            )
            posts = response.data
            cursor = response.cursor
            hasMore = response.cursor != nil
        } catch {
            // Includes the 404 a deleted or foreign collection returns; the
            // view falls through to its empty state rather than toasting.
            Self.log.error("load failed: \(String(describing: error), privacy: .public)")
        }
        isLoading = false
    }

    func loadMore() async {
        guard !isLoadingMore, hasMore, let cursor else { return }
        isLoadingMore = true
        let generation = loadGeneration
        do {
            let response: PaginatedResponse<[Post]> = try await APIClient.shared.get(
                path: "/collections/\(collectionID)",
                queryItems: [.init(name: "cursor", value: cursor)]
            )
            if generation == loadGeneration {
                posts.append(contentsOf: response.data)
                self.cursor = response.cursor
                hasMore = response.cursor != nil
            }
        } catch {
            // ok: a pagination blip leaves existing content visible and
            // pull-to-refresh is one swipe away.
        }
        isLoadingMore = false
    }

    func refresh() async {
        loadGeneration += 1
        cursor = nil
        hasMore = true
        await load()
    }

    /// Applies a page that arrived from elsewhere. Exists so the
    /// stale-generation rule is assertable without a network layer.
    func applyPage(_ page: [Post], cursor newCursor: String?, generation: Int) {
        guard generation == loadGeneration else { return }
        posts.append(contentsOf: page)
        cursor = newCursor
        hasMore = newCursor != nil
    }

    var currentGeneration: Int {
        loadGeneration
    }

    /// What `refresh()` does to the generation, without the network call —
    /// so the stale-page rule can be asserted directly.
    func bumpGenerationForTesting() {
        loadGeneration += 1
        cursor = nil
        hasMore = true
    }

    // MARK: - Remove from collection (never gated)

    /// Optimistic half, no network — the shelf's decrement broadcast included,
    /// since that is part of the same user-visible transition.
    @discardableResult
    func beginRemove(_ post: Post) -> Bool {
        guard let index = posts.firstIndex(where: { $0.id == post.id }) else { return false }
        pendingRemovals[post.id] = (index: index, post: post)
        posts.remove(at: index)
        NotificationCenter.default.post(
            name: .collectionItemRemoved, object: nil,
            userInfo: ["collectionId": collectionID]
        )
        return true
    }

    func removePost(_ post: Post) {
        guard beginRemove(post) else { return }

        let id = collectionID
        Task { [weak self] in
            do {
                _ = try await APIClient.shared.delete(path: "/collections/\(id)/posts/\(post.id)")
                self?.confirmRemove(postId: post.id)
            } catch {
                Self.log.error("remove failed: \(String(describing: error), privacy: .public)")
                self?.rollbackRemove(postId: post.id)
                Toast.collectionRemoveFailed.show()
            }
        }
    }

    func confirmRemove(postId: Int) {
        pendingRemovals.removeValue(forKey: postId)
    }

    func rollbackRemove(postId: Int) {
        guard let stashed = pendingRemovals.removeValue(forKey: postId) else { return }
        posts.insert(stashed.post, at: min(stashed.index, posts.count))
        NotificationCenter.default.post(
            name: .collectionItemRestored, object: nil,
            userInfo: ["collectionId": collectionID]
        )
    }

    // MARK: - Cross-screen sync

    /// Unlike `MyTrayViewModel.applyPostUpdate`, an unbookmarked post must
    /// **stay** here: collection membership is its own table, and the backend
    /// only drops soft-deleted or moderator-removed posts. Update in place.
    func applyPostUpdate(_ post: Post) {
        guard let index = posts.firstIndex(where: { $0.id == post.id }) else { return }
        posts[index] = post
    }

    /// The owner deleted the post outright — the server would stop returning
    /// it, so neither do we.
    func removePost(id: Int) {
        posts.removeAll { $0.id == id }
    }
}

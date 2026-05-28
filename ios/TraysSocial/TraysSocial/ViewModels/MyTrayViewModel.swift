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

    /// Loads bookmarks. `userInitiated` distinguishes the on-appear
    /// auto-load from a pull-to-refresh: when the auto-load fails but
    /// the user already has bookmarks on screen, the failure is logged
    /// but no toast is surfaced — the existing tray remains usable and
    /// a transient network blip would otherwise toast on every cold
    /// launch. User-initiated refreshes and empty-state failures still
    /// surface a toast so the user gets feedback.
    func load(userInitiated: Bool = false) async {
        guard !isLoading else { return }
        let hadPosts = !posts.isEmpty
        isLoading = true

        do {
            let response: PaginatedResponse<[Post]> = try await APIClient.shared.get(path: "/bookmarks")
            posts = response.data
            cursor = response.cursor
        } catch {
            Self.log.error("load failed: \(String(describing: error), privacy: .public)")
            if userInitiated || !hadPosts {
                ErrorReporter.report(error, fallback: "Couldn't load your tray.")
            }
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
        await load(userInitiated: true)
    }
}

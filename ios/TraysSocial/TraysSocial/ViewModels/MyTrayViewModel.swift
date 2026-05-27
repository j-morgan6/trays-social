import SwiftUI

@MainActor
@Observable
final class MyTrayViewModel {
    var posts: [Post] = []
    var isLoading = false
    var cursor: String?

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

    func load() async {
        guard !isLoading else { return }
        isLoading = true

        do {
            let response: PaginatedResponse<[Post]> = try await APIClient.shared.get(path: "/bookmarks")
            posts = response.data
            cursor = response.cursor
        } catch {
            // Silently fail
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
}

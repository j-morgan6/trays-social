import SwiftUI

@Observable
final class MyTrayViewModel {
    var posts: [Post] = []
    var isLoading = false
    var cursor: String?
    var showGrid = false

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

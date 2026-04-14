import SwiftUI

@MainActor
@Observable
final class FollowListViewModel {
    var users: [User] = []
    var isLoading = false
    var isLoadingMore = false
    var cursor: String?
    var hasMore = true

    enum Mode: Hashable {
        case followers
        case following
    }

    let username: String
    let mode: Mode

    init(username: String, mode: Mode) {
        self.username = username
        self.mode = mode
    }

    private var pathSegment: String {
        switch mode {
        case .followers: return "followers"
        case .following: return "following"
        }
    }

    func load() async {
        guard !isLoading else { return }
        isLoading = true
        do {
            let response: PaginatedResponse<[User]> = try await APIClient.shared.get(
                path: "/users/\(username)/\(pathSegment)"
            )
            users = response.data
            cursor = response.cursor
            hasMore = response.cursor != nil
        } catch { }
        isLoading = false
    }

    func loadMore() async {
        guard !isLoadingMore, hasMore, let cursor else { return }
        isLoadingMore = true
        do {
            let response: PaginatedResponse<[User]> = try await APIClient.shared.get(
                path: "/users/\(username)/\(pathSegment)",
                queryItems: [.init(name: "cursor", value: cursor)]
            )
            users.append(contentsOf: response.data)
            self.cursor = response.cursor
            hasMore = response.cursor != nil
        } catch { }
        isLoadingMore = false
    }
}

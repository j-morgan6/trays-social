import SwiftUI

@MainActor
@Observable
final class FollowListViewModel {
    var users: [User] = []
    var isLoading = false
    var isLoadingMore = false
    var cursor: String?
    var hasMore = true

    /// Set when the initial load fails. FollowListView reads this to
    /// render an inline retry surface (W116).
    var loadError: Error?

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
        case .followers: "followers"
        case .following: "following"
        }
    }

    func load() async {
        guard !isLoading else { return }
        isLoading = true
        loadError = nil
        do {
            let response: PaginatedResponse<[User]> = try await APIClient.shared.get(
                path: "/users/\(username)/\(pathSegment)"
            )
            users = response.data
            cursor = response.cursor
            hasMore = response.cursor != nil
        } catch {
            loadError = error
            // Inline retry surface in FollowListView (W116) owns the
            // user-facing copy; skip the toast to avoid double-display.
        }
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
        } catch {
            // ok: pagination silently fails — existing list stays visible
            // and the user can pull-to-refresh / retry. Toast would be
            // noisy on an infinite-scroll blip.
        }
        isLoadingMore = false
    }
}

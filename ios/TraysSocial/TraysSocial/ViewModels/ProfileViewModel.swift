import SwiftUI

@MainActor
@Observable
final class ProfileViewModel {
    var user: User?
    var posts: [Post] = []
    var filter: String = "all"
    var isLoading = false
    var isOwnProfile = false

    func loadProfile(username: String, currentUserId: Int?) async {
        isLoading = true
        do {
            let response: DataResponse<User> = try await APIClient.shared.get(path: "/users/\(username)")
            user = response.data
            isOwnProfile = response.data.id == currentUserId
            await loadPosts(username: username)
        } catch { }
        isLoading = false
    }

    func loadPosts(username: String) async {
        var queryItems: [URLQueryItem] = []
        if filter != "all" {
            queryItems.append(.init(name: "filter", value: filter))
        }
        do {
            let postsResponse: PaginatedResponse<[Post]> = try await APIClient.shared.get(
                path: "/users/\(username)/posts",
                queryItems: queryItems
            )
            posts = postsResponse.data
        } catch { }
    }

    func toggleFollow() {
        guard let user else { return }
        let wasFollowing = user.followedByCurrentUser ?? false

        // Optimistic update
        self.user = User(
            id: user.id, username: user.username, email: user.email, bio: user.bio,
            profilePhotoUrl: user.profilePhotoUrl, insertedAt: user.insertedAt,
            postCount: user.postCount,
            followerCount: (user.followerCount ?? 0) + (wasFollowing ? -1 : 1),
            followingCount: user.followingCount,
            followedByCurrentUser: !wasFollowing
        )

        Task {
            if wasFollowing {
                try? await APIClient.shared.delete(path: "/users/\(user.username)/follow")
            } else {
                try? await APIClient.shared.post(path: "/users/\(user.username)/follow")
            }
        }
    }
}

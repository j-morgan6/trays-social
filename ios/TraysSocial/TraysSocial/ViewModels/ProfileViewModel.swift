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
        } catch {
            ErrorReporter.report(error, fallback: "Couldn't load @\(username)'s profile.")
        }
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
        } catch {
            ErrorReporter.report(error, fallback: "Couldn't load posts for @\(username).")
        }
    }

    func toggleFollow() {
        guard let original = user else { return }
        let wasFollowing = original.followedByCurrentUser ?? false

        // Optimistic update — flip follow state + bump follower count.
        user = User(
            id: original.id, username: original.username, email: original.email, bio: original.bio,
            profilePhotoUrl: original.profilePhotoUrl, insertedAt: original.insertedAt,
            confirmedAt: original.confirmedAt,
            postCount: original.postCount,
            followerCount: (original.followerCount ?? 0) + (wasFollowing ? -1 : 1),
            followingCount: original.followingCount,
            followedByCurrentUser: !wasFollowing,
            isAdmin: original.isAdmin
        )

        Task { [weak self] in
            do {
                if wasFollowing {
                    _ = try await APIClient.shared.delete(path: "/users/\(original.username)/follow") as EmptyResponse
                } else {
                    _ = try await APIClient.shared.post(path: "/users/\(original.username)/follow")
                }
            } catch {
                // W133: rollback to the pre-tap user record and toast
                // with the locked copy so the user sees their follow
                // state actually persists or doesn't.
                await MainActor.run { self?.user = original }
                if wasFollowing {
                    Toast.unfollowFailed.show()
                } else {
                    Toast.followFailed.show()
                }
            }
        }
    }
}

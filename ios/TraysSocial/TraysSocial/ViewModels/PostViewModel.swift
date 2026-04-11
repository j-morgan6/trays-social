import SwiftUI

extension Notification.Name {
    /// Posted when a Post is mutated inside PostDetailView (like, bookmark, or comment).
    /// userInfo["post"] contains the updated Post so other screens (e.g. the feed) can sync.
    static let postUpdated = Notification.Name("trays.postUpdated")
}

@MainActor
@Observable
final class PostViewModel {
    var post: Post?
    var comments: [Comment] = []
    var isLoading = false
    var commentText = ""
    var isSendingComment = false

    func loadPost(id: Int) async {
        isLoading = true
        do {
            let response: DataResponse<Post> = try await APIClient.shared.get(path: "/posts/\(id)")
            post = response.data
        } catch { }
        isLoading = false
    }

    func loadComments(postId: Int) async {
        do {
            let response: PaginatedResponse<[Comment]> = try await APIClient.shared.get(
                path: "/posts/\(postId)/comments"
            )
            comments = response.data
        } catch { }
    }

    func toggleLike() {
        guard let p = post else { return }
        let wasLiked = p.likedByCurrentUser
        // Optimistic update
        let updated = Post(
            id: p.id, type: p.type, caption: p.caption,
            cookingTimeMinutes: p.cookingTimeMinutes, servings: p.servings,
            likeCount: wasLiked ? max(0, p.likeCount - 1) : p.likeCount + 1,
            commentCount: p.commentCount,
            likedByCurrentUser: !wasLiked,
            bookmarkedByCurrentUser: p.bookmarkedByCurrentUser,
            insertedAt: p.insertedAt, user: p.user, photos: p.photos,
            ingredients: p.ingredients, cookingSteps: p.cookingSteps,
            tools: p.tools, tags: p.tags
        )
        post = updated
        broadcastUpdate(updated)
        Task {
            if wasLiked {
                try? await APIClient.shared.delete(path: "/posts/\(p.id)/like")
            } else {
                try? await APIClient.shared.post(path: "/posts/\(p.id)/like")
            }
        }
    }

    func toggleBookmark() {
        guard let p = post else { return }
        let wasBookmarked = p.bookmarkedByCurrentUser ?? false
        let updated = Post(
            id: p.id, type: p.type, caption: p.caption,
            cookingTimeMinutes: p.cookingTimeMinutes, servings: p.servings,
            likeCount: p.likeCount, commentCount: p.commentCount,
            likedByCurrentUser: p.likedByCurrentUser,
            bookmarkedByCurrentUser: !wasBookmarked,
            insertedAt: p.insertedAt, user: p.user, photos: p.photos,
            ingredients: p.ingredients, cookingSteps: p.cookingSteps,
            tools: p.tools, tags: p.tags
        )
        post = updated
        broadcastUpdate(updated)
        Task {
            if wasBookmarked {
                try? await APIClient.shared.delete(path: "/bookmarks/\(p.id)")
            } else {
                try? await APIClient.shared.post(path: "/bookmarks/\(p.id)")
            }
        }
    }

    func sendComment(postId: Int) async {
        guard !commentText.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        isSendingComment = true
        do {
            let body = ["body": commentText]
            let response: DataResponse<Comment> = try await APIClient.shared.post(
                path: "/posts/\(postId)/comments", body: body
            )
            comments.append(response.data)
            commentText = ""

            // Increment local commentCount and broadcast so the feed card stays in sync.
            if let p = post {
                let updated = Post(
                    id: p.id, type: p.type, caption: p.caption,
                    cookingTimeMinutes: p.cookingTimeMinutes, servings: p.servings,
                    likeCount: p.likeCount,
                    commentCount: p.commentCount + 1,
                    likedByCurrentUser: p.likedByCurrentUser,
                    bookmarkedByCurrentUser: p.bookmarkedByCurrentUser,
                    insertedAt: p.insertedAt, user: p.user, photos: p.photos,
                    ingredients: p.ingredients, cookingSteps: p.cookingSteps,
                    tools: p.tools, tags: p.tags
                )
                post = updated
                broadcastUpdate(updated)
            }
        } catch { }
        isSendingComment = false
    }

    private func broadcastUpdate(_ post: Post) {
        NotificationCenter.default.post(name: .postUpdated, object: nil, userInfo: ["post": post])
    }
}

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

    /// Set when loadPost cannot fetch the post (network, 404, etc.).
    /// PostDetailView reads this to render an inline retry surface (W114).
    var loadError: Error?

    /// Set when loadComments fails. CommentsSection reads this to render
    /// its inline retry surface (W115).
    var commentsError: Error?

    /// True while comments are being fetched. CommentsSection shows
    /// skeleton rows when this is true and `comments.isEmpty` (the
    /// branching in W115).
    var isLoadingComments = false

    /// Flips true once `loadComments` has run at least once. The empty
    /// state only renders after the first attempt — pre-load we show a
    /// neutral placeholder so the section doesn't flash "No comments
    /// yet" before the request even fires.
    var commentsLoadAttempted = false

    func loadPost(id: Int) async {
        isLoading = true
        loadError = nil
        do {
            let response: DataResponse<Post> = try await APIClient.shared.get(path: "/posts/\(id)")
            post = response.data
        } catch {
            loadError = error
            ErrorReporter.report(error, fallback: "Couldn't load this post.")
        }
        isLoading = false
    }

    func loadComments(postId: Int) async {
        commentsError = nil
        isLoadingComments = true
        do {
            let response: PaginatedResponse<[Comment]> = try await APIClient.shared.get(
                path: "/posts/\(postId)/comments"
            )
            comments = response.data
        } catch {
            commentsError = error
            // Don't toast here — the inline comments-error surface owns
            // the messaging for this scope (W115). Toast would double up.
        }
        isLoadingComments = false
        commentsLoadAttempted = true
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
        } catch {
            ErrorReporter.report(error, fallback: "Couldn't post your comment.")
        }
        isSendingComment = false
    }

    private func broadcastUpdate(_ post: Post) {
        NotificationCenter.default.post(name: .postUpdated, object: nil, userInfo: ["post": post])
    }
}

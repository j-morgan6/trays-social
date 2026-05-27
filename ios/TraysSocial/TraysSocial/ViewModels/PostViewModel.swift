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
        guard let original = post else { return }
        let wasLiked = original.likedByCurrentUser
        // Optimistic update — flip the like state + count immediately.
        let optimistic = Post(
            id: original.id, type: original.type, caption: original.caption,
            cookingTimeMinutes: original.cookingTimeMinutes, servings: original.servings,
            likeCount: wasLiked ? max(0, original.likeCount - 1) : original.likeCount + 1,
            commentCount: original.commentCount,
            likedByCurrentUser: !wasLiked,
            bookmarkedByCurrentUser: original.bookmarkedByCurrentUser,
            insertedAt: original.insertedAt, user: original.user, photos: original.photos,
            ingredients: original.ingredients, cookingSteps: original.cookingSteps,
            tools: original.tools, tags: original.tags
        )
        post = optimistic
        broadcastUpdate(optimistic)
        Task { [weak self] in
            do {
                if wasLiked {
                    _ = try await APIClient.shared.delete(path: "/posts/\(original.id)/like") as EmptyResponse
                } else {
                    _ = try await APIClient.shared.post(path: "/posts/\(original.id)/like")
                }
            } catch {
                // W133: optimistic UI without rollback is worse than no
                // optimistic UI. Revert to the pre-tap state and toast
                // the user with the locked spec copy so they know it
                // didn't actually persist.
                await MainActor.run {
                    self?.post = original
                    self?.broadcastUpdate(original)
                }
                Toast.likeFailed.show()
            }
        }
    }

    func toggleBookmark() {
        guard let original = post else { return }
        let wasBookmarked = original.bookmarkedByCurrentUser ?? false
        let optimistic = Post(
            id: original.id, type: original.type, caption: original.caption,
            cookingTimeMinutes: original.cookingTimeMinutes, servings: original.servings,
            likeCount: original.likeCount, commentCount: original.commentCount,
            likedByCurrentUser: original.likedByCurrentUser,
            bookmarkedByCurrentUser: !wasBookmarked,
            insertedAt: original.insertedAt, user: original.user, photos: original.photos,
            ingredients: original.ingredients, cookingSteps: original.cookingSteps,
            tools: original.tools, tags: original.tags
        )
        post = optimistic
        broadcastUpdate(optimistic)
        Task { [weak self] in
            do {
                if wasBookmarked {
                    _ = try await APIClient.shared.delete(path: "/bookmarks/\(original.id)") as EmptyResponse
                } else {
                    _ = try await APIClient.shared.post(path: "/bookmarks/\(original.id)")
                }
            } catch {
                await MainActor.run {
                    self?.post = original
                    self?.broadcastUpdate(original)
                }
                if wasBookmarked {
                    Toast.unsaveFailed.show()
                } else {
                    Toast.saveFailed.show()
                }
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

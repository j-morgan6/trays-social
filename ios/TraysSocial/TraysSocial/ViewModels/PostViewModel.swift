import OSLog
import SwiftUI

extension Notification.Name {
    /// Posted when a Post is mutated inside PostDetailView (like, bookmark, or comment).
    /// userInfo["post"] contains the updated Post so other screens (e.g. the feed) can sync.
    static let postUpdated = Notification.Name("trays.postUpdated")

    /// Posted when an owner deletes their post. userInfo["postId"] (Int) lets
    /// the feed/profile/tray drop the row optimistically without holding a Post.
    static let postDeleted = Notification.Name("trays.postDeleted")

    /// Posted when an optimistic delete fails server-side, so the lists that
    /// removed the row on `.postDeleted` re-insert it. userInfo["postId"] (Int).
    static let postDeleteFailed = Notification.Name("trays.postDeleteFailed")
}

@MainActor
@Observable
final class PostViewModel {
    var post: Post?
    var comments: [Comment] = []
    var isLoading = false
    var commentText = ""
    var isSendingComment = false

    private static let log = Logger(subsystem: "com.trays.social", category: "post")

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
        // D77: when the post is already populated (pre-filled from the
        // feed cache via PostDetailView's `initialPost`), refresh
        // silently — skipping isLoading=true prevents flashing the
        // skeleton over content that's already on screen.
        let hadPost = post != nil
        if !hadPost { isLoading = true }
        loadError = nil
        do {
            let response: DataResponse<Post> = try await APIClient.shared.get(path: "/posts/\(id)")
            post = response.data
        } catch {
            // D95: read-path failure — log; PostDetailView reads
            // `loadError` to render its inline retry surface (W114).
            Self.log.error("loadPost failed: \(String(describing: error), privacy: .public)")
            if !hadPost {
                loadError = error
            }
        }
        if !hadPost { isLoading = false }
    }

    /// Pre-seed from the feed cache. Caller passes the Post that was
    /// already loaded by the feed/profile/find list — PostDetailView
    /// renders it instantly while loadPost refreshes in the background.
    func seed(post: Post) {
        guard self.post == nil else { return }
        self.post = post
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
            // D95: read-path failure — log; the inline comments-error
            // surface (W115) owns the user-visible messaging.
            Self.log.error("loadComments failed: \(String(describing: error), privacy: .public)")
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

    /// Owner-only deletion. Optimistically broadcasts `.postDeleted` so the
    /// feed, profile, and tray drop the row immediately, then calls
    /// DELETE /api/v1/posts/:id. On failure it broadcasts the paired
    /// `.postDeleteFailed` so those lists re-insert the row they removed, and
    /// toasts the user. Delete is a write-path action, so a failure toast is
    /// correct here — unlike read/refresh failures, which stay silent (D95).
    /// The View gates this behind an owner check + a confirmation alert.
    func deletePost() {
        guard let id = post?.id else { return }
        NotificationCenter.default.post(name: .postDeleted, object: nil, userInfo: ["postId": id])
        // No [weak self] needed (unlike toggleLike/toggleBookmark): this Task
        // captures only the local `id` and static members — it never touches
        // instance state, so there is no retain cycle to break.
        Task {
            do {
                _ = try await APIClient.shared.delete(path: "/posts/\(id)") as EmptyResponse
            } catch {
                Self.log.error(
                    "deletePost failed id=\(id, privacy: .public): \(String(describing: error), privacy: .public)"
                )
                await MainActor.run {
                    NotificationCenter.default.post(
                        name: .postDeleteFailed, object: nil, userInfo: ["postId": id]
                    )
                }
                Toast.deleteFailed.show()
            }
        }
    }

    /// Owner-only edit (W149). Applies the text + photo changes optimistically
    /// (so the detail view and, via `.postUpdated`, the feed/profile reflect
    /// them immediately), then PATCHes /api/v1/posts/:id. On success it
    /// reconciles with the server's authoritative copy (processed thumb/medium
    /// photo URLs); on failure it rolls back to the original and toasts.
    /// `newPhotoURL` is nil when the photo was not changed — its absence keeps
    /// the existing photo (the backend leaves photo_url untouched when omitted).
    func applyEdit(caption: String, cookingTimeMinutes: Int?, servings: Int?, newPhotoURL: String?) {
        guard let original = post else { return }
        // Optimistic photos: only the position-0 image changes (the backend
        // edit syncs just that row). Preserve any carousel tail so a multi-photo
        // post doesn't visibly collapse to one image during the round-trip.
        let photos: [PostPhoto]
        if let newPhotoURL {
            let lead = PostPhoto(url: newPhotoURL, thumbUrl: nil, mediumUrl: nil, position: 0)
            photos = original.photos.isEmpty
                ? [lead]
                : original.photos.map { $0.position == 0 ? lead : $0 }
        } else {
            photos = original.photos
        }
        let optimistic = Post(
            id: original.id, type: original.type, caption: caption,
            cookingTimeMinutes: cookingTimeMinutes, servings: servings,
            likeCount: original.likeCount, commentCount: original.commentCount,
            likedByCurrentUser: original.likedByCurrentUser,
            bookmarkedByCurrentUser: original.bookmarkedByCurrentUser,
            insertedAt: original.insertedAt, user: original.user, photos: photos,
            ingredients: original.ingredients, cookingSteps: original.cookingSteps,
            tools: original.tools, tags: original.tags
        )
        post = optimistic
        broadcastUpdate(optimistic)

        Task { [weak self] in
            do {
                let body = EditPostRequest(
                    caption: caption,
                    cookingTimeMinutes: cookingTimeMinutes,
                    servings: servings,
                    photoUrl: newPhotoURL
                )
                let response: DataResponse<Post> = try await APIClient.shared.patch(
                    path: "/posts/\(original.id)", body: body
                )
                await MainActor.run {
                    self?.post = response.data
                    self?.broadcastUpdate(response.data)
                }
            } catch {
                await MainActor.run {
                    self?.post = original
                    self?.broadcastUpdate(original)
                }
                Toast.editFailed.show()
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
            // D95: write-path failure — log + toast. sendComment is a
            // user-initiated mutation; silence would read as success.
            Self.log.error("sendComment failed: \(String(describing: error), privacy: .public)")
            ErrorReporter.report(error, fallback: "Couldn't post your comment.")
        }
        isSendingComment = false
    }

    /// PATCH body for an edit. The three text fields are ALWAYS present in the
    /// form, so they're always sent — including an explicit null when a numeric
    /// field is cleared (otherwise the cleared value would silently not persist).
    /// `photoUrl` is the only conditional key: it's omitted when the photo was
    /// not changed, which the backend treats as "keep the existing photo".
    /// apiEncoder converts the camelCase keys to snake_case on the wire.
    private struct EditPostRequest: Encodable {
        let caption: String
        let cookingTimeMinutes: Int?
        let servings: Int?
        let photoUrl: String?

        enum CodingKeys: String, CodingKey {
            case caption, cookingTimeMinutes, servings, photoUrl
        }

        func encode(to encoder: Encoder) throws {
            var c = encoder.container(keyedBy: CodingKeys.self)
            try c.encode(caption, forKey: .caption)
            // encode (not encodeIfPresent) so a cleared field sends explicit null.
            try c.encode(cookingTimeMinutes, forKey: .cookingTimeMinutes)
            try c.encode(servings, forKey: .servings)
            // Conditional: absent => backend keeps the current photo_url.
            try c.encodeIfPresent(photoUrl, forKey: .photoUrl)
        }
    }

    private func broadcastUpdate(_ post: Post) {
        #if DEBUG
            // D99: timestamp the broadcast so the MyTrayView .onReceive
            // landing-time delta can be measured in Console.app.
            Self.log.debug("broadcastUpdate id=\(post.id) bookmarked=\(post.bookmarkedByCurrentUser == true) at=\(Date().timeIntervalSince1970)")
        #endif
        NotificationCenter.default.post(name: .postUpdated, object: nil, userInfo: ["post": post])
    }
}

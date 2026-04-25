import SwiftUI

struct FeedView: View {
    @State private var viewModel = FeedViewModel()

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(viewModel.posts) { post in
                    NavigationLink(value: post) {
                        PostCardView(
                            post: post,
                            onTrayTap: { toggleBookmark(post) },
                            onLikeTap: { toggleLike(post) }
                        )
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .onAppear {
                        prefetchIfNeeded(post)
                    }
                }

                if viewModel.isLoadingMore {
                    ProgressView()
                        .tint(.gray)
                        .padding()
                }
            }
        }
        .refreshable {
            await viewModel.refresh()
        }
        .overlay {
            if viewModel.isLoading, viewModel.posts.isEmpty {
                ProgressView()
                    .tint(Theme.accent)
            } else if viewModel.posts.isEmpty, !viewModel.isLoading {
                VStack(spacing: 8) {
                    Text("No recipes yet")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                    Text("Follow some cooks or create your first recipe")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .task {
            if viewModel.posts.isEmpty {
                await viewModel.loadFeed()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .postUpdated)) { notification in
            if let updated = notification.userInfo?["post"] as? Post {
                viewModel.applyPostUpdate(updated)
            }
        }
    }

    private func toggleBookmark(_ post: Post) {
        let wasBookmarked = post.bookmarkedByCurrentUser ?? false

        // Optimistic UI update
        if let index = viewModel.posts.firstIndex(where: { $0.id == post.id }) {
            let p = viewModel.posts[index]
            viewModel.posts[index] = Post(
                id: p.id, type: p.type, caption: p.caption,
                cookingTimeMinutes: p.cookingTimeMinutes, servings: p.servings,
                likeCount: p.likeCount, commentCount: p.commentCount,
                likedByCurrentUser: p.likedByCurrentUser,
                bookmarkedByCurrentUser: !wasBookmarked,
                insertedAt: p.insertedAt, user: p.user, photos: p.photos,
                ingredients: p.ingredients, cookingSteps: p.cookingSteps,
                tools: p.tools, tags: p.tags
            )
        }

        Task {
            if wasBookmarked {
                _ = try? await APIClient.shared.delete(path: "/bookmarks/\(post.id)") as EmptyResponse
            } else {
                _ = try? await APIClient.shared.post(path: "/bookmarks/\(post.id)")
            }
        }
    }

    private func prefetchIfNeeded(_ post: Post) {
        let threshold = 5
        guard let index = viewModel.posts.firstIndex(where: { $0.id == post.id }) else { return }
        if index >= viewModel.posts.count - threshold {
            Task { await viewModel.loadMore() }
        }
    }

    private func toggleLike(_ post: Post) {
        let wasLiked = post.likedByCurrentUser

        // Optimistic UI update
        if let index = viewModel.posts.firstIndex(where: { $0.id == post.id }) {
            let p = viewModel.posts[index]
            viewModel.posts[index] = Post(
                id: p.id, type: p.type, caption: p.caption,
                cookingTimeMinutes: p.cookingTimeMinutes, servings: p.servings,
                likeCount: max(0, p.likeCount + (wasLiked ? -1 : 1)),
                commentCount: p.commentCount,
                likedByCurrentUser: !wasLiked,
                bookmarkedByCurrentUser: p.bookmarkedByCurrentUser,
                insertedAt: p.insertedAt, user: p.user, photos: p.photos,
                ingredients: p.ingredients, cookingSteps: p.cookingSteps,
                tools: p.tools, tags: p.tags
            )
        }

        Task {
            if wasLiked {
                _ = try? await APIClient.shared.delete(path: "/posts/\(post.id)/like") as EmptyResponse
            } else {
                _ = try? await APIClient.shared.post(path: "/posts/\(post.id)/like")
            }
        }
    }
}

extension String: @retroactive Identifiable {
    public var id: String {
        self
    }
}

/// Placeholders for screens built in later tasks
private struct PostDetailPlaceholder: View {
    let postId: Int
    var body: some View {
        Text("Post Detail #\(postId) — Built in W68")
            .foregroundStyle(.secondary)
    }
}

private struct UserProfilePlaceholder: View {
    let username: String
    var body: some View {
        Text("@\(username) Profile — Built in W71")
            .foregroundStyle(.secondary)
    }
}

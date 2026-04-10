import SwiftUI

struct FeedView: View {
    @State private var viewModel = FeedViewModel()
    @State private var navigateToPost: Post?
    @State private var navigateToUser: String?

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(viewModel.posts) { post in
                    PostCardView(
                        post: post,
                        onTrayTap: { toggleBookmark(post) },
                        onUserTap: { navigateToUser = post.user.username }
                    )
                    .onTapGesture {
                        navigateToPost = post
                    }
                    .onAppear {
                        if post.id == viewModel.posts.last?.id {
                            Task { await viewModel.loadMore() }
                        }
                    }

                    Divider()
                        .background(Theme.surface)
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
            if viewModel.isLoading && viewModel.posts.isEmpty {
                ProgressView()
                    .tint(Theme.accent)
            } else if viewModel.posts.isEmpty && !viewModel.isLoading {
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
                try? await APIClient.shared.post(path: "/bookmarks/\(post.id)")
            }
        }
    }
}

// Conform Post and String to Hashable for navigationDestination(item:)
extension Post: Hashable {
    static func == (lhs: Post, rhs: Post) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

extension String: @retroactive Identifiable {
    public var id: String { self }
}

// Placeholders for screens built in later tasks
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

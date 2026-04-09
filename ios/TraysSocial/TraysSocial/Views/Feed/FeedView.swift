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
                        onTrayTap: { bookmarkPost(post) },
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
                        .background(Color.white.opacity(0.06))
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
                    .tint(.orange)
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
        .navigationDestination(item: $navigateToPost) { post in
            PostDetailPlaceholder(postId: post.id)
        }
        .navigationDestination(item: $navigateToUser) { username in
            UserProfilePlaceholder(username: username)
        }
    }

    private func bookmarkPost(_ post: Post) {
        Task {
            try? await APIClient.shared.post(path: "/bookmarks/\(post.id)")
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

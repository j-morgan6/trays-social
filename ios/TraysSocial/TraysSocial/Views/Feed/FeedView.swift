import SwiftUI

/// Feed screen ported from the Pass 1 prototype's TabFeed
/// (prototype.jsx lines 441-465): a 22pt semibold header section
/// above a lazy vertical list of `FeedCardView`s, ending with a quiet
/// "You're all caught up." footer.
struct FeedView: View {
    @Environment(\.colorScheme) private var colorScheme
    @State private var viewModel = FeedViewModel()

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                headerSection
                    .padding(.top, 4)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 16)

                ForEach(viewModel.posts) { post in
                    NavigationLink(value: post) {
                        FeedCardView(
                            post: post,
                            onSaveTap: { newValue in
                                toggleBookmark(post, newValue: newValue)
                            }
                        )
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.borderless)
                    .onAppear {
                        prefetchIfNeeded(post)
                    }
                }

                if viewModel.isLoadingMore {
                    ProgressView()
                        .tint(.gray)
                        .padding(.vertical, 12)
                } else if !viewModel.posts.isEmpty {
                    Text("You're all caught up.")
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.subtle(for: colorScheme))
                        .frame(maxWidth: .infinity)
                        .padding(.top, 8)
                        .padding(.bottom, 22)
                }
            }
            .padding(.top, 116)
            .padding(.bottom, 116)
        }
        .refreshable {
            await viewModel.refresh()
        }
        .overlay {
            if viewModel.isLoading, viewModel.posts.isEmpty {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(0 ..< 4, id: \.self) { _ in
                            SkeletonPostCard()
                        }
                    }
                }
                .allowsHitTesting(false)
                .skeletonGroup(label: "Loading feed")
                .transition(.opacity)
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

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("From cooks you follow")
                .font(.system(size: 22, weight: .semibold))
                .tracking(-0.44)
                .foregroundStyle(colorScheme == .dark ? Theme.textDark : Theme.textLight)
                .frame(maxWidth: .infinity, alignment: .leading)

            Text(headerSubtitle)
                .font(.system(size: 13))
                .foregroundStyle(Theme.muted(for: colorScheme))
        }
    }

    private var headerSubtitle: String {
        let count = viewModel.posts.count
        return count == 1
            ? "One new post since yesterday."
            : "\(count) new posts since yesterday."
    }

    private func toggleBookmark(_ post: Post, newValue: Bool) {
        let wasBookmarked = post.bookmarkedByCurrentUser ?? false
        guard wasBookmarked != newValue else { return }

        // Snapshot the pre-tap version so we can revert on rollback.
        let original = post

        // Optimistic UI update — flip the row in place.
        if let index = viewModel.posts.firstIndex(where: { $0.id == post.id }) {
            let p = viewModel.posts[index]
            viewModel.posts[index] = Post(
                id: p.id, type: p.type, caption: p.caption,
                cookingTimeMinutes: p.cookingTimeMinutes, servings: p.servings,
                likeCount: p.likeCount, commentCount: p.commentCount,
                likedByCurrentUser: p.likedByCurrentUser,
                bookmarkedByCurrentUser: newValue,
                insertedAt: p.insertedAt, user: p.user, photos: p.photos,
                ingredients: p.ingredients, cookingSteps: p.cookingSteps,
                tools: p.tools, tags: p.tags
            )
        }

        Task {
            do {
                if newValue {
                    _ = try await APIClient.shared.post(path: "/bookmarks/\(post.id)")
                } else {
                    _ = try await APIClient.shared.delete(path: "/bookmarks/\(post.id)") as EmptyResponse
                }
            } catch {
                // W133: rollback — restore the pre-tap row and surface
                // the locked toast copy so the user knows the save
                // didn't actually stick.
                await MainActor.run {
                    if let index = viewModel.posts.firstIndex(where: { $0.id == original.id }) {
                        viewModel.posts[index] = original
                    }
                }
                if newValue {
                    Toast.saveFailed.show()
                } else {
                    Toast.unsaveFailed.show()
                }
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
}

extension String: @retroactive Identifiable {
    public var id: String {
        self
    }
}

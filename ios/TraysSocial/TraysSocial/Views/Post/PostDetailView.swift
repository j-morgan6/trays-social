import SwiftUI

/// Recipe detail. W247: the screen shell — state branches (skeleton, the
/// unavailable surface, the loaded content), the action pill (Save or Edit,
/// and Cook mode), the comment bar, and the sheets. The content lives in `PostDetailContent`.
struct PostDetailView: View {
    @Environment(AppState.self) private var appState
    let postId: Int
    /// D77: optional pre-filled Post from the feed cache. When set, the
    /// view renders instantly and loadPost runs as a silent refresh.
    var initialPost: Post?
    @State private var viewModel = PostViewModel()
    @State private var showCookMode = false
    @State private var showReport = false
    @State private var showDeleteConfirm = false
    @State private var showEditSheet = false

    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// W148: only a post's author may delete it. Gates the Delete menu item.
    private var isOwner: Bool {
        guard let authorId = viewModel.post?.user.id, let me = appState.currentUser?.id
        else { return false }
        return authorId == me
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            if viewModel.isLoading, viewModel.post == nil {
                ScrollView {
                    SkeletonPostDetail()
                        .padding(.bottom, 80)
                }
                .skeletonGroup(label: String(localized: "Loading recipe"))
                .allowsHitTesting(false)
                .transition(.opacity)
            } else if viewModel.post == nil, let error = viewModel.loadError {
                PostUnavailableSurface(
                    error: error,
                    onRetry: {
                        Task {
                            await viewModel.loadPost(id: postId)
                            await viewModel.loadComments(postId: postId)
                        }
                    },
                    onBack: { dismiss() }
                )
            } else if let post = viewModel.post {
                PostDetailContent(
                    post: post,
                    isOwner: isOwner,
                    comments: commentsState,
                    actions: actions(for: post)
                )

                VStack(spacing: 12) {
                    RecipeActionBar(
                        isOwner: isOwner,
                        isSaved: post.bookmarkedByCurrentUser == true,
                        showsCookMode: post.isRecipe && !post.cookingSteps.isEmpty,
                        onToggleSave: { viewModel.toggleBookmark() },
                        onEdit: { showEditSheet = true },
                        onCookMode: { showCookMode = true }
                    )
                    commentInputBar(post)
                }
            }
        }
        .background(Theme.background)
        .navigationBarTitleDisplayMode(.inline)
        // Hide the system nav bar — the floating back/share/bookmark
        // controls on the hero serve that role. Edge-back swipe still
        // works (NavigationStack handles it). iOS 17 API; iOS 18 has
        // `.toolbarVisibility(.hidden, for:)`.
        .toolbar(.hidden, for: .navigationBar)
        .ignoresSafeArea(edges: .top)
        // W148: the overflow menu (Report for everyone, Delete for the
        // owner) lives on the hero's floating controls — a toolbar menu
        // would be hidden by `.toolbar(.hidden, for: .navigationBar)` above.
        .task {
            if let initialPost {
                viewModel.seed(post: initialPost)
            }
            // Unstructured so popping the view does not cancel the POST and
            // comments do not wait on it; recordOpen guards against re-runs.
            Task { await viewModel.recordOpen(postId: postId) }
            await viewModel.loadPost(id: postId)
            await viewModel.loadComments(postId: postId)
        }
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.18), value: viewModel.isLoading)
        .fullScreenCover(isPresented: $showCookMode) {
            if let post = viewModel.post {
                CookModeView(
                    steps: post.cookingSteps,
                    title: RecipeTitle.from(caption: post.caption, fallback: String(localized: "Recipe")),
                    servings: post.servings
                )
            }
        }
        .sheet(isPresented: $showReport) {
            ReportSheetView(targetType: "post", targetId: postId)
        }
        .sheet(isPresented: $showEditSheet) {
            if let post = viewModel.post {
                EditPostView(post: post, postViewModel: viewModel)
            }
        }
        // W148: destructive + irreversible to the user, so confirm first.
        .alert("Delete Post", isPresented: $showDeleteConfirm) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                viewModel.deletePost()
                dismiss()
            }
        } message: {
            Text("This will permanently remove this post. This cannot be undone.")
        }
    }

    private var commentsState: PostDetailContent.CommentsState {
        PostDetailContent.CommentsState(
            comments: viewModel.comments,
            isLoading: viewModel.isLoadingComments,
            loadAttempted: viewModel.commentsLoadAttempted,
            error: viewModel.commentsError
        )
    }

    private func actions(for post: Post) -> PostDetailContent.Actions {
        PostDetailContent.Actions(
            onBack: { dismiss() },
            onOpenAuthor: { appState.navigationPath.append(post.user.username) },
            onToggleLike: { viewModel.toggleLike() },
            onToggleBookmark: { viewModel.toggleBookmark() },
            onReport: { showReport = true },
            onEdit: { showEditSheet = true },
            onDelete: { showDeleteConfirm = true },
            onRetryComments: { Task { await viewModel.loadComments(postId: post.id) } }
        )
    }

    // MARK: - Comment Input

    private func commentInputBar(_ post: Post) -> some View {
        HStack(spacing: 10) {
            TextField("Add a comment...", text: $viewModel.commentText)
                .textFieldStyle(.plain)
                .scaledFont(15, relativeTo: .body)
                .padding(.horizontal, 14)
                .frame(minHeight: 40)
                .background(Capsule(style: .continuous).fill(Theme.surface))
                .overlay(Capsule(style: .continuous).strokeBorder(Theme.hairlineStrong, lineWidth: 1))

            if !viewModel.commentText.isEmpty {
                Button {
                    Task { await viewModel.sendComment(postId: post.id) }
                } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.title2)
                        .foregroundStyle(Theme.accent)
                }
                .disabled(viewModel.isSendingComment)
                .accessibilityLabel(Text("Send note"))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background {
            ZStack {
                Rectangle().fill(.ultraThinMaterial)
                Rectangle().fill(Theme.pill)
            }
            .ignoresSafeArea(edges: .bottom)
        }
    }
}

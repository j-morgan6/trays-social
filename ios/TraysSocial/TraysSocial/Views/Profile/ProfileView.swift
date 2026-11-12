import OSLog
import SwiftUI

private let profileLog = Logger(subsystem: "com.trays.social", category: "profile")

struct ProfileView: View {
    let username: String
    @Environment(AppState.self) private var appState
    @State private var viewModel = ProfileViewModel()
    @State private var showEditProfile = false
    @State private var showSettings = false
    @State private var showReportUser = false
    @State private var showBlockConfirm = false

    var body: some View {
        ScrollView {
            switch state {
            case .loading:
                ProfileSkeleton()
                    .padding(.top, 6)
            case .error, .empty:
                TrayLoadErrorView(title: String(localized: "Couldn't load this tray"), onRetry: reload)
                    .padding(.top, 20)
            case .content:
                if let user = viewModel.user {
                    VStack(alignment: .leading, spacing: 0) {
                        ProfileHeader(
                            user: user,
                            isOwnProfile: viewModel.isOwnProfile,
                            onToggleFollow: { viewModel.toggleFollow() }
                        )
                        .padding(.horizontal, HomeMetrics.inset)
                        .padding(.top, 6)
                        ProfileRecipes(user: user, posts: viewModel.posts, isOwnProfile: viewModel.isOwnProfile)
                    }
                    .transition(.opacity)
                }
            }
        }
        .contentMargins(.bottom, 60, for: .scrollContent)
        .animation(.easeInOut(duration: 0.18), value: viewModel.isLoading)
        .background(Theme.background)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await viewModel.loadProfile(username: username, currentUserId: appState.currentUser?.id)
        }
        .onReceive(NotificationCenter.default.publisher(for: .postDeleted)) { notification in
            if let id = notification.userInfo?["postId"] as? Int {
                viewModel.removePost(id: id)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .postDeleteFailed)) { notification in
            if let id = notification.userInfo?["postId"] as? Int {
                viewModel.restorePost(id: id)
            }
        }
        .navigationDestination(for: Post.self) { post in
            // D77: pre-fill from the profile grid's already-loaded Post.
            PostDetailView(postId: post.id, initialPost: post.user.id == 0 ? nil : post)
        }
        .sheet(isPresented: $showEditProfile) {
            EditProfileView { updatedUser in
                // Re-fetch so stats stay accurate and the (possibly new) username is used.
                Task {
                    await viewModel.loadProfile(
                        username: updatedUser.username,
                        currentUserId: appState.currentUser?.id
                    )
                }
            }
        }
        .sheet(isPresented: $showSettings) {
            SettingsView(onEditProfile: { showEditProfile = true })
        }
        .sheet(isPresented: $showReportUser) {
            if let user = viewModel.user {
                ReportSheetView(targetType: "user", targetId: user.id)
            }
        }
        .toolbar {
            if viewModel.isOwnProfile, viewModel.user != nil {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                            .foregroundStyle(.gray)
                    }
                    .accessibilityLabel("Settings")
                }
            } else if !viewModel.isOwnProfile, viewModel.user != nil {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button("Block User", role: .destructive) {
                            if let user = viewModel.user {
                                blockUser(user.username)
                            }
                        }
                        Button("Report User", role: .destructive) {
                            showReportUser = true
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                            .foregroundStyle(.gray)
                    }
                }
            }
        }
    }

    private func blockUser(_ username: String) {
        Task {
            do {
                let _: MessageResponse = try await APIClient.shared.post(path: "/users/\(username)/block")
                // Pop back to previous screen
            } catch {
                // D95: write-path failure — log + toast. User-initiated.
                profileLog.error("blockUser failed: \(String(describing: error), privacy: .public)")
                ErrorReporter.report(error, fallback: String(localized: "Couldn't block @\(username)."))
            }
        }
    }

    /// W245: content always wins, so a re-fetch after editing the profile
    /// keeps the page instead of flashing the skeleton.
    private var state: ContentLoadState {
        ContentLoadState.decide(
            hasContent: viewModel.user != nil,
            hasLoaded: viewModel.hasLoaded,
            isLoading: viewModel.isLoading,
            loadFailed: viewModel.loadFailed
        )
    }

    private func reload() {
        Task { await viewModel.loadProfile(username: username, currentUserId: appState.currentUser?.id) }
    }
}

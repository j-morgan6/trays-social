import SwiftUI

/// Replaces `MainView` as the user-visible nav shell once W129 wires it
/// in. Hosts a `TabView(.page)` of Feed / My Tray / Find under two
/// floating pills (`TopPill` + `BottomPill`) overlaid via `ZStack`.
///
/// Pill visibility is owned by `ShellViewModel.pillsHidden`. When that
/// flag flips, the pills transition off-screen via `.move(edge:)`
/// combined with `.opacity` — or, when Reduce Motion is on, they
/// simply cross-fade.
///
/// All existing navigation destinations (Post, String/username,
/// NotificationRoute, FollowListRoute) and the CreatePostView sheet
/// from `MainView` are preserved verbatim. `ShellViewModel` is placed
/// in the environment so deeper screens (Cook Mode in particular) can
/// hide the pills without threading callbacks back up.
struct AppShellView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var shell = ShellViewModel()
    @State private var showCreatePost = false

    var body: some View {
        @Bindable var state = appState

        NavigationStack(path: $state.navigationPath) {
            ZStack(alignment: .top) {
                TabView(selection: $state.selectedTray) {
                    FeedView()
                        .tag(AppState.TrayTab.feed)
                    MyTrayView()
                        .tag(AppState.TrayTab.myTray)
                    FindView()
                        .tag(AppState.TrayTab.find)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .ignoresSafeArea(edges: .bottom)

                VStack(spacing: 0) {
                    if !shell.pillsHidden {
                        TopPill(
                            selectedTray: $state.selectedTray,
                            hasUnread: appState.unreadNotificationCount > 0,
                            unreadCount: appState.unreadNotificationCount,
                            onBellTap: {
                                state.navigationPath.append(NotificationRoute())
                            }
                        )
                        .padding(.horizontal, 12)
                        .padding(.top, 8)
                        .transition(pillTransition(edge: .top))
                    }

                    Spacer(minLength: 0)

                    if !shell.pillsHidden {
                        BottomPill(
                            profilePhotoURL: appState.currentUser?.profilePhotoUrl,
                            onCreateTap: { showCreatePost = true },
                            onProfileTap: {
                                state.navigationPath.append(appState.currentUser?.username ?? "")
                            }
                        )
                        .padding(.horizontal, 12)
                        .padding(.bottom, 8)
                        .transition(pillTransition(edge: .bottom))
                    }
                }
            }
            .background(Theme.background)
            .navigationDestination(for: Post.self) { post in
                // D77: pass the full Post (loaded by the feed/profile/find list)
                // through so PostDetailView can render instantly while it
                // refreshes /posts/:id in the background. Deep-link stubs
                // come in with only the id populated — the optional
                // initialPost is a no-op in that case.
                PostDetailView(postId: post.id, initialPost: post.user.id == 0 ? nil : post)
            }
            .navigationDestination(for: String.self) { username in
                ProfileView(username: username)
            }
            .navigationDestination(for: NotificationRoute.self) { _ in
                NotificationsView()
            }
            .navigationDestination(for: FollowListRoute.self) { route in
                FollowListView(route: route)
            }
            .sheet(isPresented: $showCreatePost) {
                CreatePostView()
            }
        }
        .tint(Theme.primary)
        .environment(shell)
        .task {
            // D72: refresh the bell's amber-dot signal on shell mount
            // so the user sees the right state before they open
            // Notifications. NotificationsView keeps it fresh after
            // that via its own .task + onChange.
            await appState.refreshUnreadNotificationsCount()
        }
    }

    private func pillTransition(edge: Edge) -> AnyTransition {
        if reduceMotion {
            return .opacity
        }
        return .move(edge: edge).combined(with: .opacity)
    }
}

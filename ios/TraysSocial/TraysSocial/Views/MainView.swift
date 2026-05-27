import SwiftUI

struct MainView: View {
    @Environment(AppState.self) private var appState
    @State private var showCreatePost = false

    var body: some View {
        @Bindable var state = appState

        NavigationStack(path: $state.navigationPath) {
            VStack(spacing: 0) {
                // Editorial header — serif Trays wordmark, mono day eyebrow,
                // bell with amber dot, big serif page title (changes per tray).
                EditorialHeader(
                    title: trayTitle(for: state.selectedTray),
                    eyebrow: EditorialDate.eyebrowToday
                ) {
                    EditorialBellButton {
                        state.navigationPath.append(NotificationRoute())
                    }
                }

                // Swipeable tray content
                TabView(selection: $state.selectedTray) {
                    FeedView()
                        .tag(AppState.TrayTab.feed)

                    FindView()
                        .tag(AppState.TrayTab.find)

                    MyTrayView()
                        .tag(AppState.TrayTab.myTray)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))

                // Editorial bottom tab bar — Feed/Find/[+]/My Tray/Profile.
                // Replaces the old top TraySelector (tray switching now
                // lives in the bottom bar; swipe still works via the
                // TabView above).
                BottomBar(
                    selectedTray: $state.selectedTray,
                    onCreateTap: { showCreatePost = true },
                    onProfileTap: {
                        state.navigationPath.append(appState.currentUser?.username ?? "")
                    },
                    profilePhotoURL: appState.currentUser?.profilePhotoUrl
                )
            }
            .background(Theme.background)
            .navigationDestination(for: Post.self) { post in
                PostDetailView(postId: post.id)
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
    }

    /// Big serif title for the editorial header. Mirrors the per-screen
    /// IOSHeaderDark title in the design — Feed / Find / My Tray.
    private func trayTitle(for tray: AppState.TrayTab) -> String {
        switch tray {
        case .feed: "Feed"
        case .find: "Find"
        case .myTray: "My Tray"
        }
    }
}

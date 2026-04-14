import SwiftUI

struct NotificationRoute: Hashable {}

struct MainView: View {
    @Environment(AppState.self) private var appState
    @State private var showCreatePost = false
    @State private var path = NavigationPath()

    var body: some View {
        @Bindable var state = appState

        NavigationStack(path: $path) {
            VStack(spacing: 0) {
                // Top bar
                HStack {
                    Text("Trays")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(Theme.text)

                    Spacer()

                    Button {
                        path.append(NotificationRoute())
                    } label: {
                        Image(systemName: "bell")
                            .font(.body)
                            .foregroundStyle(.gray)
                            .overlay(alignment: .topTrailing) {
                                Circle()
                                    .fill(Theme.accent)
                                    .frame(width: 8, height: 8)
                                    .offset(x: 2, y: -2)
                            }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)

                // Tray selector
                TraySelector(selectedTray: $state.selectedTray)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 8)

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

                // Bottom bar
                BottomBar(
                    onCreateTap: { showCreatePost = true },
                    onProfileTap: {
                        path.append(appState.currentUser?.username ?? "")
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
    }
}

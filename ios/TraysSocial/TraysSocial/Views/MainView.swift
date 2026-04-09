import SwiftUI

struct MainView: View {
    @Environment(AppState.self) private var appState
    @State private var showCreatePost = false
    @State private var showProfile = false
    @State private var showNotifications = false

    var body: some View {
        @Bindable var state = appState

        NavigationStack {
            VStack(spacing: 0) {
                // Top bar
                HStack {
                    Text("Trays")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(.white)

                    Spacer()

                    Button {
                        showNotifications = true
                    } label: {
                        Image(systemName: "bell")
                            .font(.body)
                            .foregroundStyle(.gray)
                            .overlay(alignment: .topTrailing) {
                                Circle()
                                    .fill(.orange)
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
                    onProfileTap: { showProfile = true },
                    profilePhotoURL: appState.currentUser?.profilePhotoUrl
                )
            }
            .background(.black)
            .navigationDestination(isPresented: $showNotifications) {
                NotificationsPlaceholder()
            }
            .navigationDestination(isPresented: $showProfile) {
                ProfilePlaceholder()
            }
            .sheet(isPresented: $showCreatePost) {
                CreatePostPlaceholder()
            }
        }
    }
}

// MARK: - Placeholder Views (replaced in subsequent tasks)

private struct NotificationsPlaceholder: View {
    var body: some View {
        Text("Notifications — Built in W72")
            .foregroundStyle(.secondary)
            .navigationTitle("Notifications")
    }
}

private struct ProfilePlaceholder: View {
    var body: some View {
        Text("Profile — Built in W71")
            .foregroundStyle(.secondary)
            .navigationTitle("Profile")
    }
}

private struct CreatePostPlaceholder: View {
    var body: some View {
        Text("Create Post — Built in W70")
            .foregroundStyle(.secondary)
    }
}

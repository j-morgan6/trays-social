import SwiftUI

struct FollowListRoute: Hashable {
    let username: String
    let mode: FollowListViewModel.Mode
}

/// Editorial Followers / Following — matches `IOSFollowers` from the
/// Claude Design handoff. Serif tabs with counts, search field, list
/// of cooks with bio + follow toggle.
struct FollowListView: View {
    let route: FollowListRoute
    @State private var viewModel: FollowListViewModel
    @State private var query: String = ""

    init(route: FollowListRoute) {
        self.route = route
        _viewModel = State(initialValue: FollowListViewModel(
            username: route.username,
            mode: route.mode
        ))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                tabsRow
                    .padding(.horizontal, 20)
                    .padding(.top, 8)

                searchField
                    .padding(.horizontal, 20)
                    .padding(.top, 10)
                    .padding(.bottom, 14)

                if viewModel.isLoading, viewModel.users.isEmpty {
                    loadingSkeleton
                } else if viewModel.loadError != nil, viewModel.users.isEmpty {
                    errorSurface
                } else if visibleUsers.isEmpty {
                    EditorialEmptyState(title: emptyTitle, subtitle: emptySubtitle)
                } else {
                    list
                }

                if viewModel.isLoadingMore {
                    ProgressView().tint(.gray).padding()
                }
            }
        }
        .background(Theme.background)
        .navigationTitle(route.mode == .followers ? "Followers" : "Following")
        .navigationBarTitleDisplayMode(.inline)
        .task { await viewModel.load() }
    }

    // MARK: - Tabs

    private var tabsRow: some View {
        // Tabs are visual today; the route already picks which list to
        // load. Tapping the inactive tab requires a route push from the
        // profile screen — not wired here.
        HStack(spacing: 22) {
            tabPill(label: "Followers", count: route.mode == .followers ? viewModel.users.count : nil, active: route.mode == .followers)
            tabPill(label: "Following", count: route.mode == .following ? viewModel.users.count : nil, active: route.mode == .following)
            Spacer()
        }
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Color.white.opacity(0.08))
                .frame(height: 1)
        }
    }

    private func tabPill(label: String, count: Int?, active: Bool) -> some View {
        VStack(spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(label)
                    .font(.serif(18))
                    .foregroundStyle(active ? Theme.text : Theme.textSecondary)
                if let count {
                    Text("\(count)")
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.textSecondary)
                }
            }
            Rectangle()
                .fill(active ? Theme.secondary : Color.clear)
                .frame(height: 2)
        }
    }

    // MARK: - Search

    private var searchField: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 13))
                .foregroundStyle(Theme.textSecondary)
            TextField(
                "",
                text: $query,
                prompt: Text(searchPrompt).foregroundStyle(Theme.textSecondary)
            )
            .font(.system(size: 13))
            .foregroundStyle(Theme.text)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
        }
        .padding(.horizontal, 14)
        .frame(height: 38)
        .background(Theme.surface)
        .clipShape(Capsule())
    }

    private var searchPrompt: String {
        let n = viewModel.users.count
        switch route.mode {
        case .followers: return "Search \(n) followers"
        case .following: return "Search \(n) people"
        }
    }

    // MARK: - List

    private var list: some View {
        VStack(spacing: 0) {
            ForEach(visibleUsers) { user in
                NavigationLink(value: user.username) {
                    cookRow(user)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.borderless)
                .onAppear {
                    if user.id == viewModel.users.last?.id {
                        Task { await viewModel.loadMore() }
                    }
                }
                Divider().background(Color.white.opacity(0.08))
            }
        }
        .padding(.horizontal, 20)
    }

    private func cookRow(_ user: User) -> some View {
        HStack(alignment: .top, spacing: 12) {
            avatar(for: user)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(user.username)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Theme.text)
                        .lineLimit(1)
                        .truncationMode(.tail)
                    if isNewCook(user) {
                        Text("NEW")
                            .font(.system(size: 9, weight: .medium, design: .monospaced))
                            .tracking(1)
                            .foregroundStyle(Theme.secondary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 1)
                            .background(Theme.secondary.opacity(0.2))
                            .clipShape(Capsule())
                    }
                }
                Text("@\(user.username)")
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.textSecondary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                if let bio = user.bio, !bio.isEmpty {
                    Text(bio)
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.textSecondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            followToggle(for: user)
        }
        .padding(.vertical, 12)
    }

    private func avatar(for user: User) -> some View {
        Circle()
            .fill(Theme.primary)
            .frame(width: 40, height: 40)
            .overlay(
                Text(String(user.username.prefix(1)).uppercased())
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
            )
            .overlay {
                if let urlString = user.profilePhotoUrl, let url = urlString.asBackendURL {
                    CachedAsyncImage(url: url) { image in
                        image.resizable().scaledToFill()
                    } placeholder: { Color.clear }
                        .frame(width: 40, height: 40)
                        .clipShape(Circle())
                }
            }
    }

    @ViewBuilder
    private func followToggle(for user: User) -> some View {
        let following = user.followedByCurrentUser == true
        Button {
            // Hook into viewmodel toggle when it exists; for now this
            // is a visual pill that the user can wire to the existing
            // follow API.
        } label: {
            Text(following ? "Following" : "Follow")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(following ? Theme.text : .white)
                .padding(.horizontal, 12)
                .frame(height: 30)
                .background(following ? Color.clear : Theme.primaryLight)
                .overlay(
                    Capsule().stroke(following ? Color.white.opacity(0.2) : Color.clear, lineWidth: 1)
                )
                .clipShape(Capsule())
        }
        .buttonStyle(.borderless)
    }

    // MARK: - Loading / error / empty

    private var loadingSkeleton: some View {
        VStack(spacing: 6) {
            ForEach(0 ..< 4, id: \.self) { _ in
                SkeletonListRow()
            }
        }
        .padding(.top, 6)
        .skeletonGroup(label: route.mode == .followers ? "Loading followers" : "Loading following")
    }

    private var errorSurface: some View {
        VStack(spacing: 10) {
            Text("Couldn't load \(route.mode == .followers ? "followers" : "following").")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Theme.text)
            Button {
                Task { await viewModel.load() }
            } label: {
                Label("Retry", systemImage: "arrow.clockwise")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color(hex: 0x2A1C00))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(Theme.accent)
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Retry loading this list")
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 60)
    }

    private var emptyTitle: String {
        if !query.isEmpty {
            return "No one matches \u{201C}\(query)\u{201D}."
        }
        switch route.mode {
        case .followers: return "No followers yet."
        case .following: return "Not following anyone yet."
        }
    }

    private var emptySubtitle: String? {
        if !query.isEmpty { return "Try a different name." }
        switch route.mode {
        case .followers: return "Share recipes you're proud of and they'll find you."
        case .following: return "Tap a cook's handle to follow them."
        }
    }

    // MARK: - Derived

    private var visibleUsers: [User] {
        guard !query.isEmpty else { return viewModel.users }
        let q = query.lowercased()
        return viewModel.users.filter { user in
            user.username.lowercased().contains(q) ||
                (user.bio?.lowercased().contains(q) ?? false)
        }
    }

    private func isNewCook(_ user: User) -> Bool {
        guard let inserted = user.insertedAt else { return false }
        return Date().timeIntervalSince(inserted) <= 7 * 24 * 3600
    }
}

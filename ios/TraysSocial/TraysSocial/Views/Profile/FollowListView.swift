import SwiftUI

struct FollowListRoute: Hashable {
    let username: String
    let mode: FollowListViewModel.Mode
}

struct FollowListView: View {
    let route: FollowListRoute
    @State private var viewModel: FollowListViewModel

    init(route: FollowListRoute) {
        self.route = route
        _viewModel = State(initialValue: FollowListViewModel(
            username: route.username,
            mode: route.mode
        ))
    }

    var body: some View {
        List {
            ForEach(viewModel.users) { user in
                NavigationLink(value: user.username) {
                    HStack(spacing: 12) {
                        Circle()
                            .fill(Color(.systemGray4))
                            .frame(width: 40, height: 40)
                            .overlay {
                                if let url = user.profilePhotoUrl, let imageURL = url.asBackendURL {
                                    AsyncImage(url: imageURL) { image in
                                        image.resizable().scaledToFill()
                                    } placeholder: {
                                        Color.clear
                                    }
                                    .frame(width: 40, height: 40)
                                    .clipShape(Circle())
                                } else {
                                    Image(systemName: "person.fill")
                                        .foregroundStyle(.gray)
                                }
                            }

                        VStack(alignment: .leading, spacing: 2) {
                            Text(user.username)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(Theme.text)

                            if let bio = user.bio, !bio.isEmpty {
                                Text(bio)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
                .onAppear {
                    if user.id == viewModel.users.last?.id {
                        Task { await viewModel.loadMore() }
                    }
                }
            }

            if viewModel.isLoadingMore {
                HStack {
                    Spacer()
                    ProgressView().tint(.gray)
                    Spacer()
                }
            }
        }
        .listStyle(.plain)
        .background(Theme.background)
        .navigationTitle(route.mode == .followers ? "Followers" : "Following")
        .navigationBarTitleDisplayMode(.inline)
        .overlay {
            if viewModel.isLoading {
                ProgressView().tint(Theme.accent)
            } else if viewModel.users.isEmpty {
                Text(route.mode == .followers ? "No followers yet" : "Not following anyone")
                    .foregroundStyle(.secondary)
            }
        }
        .task {
            await viewModel.load()
        }
    }
}

import SwiftUI

struct FindView: View {
    @State private var viewModel = FindViewModel()
    @FocusState private var isSearchFocused: Bool

    private let filterChips = ["Under 30 min", "Breakfast", "Dinner", "Vegetarian", "Dessert", "Vegan"]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Search bar
                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.gray)
                    TextField("Search recipes, ingredients, cooks...", text: $viewModel.searchText)
                        .focused($isSearchFocused)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .onSubmit { viewModel.search() }
                        .onChange(of: viewModel.searchText) {
                            viewModel.search()
                        }
                    if !viewModel.searchText.isEmpty {
                        Button { viewModel.clearSearch() } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.gray)
                        }
                    }
                }
                .padding(12)
                .background(Theme.surface)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Theme.surface, lineWidth: 1)
                )
                .padding(.horizontal, 16)

                // Filter chips
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(filterChips, id: \.self) { chip in
                            Button { viewModel.toggleFilter(chip) } label: {
                                Text(chip)
                                    .font(.caption.weight(.medium))
                                    .foregroundStyle(viewModel.activeFilter == chip ? .white : Color(.systemGray))
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 8)
                                    .background(viewModel.activeFilter == chip ? Theme.accent : Theme.surface)
                                    .clipShape(Capsule())
                                    .overlay(
                                        Capsule()
                                            .stroke(Theme.surface.opacity(viewModel.activeFilter == chip ? 0 : 1), lineWidth: 1)
                                    )
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                }

                if viewModel.showSearchResults {
                    // Search results
                    searchResultsView
                } else {
                    // Default: trending + tags
                    trendingView
                }
            }
            .padding(.top, 8)
        }
        .task {
            await viewModel.loadTrending()
        }
    }

    // MARK: - Search Results

    @ViewBuilder
    private var searchResultsView: some View {
        if viewModel.isSearching {
            HStack {
                Spacer()
                ProgressView().tint(Theme.accent)
                Spacer()
            }
            .padding(.top, 40)
        } else {
            // Users
            if !viewModel.users.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("COOKS")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.gray)
                        .padding(.horizontal, 16)

                    ForEach(viewModel.users) { user in
                        HStack(spacing: 10) {
                            Circle()
                                .fill(Color(.systemGray4))
                                .frame(width: 36, height: 36)
                            VStack(alignment: .leading) {
                                Text(user.username)
                                    .font(.subheadline.weight(.medium))
                                    .foregroundStyle(Theme.text)
                                if let bio = user.bio {
                                    Text(bio)
                                        .font(.caption)
                                        .foregroundStyle(.gray)
                                        .lineLimit(1)
                                }
                            }
                            Spacer()
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 4)
                    }
                }
            }

            // Posts
            if !viewModel.posts.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("RECIPES")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.gray)
                        .padding(.horizontal, 16)

                    LazyVStack(spacing: 0) {
                        ForEach(viewModel.posts) { post in
                            PostCardView(post: post)
                            Divider().background(Theme.surface)
                        }
                    }
                }
            }

            if viewModel.posts.isEmpty && viewModel.users.isEmpty {
                VStack(spacing: 8) {
                    Text("No results")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                    Text("Try a different search or filter")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 60)
            }
        }
    }

    // MARK: - Trending

    @ViewBuilder
    private var trendingView: some View {
        if viewModel.isLoadingTrending {
            HStack {
                Spacer()
                ProgressView().tint(Theme.accent)
                Spacer()
            }
            .padding(.top, 40)
        } else {
            // Trending section
            VStack(alignment: .leading, spacing: 10) {
                Text("TRENDING RIGHT NOW")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.gray)
                    .tracking(1)
                    .padding(.horizontal, 16)

                LazyVGrid(columns: [.init(.flexible()), .init(.flexible())], spacing: 8) {
                    ForEach(viewModel.trendingPosts) { post in
                        TrendingCard(post: post)
                    }
                }
                .padding(.horizontal, 16)
            }
        }
    }
}

// MARK: - Trending Card

private struct TrendingCard: View {
    let post: Post

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Photo
            ZStack(alignment: .bottomLeading) {
                if let url = post.primaryPhotoURL {
                    AsyncImage(url: url.asBackendURL) { image in
                        image.resizable().scaledToFill()
                    } placeholder: {
                        Rectangle().fill(Color(.systemGray5))
                    }
                    .frame(height: 120)
                    .clipped()
                } else {
                    Rectangle().fill(Color(.systemGray5))
                        .frame(height: 120)
                }

                if let time = post.cookingTimeMinutes {
                    BadgePill(text: "\(time) min", color: Theme.accent)
                        .padding(6)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 10))

            VStack(alignment: .leading, spacing: 2) {
                Text(post.caption ?? "Recipe")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(Theme.text)
                    .lineLimit(1)

                Text("@\(post.user.username)")
                    .font(.caption2)
                    .foregroundStyle(.gray)
            }
            .padding(.horizontal, 4)
            .padding(.vertical, 6)
        }
        .background(Color(.systemGray6).opacity(0.3))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Theme.surface, lineWidth: 1)
        )
    }

}

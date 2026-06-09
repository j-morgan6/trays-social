import SwiftUI

/// Find screen: a 28pt bold title over a live search bar and a
/// 2-column `GridCard` trending grid.
///
/// The search bar is a real `TextField` bound to
/// `FindViewModel.searchText`; edits debounce through
/// `FindViewModel.search()` (300ms) and hit `GET /search?q=`. While a
/// query is active the trending grid is replaced by results — a "Cooks"
/// rows section over a "Recipes" `GridCard` grid. Trending data flows
/// from the `FindViewModel.trendingPosts` pipeline when the field is empty.
struct FindView: View {
    @Environment(\.colorScheme) private var colorScheme
    @State private var viewModel = FindViewModel()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                titleSection
                    .padding(.horizontal, 20)
                    .padding(.top, 4)
                    .padding(.bottom, 14)

                searchBar
                    .padding(.horizontal, 16)
                    .padding(.bottom, 22)

                if viewModel.showSearchResults {
                    resultsSection
                        .padding(.bottom, 24)
                } else {
                    trendingSection
                        .padding(.bottom, 24)
                }
            }
            .padding(.top, 116)
            .padding(.bottom, 116)
        }
        .onChange(of: viewModel.searchText) {
            // ViewModel.search() debounces 300ms and cancels any in-flight
            // task, so firing on every keystroke is safe.
            viewModel.search()
        }
        .task {
            await viewModel.loadTrending()
        }
        .refreshable {
            // D73: pull-to-refresh gives users a recovery action when
            // a transient backend blip leaves trendingPosts empty.
            await viewModel.loadTrending()
        }
        .onDisappear {
            viewModel.cancelInFlight()
        }
    }

    private var titleSection: some View {
        Text("Find Something to Cook")
            .font(.system(size: 28, weight: .bold))
            .tracking(-0.7)
            .foregroundStyle(colorScheme == .dark ? Theme.textDark : Theme.textLight)
    }

    private var searchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 16, weight: .regular))
                .foregroundStyle(Theme.subtle(for: colorScheme))

            TextField(
                "",
                text: $viewModel.searchText,
                prompt: Text("Search recipes, ingredients, cooks…")
                    .foregroundStyle(Theme.subtle(for: colorScheme))
            )
            .font(.system(size: 14.5))
            .foregroundStyle(colorScheme == .dark ? Theme.textDark : Theme.textLight)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .submitLabel(.search)
            .accessibilityLabel("Search recipes, ingredients, cooks")

            if !viewModel.searchText.isEmpty {
                Button {
                    viewModel.clearSearch()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16, weight: .regular))
                        .foregroundStyle(Theme.subtle(for: colorScheme))
                }
                .buttonStyle(.borderless)
                .accessibilityLabel("Clear search")
            }
        }
        .padding(.horizontal, 14)
        .frame(height: 46)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Theme.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Theme.hairline(for: colorScheme), lineWidth: 1)
        )
    }

    // MARK: - Search results

    @ViewBuilder
    private var resultsSection: some View {
        if viewModel.isSearching, viewModel.posts.isEmpty, viewModel.users.isEmpty {
            // Query in flight with nothing yet — mirror the trending skeleton.
            LazyVGrid(
                columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible())],
                spacing: 10
            ) {
                ForEach(0 ..< 4, id: \.self) { _ in
                    SkeletonGridTile()
                }
            }
            .padding(.horizontal, 16)
            .skeletonGroup(label: "Searching")
        } else if viewModel.posts.isEmpty, viewModel.users.isEmpty {
            EditorialEmptyState(
                title: "No results for \u{201C}\(viewModel.searchText)\u{201D}.",
                subtitle: "Try a different recipe, ingredient, or cook."
            )
        } else {
            VStack(alignment: .leading, spacing: 24) {
                if !viewModel.users.isEmpty {
                    userResults
                }
                if !viewModel.posts.isEmpty {
                    postResults
                }
            }
        }
    }

    private var userResults: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionHeader(label: "Cooks")
                .padding(.horizontal, 20)
                .padding(.bottom, 4)

            ForEach(viewModel.users) { user in
                NavigationLink(value: user.username) {
                    userRow(user)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.borderless)

                Divider()
                    .background(Theme.hairline(for: colorScheme))
                    .padding(.horizontal, 20)
            }
        }
    }

    private func userRow(_ user: User) -> some View {
        HStack(spacing: 12) {
            avatar(for: user)

            VStack(alignment: .leading, spacing: 2) {
                Text(user.username)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(colorScheme == .dark ? Theme.textDark : Theme.textLight)
                    .lineLimit(1)
                    .truncationMode(.tail)
                if let bio = user.bio, !bio.isEmpty {
                    Text(bio)
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.subtle(for: colorScheme))
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Theme.subtle(for: colorScheme))
        }
        .padding(.horizontal, 20)
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
                    } placeholder: {
                        Color.clear
                    }
                    .frame(width: 40, height: 40)
                    .clipShape(Circle())
                }
            }
    }

    private var postResults: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(label: "Recipes")
                .padding(.horizontal, 20)

            LazyVGrid(
                columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible())],
                spacing: 10
            ) {
                ForEach(viewModel.posts) { post in
                    NavigationLink(value: post) {
                        GridCard(
                            photoKey: photoKey(for: post),
                            title: gridTitle(for: post),
                            url: post.primaryPhotoURL?.asBackendURL
                        )
                    }
                    .buttonStyle(.borderless)
                }
            }
            .padding(.horizontal, 16)
        }
    }

    @ViewBuilder
    private var trendingSection: some View {
        if viewModel.isLoadingTrending {
            // W145: section header dropped from the loaded layout, so the
            // skeleton mirrors with just a 2-col grid of tiles.
            LazyVGrid(
                columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible())],
                spacing: 10
            ) {
                ForEach(0 ..< 4, id: \.self) { _ in
                    SkeletonGridTile()
                }
            }
            .padding(.horizontal, 16)
            .skeletonGroup(label: "Loading trending recipes")
        } else if !viewModel.trendingPosts.isEmpty {
            trendingGrid
                .padding(.horizontal, 16)
        } else {
            // D73: post-load with no trending posts. Could be a brand-
            // new install (nothing has trended yet) or a transient
            // backend blip that pull-to-refresh will recover from.
            EditorialEmptyState(
                title: "Nothing trending yet.",
                subtitle: "Pull to refresh, or check back later when posts pick up."
            )
        }
    }

    private var trendingGrid: some View {
        LazyVGrid(
            columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible())],
            spacing: 10
        ) {
            ForEach(viewModel.trendingPosts) { post in
                NavigationLink(value: post) {
                    GridCard(
                        photoKey: photoKey(for: post),
                        title: gridTitle(for: post),
                        url: post.primaryPhotoURL?.asBackendURL
                    )
                }
                .buttonStyle(.borderless)
            }
        }
    }

    private func photoKey(for post: Post) -> FoodPalette.Key {
        let keys = FoodPalette.Key.allCases
        return keys[abs(post.id) % keys.count]
    }

    private func gridTitle(for post: Post) -> String {
        let raw = (post.caption ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !raw.isEmpty else { return "Untitled" }
        let candidate = raw.components(separatedBy: CharacterSet(charactersIn: ".!?\n"))
            .first?
            .trimmingCharacters(in: .whitespaces) ?? raw
        return candidate.isEmpty ? "Untitled" : candidate
    }
}

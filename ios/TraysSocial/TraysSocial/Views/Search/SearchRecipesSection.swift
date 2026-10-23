import SwiftUI

/// Normal-search body: Browse tiles and Most saved before typing; grouped
/// results (Cooks, In your tray, From people you follow, Everyone) after.
///
/// Like `IngredientMatchResults`, the section pads its own content rather
/// than taking outer padding, because `SectionHeader` carries a built-in
/// 20pt inset. Sponsored tiles render only in the FeedItem-shaped lists
/// (Everyone and Most saved); the tray and following groups are plain posts.
struct SearchRecipesSection: View {
    @Environment(AppState.self) private var appState
    let viewModel: SearchViewModel

    private let columns = [GridItem(.flexible(), spacing: 10), GridItem(.flexible())]

    var body: some View {
        if viewModel.showsResults {
            results
        } else {
            browse
        }
    }

    @ViewBuilder
    private var browse: some View {
        if let browse = viewModel.browse {
            VStack(alignment: .leading, spacing: 12) {
                SectionHeader(label: String(localized: "Browse"))
                LazyVGrid(columns: columns, spacing: 10) {
                    ForEach(browse.categories) { category in
                        categoryTile(category)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 8)
                if !browse.mostSaved.isEmpty {
                    SectionHeader(label: String(localized: "Most saved this week"))
                    feedGrid(browse.mostSaved)
                }
            }
        } else if viewModel.isLoadingBrowse {
            ProgressView().frame(maxWidth: .infinity)
        }
    }

    @ViewBuilder
    private var results: some View {
        if let results = viewModel.results {
            VStack(alignment: .leading, spacing: 12) {
                if !results.users.isEmpty {
                    SectionHeader(label: String(localized: "Cooks"))
                    ForEach(results.users) { user in
                        NavigationLink(value: user.username) {
                            Text("@\(user.username)")
                                .font(.headline)
                                .foregroundStyle(Theme.text)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.borderless)
                        .padding(.horizontal, 20)
                    }
                }
                groupSection(.tray, posts: results.tray)
                groupSection(.following, posts: results.following)
                if !results.everyone.isEmpty {
                    SectionHeader(label: SearchGroup.everyone.title, onSeeAll: { seeAll(.everyone) })
                    feedGrid(results.everyone)
                }
                if results.isEmpty {
                    EditorialEmptyState(
                        title: String(localized: "No results yet."),
                        subtitle: String(localized: "Try a different recipe, ingredient, or cook."),
                        topPadding: 24
                    )
                }
            }
        } else if viewModel.isSearching {
            ProgressView().frame(maxWidth: .infinity)
        }
    }

    private func categoryTile(_ category: BrowseCategory) -> some View {
        Button { viewModel.select(category) } label: {
            Text(category.displayLabel)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(Theme.text)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, minHeight: 64, alignment: .bottomLeading)
                .padding(10)
                .background(RoundedRectangle(cornerRadius: 12).fill(Theme.surface))
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func groupSection(_ group: SearchGroup, posts: [Post]) -> some View {
        if !posts.isEmpty {
            SectionHeader(label: group.title, onSeeAll: { seeAll(group) })
            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(posts) { post in card(post) }
            }
            .padding(.horizontal, 16)
        }
    }

    private func feedGrid(_ items: [FeedItem]) -> some View {
        LazyVGrid(columns: columns, spacing: 10) {
            ForEach(items) { item in
                switch item {
                case let .post(post): card(post)
                case let .ad(_, slot): SponsoredTileView(slot: slot)
                case .unknown: EmptyView()
                }
            }
        }
        .padding(.horizontal, 16)
    }

    private func card(_ post: Post) -> some View {
        NavigationLink(value: post) {
            GridCard(
                photoKey: HomeTiles.photoKey(post.id),
                title: RecipeTitle.from(caption: post.caption),
                url: post.primaryPhotoURL?.asBackendURL
            )
        }
        .buttonStyle(.borderless)
    }

    private func seeAll(_ group: SearchGroup) {
        appState.navigationPath.append(SearchGroupRoute(
            group: group,
            query: viewModel.searchText.trimmingCharacters(in: .whitespacesAndNewlines),
            categoryKey: viewModel.category?.key
        ))
    }
}

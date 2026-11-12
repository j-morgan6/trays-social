import SwiftUI

/// One term, typed or a single chip (Search state b): Cooks, In your tray,
/// From people you follow, then Everyone. Shows the term skeleton while a
/// search runs and the plain "No results yet." block when nothing matched.
struct SearchTermResults: View {
    @Environment(AppState.self) private var appState
    let viewModel: SearchViewModel

    var body: some View {
        if viewModel.isSearching {
            SearchTermSkeleton()
        } else if let results = viewModel.results {
            if results.isEmpty {
                EmptyStateBlock(
                    title: String(localized: "No results yet."),
                    subtitle: String(localized: "Try a different recipe, ingredient, or cook."),
                    topPadding: 56,
                    chrome: .plain
                )
            } else {
                SearchTermContent(results: results, onSeeAll: seeAll)
            }
        }
    }

    private func seeAll(_ group: SearchGroup) {
        appState.navigationPath.append(SearchGroupRoute(
            group: group,
            query: viewModel.searchText.trimmingCharacters(in: .whitespacesAndNewlines),
            categoryKey: viewModel.category?.key
        ))
    }
}

/// Loaded one-term results, separate from the view model so previews can
/// render it with sample data.
struct SearchTermContent: View {
    let results: GroupedSearchResults
    let onSeeAll: (SearchGroup) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if !results.users.isEmpty {
                heading(String(localized: "Cooks"))
                SearchCooksPanel(users: results.users)
            }
            rowGroup(.tray, posts: results.tray)
            rowGroup(.following, posts: results.following)
            if !results.everyone.isEmpty {
                heading(SearchGroup.everyone.title, onSeeAll: { onSeeAll(.everyone) })
                SearchRecipeGrid(items: results.everyone)
            }
        }
        .padding(.horizontal, HomeMetrics.inset)
    }

    private func heading(_ label: String, onSeeAll: (() -> Void)? = nil) -> some View {
        HomeSectionHeading(label: label, onSeeAll: onSeeAll)
            .padding(.horizontal, -HomeMetrics.inset)
    }

    @ViewBuilder
    private func rowGroup(_ group: SearchGroup, posts: [Post]) -> some View {
        if !posts.isEmpty {
            heading(group.title, onSeeAll: { onSeeAll(group) })
            VStack(spacing: 10) {
                ForEach(posts) { post in
                    NavigationLink(value: post) { SearchRowCard(post: post) }
                        .buttonStyle(.borderless)
                }
            }
        }
    }
}

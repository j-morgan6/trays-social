import SwiftUI

/// Normal-search body: Browse tiles and Most saved before typing; grouped
/// results (Cooks, In your tray, From people you follow, Everyone) after.
///
/// W243: restyled to the redesign canvas (Search states a, b, d and e).
/// Sponsored cards render only in the FeedItem-shaped lists (Everyone and
/// Most saved); the tray and following groups are plain posts.
struct SearchRecipesSection: View {
    let viewModel: SearchViewModel
    /// Browse finished loading once and has nothing to show.
    var browseFailed = false
    var onRetryBrowse: () -> Void = {}

    var body: some View {
        if viewModel.showsResults {
            SearchTermResults(viewModel: viewModel)
        } else {
            browse
        }
    }

    @ViewBuilder
    private var browse: some View {
        if let browse = viewModel.browse {
            SearchBrowseContent(browse: browse) { viewModel.select($0) }
        } else if browseFailed {
            SearchLoadErrorView(onRetry: onRetryBrowse)
        } else {
            SearchBrowseSkeleton()
        }
    }
}

/// Browse (state a): category tiles, then Most saved this week.
struct SearchBrowseContent: View {
    let browse: BrowsePayload
    let onSelect: (BrowseCategory) -> Void

    private let tileColumns = [GridItem(.flexible(), spacing: 10), GridItem(.flexible())]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HomeSectionHeading(label: String(localized: "Browse"))
                .padding(.horizontal, -HomeMetrics.inset)
            LazyVGrid(columns: tileColumns, spacing: 10) {
                ForEach(Array(browse.categories.enumerated()), id: \.element.id) { index, category in
                    CategoryTile(category: category, index: index) { onSelect(category) }
                }
            }
            if !browse.mostSaved.isEmpty {
                HomeSectionHeading(label: String(localized: "Most saved this week"))
                    .padding(.horizontal, -HomeMetrics.inset)
                SearchRecipeGrid(
                    items: browse.mostSaved,
                    ranks: MostSavedRank.ranks(postIDs: browse.mostSaved.compactMap(\.post?.id))
                )
            }
        }
        .padding(.horizontal, HomeMetrics.inset)
    }
}

/// Browse could not load and there is nothing cached to show. Failures only
/// log; this block is the one visible sign, with a retry.
struct SearchLoadErrorView: View {
    let onRetry: () -> Void

    var body: some View {
        EmptyStateBlock(
            title: String(localized: "Couldn't load Search"),
            subtitle: String(localized: "Check your connection and try again."),
            topPadding: 56,
            chrome: .plain,
            action: .init(title: String(localized: "Try again"), isPrimary: true, perform: onRetry)
        )
    }
}

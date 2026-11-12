import SwiftUI

/// Results of the single search box once it holds two or more ingredients
/// (W205): "You have everything" and "Almost there", each recipe listing
/// what it still needs.
///
/// W243: a summary card first ("With chicken and rice, you can make…"),
/// then RowCards with Ready to cook / Need N pills, and a pantry note. Also
/// shown by the classic `FindView`. Insets itself by `HomeMetrics.inset`.
struct IngredientMatchResults: View {
    let viewModel: IngredientSearchViewModel

    var body: some View {
        if viewModel.isSearching {
            SearchIngredientSkeleton()
        } else if let results = viewModel.results {
            if results.isEmpty {
                EmptyStateBlock(
                    title: String(localized: "No matches yet."),
                    subtitle: String(localized: "Try removing an ingredient."),
                    topPadding: 56,
                    chrome: .plain
                )
            } else {
                IngredientMatchContent(chips: viewModel.chips, results: results)
            }
        }
    }
}

/// Loaded ingredient results, separate from the view model so previews can
/// render it with sample data.
struct IngredientMatchContent: View {
    let chips: [String]
    let results: IngredientSearchResults

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            summary(results)
            matchSection(String(localized: "You have everything"), results.everything, ready: true)
            matchSection(String(localized: "Almost there"), results.almost, ready: false)
            Text("Salt, pepper, oil and garlic count as pantry staples.")
                .scaledFont(12.5, relativeTo: .caption)
                .foregroundStyle(Theme.muted)
                .padding(.top, 18)
                .padding(.horizontal, 4)
        }
        .padding(.horizontal, HomeMetrics.inset)
    }

    private func summary(_ results: IngredientSearchResults) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(IngredientSummary.title(chips: chips))
                .roundedFont(22, weight: .bold, relativeTo: .title2)
                .foregroundStyle(Theme.text)
                .fixedSize(horizontal: false, vertical: true)
            Text(IngredientSummary.subtitle(ready: results.everything.count, almost: results.almost.count))
                .scaledFont(14, relativeTo: .subheadline)
                .foregroundStyle(Theme.muted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 18)
        .padding(.horizontal, 18)
        .padding(.bottom, 16)
        .background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(Theme.accentMuted))
        .padding(.top, 24)
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private func matchSection(_ title: String, _ matches: [IngredientMatch], ready: Bool) -> some View {
        if !matches.isEmpty {
            HomeSectionHeading(label: title)
                .padding(.horizontal, -HomeMetrics.inset)
            VStack(spacing: 10) {
                ForEach(matches) { match in
                    NavigationLink(value: match.post) {
                        SearchRowCard(
                            post: match.post,
                            match: ready ? .readyToCook : .need(match.missing.count),
                            uses: ready ? IngredientUses.line(chips: chips, in: match.post.ingredients) : nil,
                            missing: match.missing
                        )
                    }
                    .buttonStyle(.borderless)
                }
            }
        }
    }
}

import SwiftUI

/// Results of the single search box once it holds two or more ingredients
/// (W205): "You have everything" and "Almost there", each recipe listing
/// what it still needs.
///
/// Pads its own content (16pt) like the other search sections, because
/// `SectionHeader` carries a built-in 20pt inset; outer padding would double it.
struct IngredientMatchResults: View {
    let viewModel: IngredientSearchViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if let results = viewModel.results {
                if results.isEmpty {
                    EditorialEmptyState(
                        title: String(localized: "No matches yet. Try removing an ingredient."),
                        topPadding: 24
                    )
                } else {
                    matchSection(String(localized: "You have everything"), results.everything)
                    matchSection(String(localized: "Almost there"), results.almost)
                }
            } else if viewModel.isSearching {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 16)
            }
        }
    }

    @ViewBuilder
    private func matchSection(_ title: String, _ matches: [IngredientMatch]) -> some View {
        if !matches.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                SectionHeader(label: title, count: matches.count)
                ForEach(matches) { match in
                    NavigationLink(value: match.post) { matchRow(match) }
                        .buttonStyle(.plain)
                        .padding(.horizontal, 16)
                }
            }
        }
    }

    private func matchRow(_ match: IngredientMatch) -> some View {
        HStack(spacing: 12) {
            Photo(key: photoKey(match.post), url: match.post.thumbURL?.asBackendURL)
                .frame(width: 56, height: 56)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text(RecipeTitle.from(caption: match.post.caption))
                    .font(.system(size: 15, weight: .semibold))
                    .lineLimit(1)
                Text("@\(match.post.user.username)")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                if !match.missing.isEmpty {
                    Text("missing: \(match.missing.joined(separator: ", "))")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }
            Spacer(minLength: 0)
        }
        .contentShape(Rectangle())
    }

    private func photoKey(_ post: Post) -> FoodPalette.Key {
        let keys = FoodPalette.Key.allCases
        return keys[abs(post.id) % keys.count]
    }
}

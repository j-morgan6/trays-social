import SwiftUI

/// Find screen ported from the Pass 1 prototype's TabFind
/// (prototype.jsx lines 553-616): a 28pt bold title, a 46pt
/// non-functional search bar, a horizontal row of filter chips with
/// the locked launch set, and a "Trending this week" section header
/// over a 2-column `GridCard` grid.
///
/// Real search wiring stays deferred — chips toggle visual state only;
/// the search bar accepts focus but does nothing. Trending data flows
/// from the existing `FindViewModel.trendingPosts` pipeline.
struct FindView: View {
    @Environment(\.colorScheme) private var colorScheme
    @State private var viewModel = FindViewModel()
    @State private var activeChips: Set<String> = []

    /// Locked launch chip set per the prototype + acceptance criteria.
    /// Do not edit without updating the corresponding design spec.
    private let filterChips: [String] = [
        "Under 30 min",
        "Breakfast",
        "Vegetarian",
        "Easy",
        "Dinner",
        "One pan",
        "Bake",
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                titleSection
                    .padding(.horizontal, 20)
                    .padding(.top, 4)
                    .padding(.bottom, 14)

                searchBar
                    .padding(.horizontal, 16)
                    .padding(.bottom, 14)

                chipRow
                    .padding(.bottom, 22)

                trendingSection
                    .padding(.bottom, 24)
            }
            .padding(.top, 116)
            .padding(.bottom, 116)
        }
        .task {
            await viewModel.loadTrending()
        }
        .onDisappear {
            viewModel.cancelInFlight()
        }
    }

    private var titleSection: some View {
        Text("Find something to cook")
            .font(.system(size: 28, weight: .bold))
            .tracking(-0.7)
            .foregroundStyle(colorScheme == .dark ? Theme.textDark : Theme.textLight)
    }

    private var searchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 16, weight: .regular))
                .foregroundStyle(Theme.subtle(for: colorScheme))

            Text("Search recipes, ingredients, cooks…")
                .font(.system(size: 14.5))
                .foregroundStyle(Theme.subtle(for: colorScheme))

            Spacer()

            Image(systemName: "slider.horizontal.3")
                .font(.system(size: 16, weight: .regular))
                .foregroundStyle(Theme.subtle(for: colorScheme))
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
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Search recipes, ingredients, cooks (coming soon)")
    }

    private var chipRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(filterChips, id: \.self) { chip in
                    FilterChip(
                        label: chip,
                        isActive: activeChips.contains(chip),
                        onTap: { toggle(chip) }
                    )
                }
            }
            .padding(.horizontal, 16)
        }
    }

    private func toggle(_ chip: String) {
        if activeChips.contains(chip) {
            activeChips.remove(chip)
        } else {
            activeChips.insert(chip)
        }
    }

    @ViewBuilder
    private var trendingSection: some View {
        if viewModel.isLoadingTrending {
            VStack(spacing: 10) {
                ForEach(0 ..< 4, id: \.self) { _ in
                    SkeletonGridTile()
                }
            }
            .padding(.horizontal, 20)
            .skeletonGroup(label: "Loading trending recipes")
        } else if !viewModel.trendingPosts.isEmpty {
            SectionHeader(label: "Trending this week", count: viewModel.trendingPosts.count)
            trendingGrid
                .padding(.horizontal, 16)
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
                        title: gridTitle(for: post)
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

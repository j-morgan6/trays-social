import SwiftUI

/// Recipe-first Search tab: Recipes / What I have, remembering the last mode.
///
/// Recipes mode shows Browse tiles and Most saved before typing, then grouped
/// results with "See all" (`SearchRecipesSection`). What I have reuses
/// `IngredientSearchSection` unchanged. Not wired into the shell yet; the
/// recipe-first shell adds it as a tab.
///
/// Laid out like `FindView`: each child pads itself, because the sections
/// carry `SectionHeader`'s built-in inset and outer padding would double it.
struct SearchView: View {
    @Environment(\.colorScheme) private var colorScheme
    @State private var mode: SearchMode = SearchPreferences().mode
    @State private var recipes = SearchViewModel()
    @State private var ingredients = IngredientSearchViewModel()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Text("Search")
                    .font(.system(size: 28, weight: .bold))
                    .tracking(-0.7)
                    .foregroundStyle(colorScheme == .dark ? Theme.textDark : Theme.textLight)
                    .padding(.horizontal, 20)
                    .padding(.top, 4)
                    .padding(.bottom, 14)

                SearchModeSwitch(mode: $mode)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 14)

                if mode == .recipes {
                    searchField
                        .padding(.horizontal, 16)
                        .padding(.bottom, 22)
                    SearchRecipesSection(viewModel: recipes)
                        .padding(.bottom, 24)
                } else {
                    IngredientSearchSection(viewModel: ingredients)
                        .padding(.bottom, 24)
                }
            }
            .padding(.top, 116)
            .padding(.bottom, 116)
        }
        .task { await recipes.loadBrowseIfNeeded() }
        .refreshable { await recipes.loadBrowse() }
        .onChange(of: mode) { _, newMode in SearchPreferences().mode = newMode }
        // The view model debounces 300ms and cancels any in-flight search,
        // so firing on every keystroke is safe.
        .onChange(of: recipes.searchText) { recipes.textChanged() }
        .onAppear { recipes.resumeIfNeeded() }
        .onDisappear { recipes.cancelInFlight() }
    }

    private var searchField: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 16, weight: .regular))
                .foregroundStyle(Theme.subtle(for: colorScheme))
            TextField(
                "",
                text: $recipes.searchText,
                prompt: Text("Search recipes, dishes, cooks…").foregroundStyle(Theme.subtle(for: colorScheme))
            )
            .font(.system(size: 14.5))
            .foregroundStyle(colorScheme == .dark ? Theme.textDark : Theme.textLight)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .submitLabel(.search)
            .accessibilityLabel(Text("Search recipes, dishes, cooks"))
            if recipes.showsResults {
                Button { recipes.clear() } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16, weight: .regular))
                        .foregroundStyle(Theme.subtle(for: colorScheme))
                }
                .buttonStyle(.borderless)
                .accessibilityLabel(Text("Clear search"))
            }
        }
        .padding(.horizontal, 14)
        .frame(height: 46)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Theme.surface))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Theme.hairline(for: colorScheme), lineWidth: 1)
        )
    }
}

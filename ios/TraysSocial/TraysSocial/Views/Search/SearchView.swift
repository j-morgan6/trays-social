import SwiftUI

/// Recipe-first Search tab with one search box (W205).
///
/// Return turns the typed text into an ingredient chip. Browse tiles and Most
/// saved show before typing; one term (typed or a single chip) shows grouped
/// results with "See all" (`SearchRecipesSection`); two or more ingredients
/// show "You have everything" / "Almost there" (`IngredientMatchResults`).
/// `IngredientSearchViewModel.route` makes that call.
///
/// Laid out like `FindView`: each child pads itself, because the sections
/// carry `SectionHeader`'s built-in inset and outer padding would double it.
struct SearchView: View {
    @Environment(\.colorScheme) private var colorScheme
    @State private var recipes = SearchViewModel()
    @State private var ingredients = IngredientSearchViewModel()
    @FocusState private var fieldFocused: Bool

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

                searchField
                    .padding(.horizontal, 16)
                    .padding(.bottom, 12)
                IngredientChipBar(viewModel: ingredients)
                    .padding(.bottom, 10)

                if ingredients.isMatchingIngredients {
                    IngredientMatchResults(viewModel: ingredients)
                        .padding(.bottom, 24)
                } else {
                    SearchRecipesSection(viewModel: recipes)
                        .padding(.bottom, 24)
                }
            }
            .padding(.top, 116)
            .padding(.bottom, 116)
        }
        .task { await recipes.loadBrowseIfNeeded() }
        .refreshable { await recipes.loadBrowse() }
        // Both view models debounce 300ms and cancel any in-flight search,
        // so firing on every keystroke is safe.
        .onChange(of: ingredients.draft) { ingredients.draftChanged() }
        .onChange(of: ingredients.searchTerm) { _, term in recipes.searchText = term }
        .onChange(of: recipes.searchText) { recipes.textChanged() }
        .onAppear {
            recipes.resumeIfNeeded()
            ingredients.resumeIfNeeded()
        }
        .onDisappear {
            recipes.cancelInFlight()
            ingredients.cancelInFlight()
        }
    }

    private var showsClear: Bool {
        recipes.showsResults || !ingredients.chips.isEmpty || !ingredients.draft.isEmpty
    }

    private var searchField: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 16, weight: .regular))
                .foregroundStyle(Theme.subtle(for: colorScheme))
            TextField(
                "",
                text: $ingredients.draft,
                prompt: Text("Search recipes, ingredients, cooks…").foregroundStyle(Theme.subtle(for: colorScheme))
            )
            .font(.system(size: 14.5))
            .foregroundStyle(colorScheme == .dark ? Theme.textDark : Theme.textLight)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .submitLabel(.return)
            .focused($fieldFocused)
            // Return adds the text as a chip and keeps the keyboard up for the next one.
            .onSubmit {
                ingredients.submitDraft()
                fieldFocused = true
            }
            .accessibilityLabel(Text("Search recipes, ingredients, cooks"))
            if showsClear {
                Button {
                    ingredients.clear()
                    recipes.clear()
                } label: {
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

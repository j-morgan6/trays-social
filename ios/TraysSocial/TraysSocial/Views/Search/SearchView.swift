import SwiftUI

/// Recipe-first Search tab with one search box (W205), restyled to the
/// redesign canvas in W243.
///
/// Return turns the typed text into an ingredient chip. Browse tiles and Most
/// saved show before typing; one term (typed or a single chip) shows grouped
/// results with "See all" (`SearchRecipesSection`); two or more ingredients
/// show "You have everything" / "Almost there" (`IngredientMatchResults`).
/// `IngredientSearchViewModel.route` makes that call.
///
/// Children inset themselves by `HomeMetrics.inset` (the canvas's 18pt), so
/// horizontal rows can bleed to the screen edge where the canvas does.
struct SearchView: View {
    @State private var recipes = SearchViewModel()
    @State private var ingredients = IngredientSearchViewModel()
    @FocusState private var fieldFocused: Bool
    /// View-local: Browse has been asked for at least once. A finished first
    /// load with nothing to show is a failure (the view models only log).
    @State private var browseAttempted = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                SearchField(
                    text: $ingredients.draft,
                    isFocused: $fieldFocused,
                    showsClear: showsClear,
                    onSubmit: {
                        // Return adds the text as a chip and keeps the keyboard up.
                        ingredients.submitDraft()
                        fieldFocused = true
                    },
                    onClear: {
                        ingredients.clear()
                        recipes.clear()
                    }
                )
                .padding(.horizontal, HomeMetrics.inset)
                IngredientChipBar(viewModel: ingredients)

                if ingredients.isMatchingIngredients {
                    IngredientMatchResults(viewModel: ingredients)
                } else {
                    SearchRecipesSection(
                        viewModel: recipes,
                        browseFailed: browseFailed,
                        onRetryBrowse: { Task { await recipes.loadBrowse() } }
                    )
                }
            }
            .padding(.top, 116)
            .padding(.bottom, 128)
        }
        .background(Theme.background)
        .task {
            await recipes.loadBrowseIfNeeded()
            // A cancelled load (the tab was left mid-load) is not a failure.
            if !Task.isCancelled {
                browseAttempted = true
            }
        }
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

    private var browseFailed: Bool {
        SearchBrowseState.failed(
            attempted: browseAttempted,
            hasBrowse: recipes.browse != nil,
            isLoading: recipes.isLoadingBrowse
        )
    }
}

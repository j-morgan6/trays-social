import SwiftUI

/// Picks a saved recipe to plan on a given day.
///
/// The list is `MyTrayViewModel.savedRecipes` — the user's own posts merged
/// with their bookmarks, filtered to `type == "recipe"`. That is an exact
/// match for the server's eligibility rule (owned OR bookmarked), so there is
/// no second source of truth to keep in step. Non-recipe posts are excluded
/// because only recipes carry ingredients, and planning one would create an
/// entry that can never contribute to the grocery list.
struct RecipePickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    let day: PlannerDay
    let recipes: [Post]
    let isLoading: Bool
    /// Recipes already planned on this day. Belt-and-braces with
    /// `PlanValidation.duplicate` — the DB has a unique index on
    /// (user, date, post) — but this is the version the user experiences.
    let alreadyPlanned: Set<Int>
    let onPick: (Post) -> Void

    @State private var query = ""

    var body: some View {
        NavigationStack {
            Group {
                if isLoading, recipes.isEmpty {
                    ProgressView()
                        .tint(.gray)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if filtered.isEmpty {
                    EditorialEmptyState(
                        title: String(localized: "No recipes to plan"),
                        subtitle: String(localized: "Save a recipe to your tray first.")
                    )
                } else {
                    list
                }
            }
            .background(Theme.background)
            .navigationTitle(String(localized: "Choose a recipe"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "Cancel")) { dismiss() }
                }
            }
            // Filters the page already loaded. MyTrayViewModel fetches only the
            // first page of /bookmarks and has no loadMore — a pre-existing
            // limit the tray grid shares, deliberately not grown here.
            .searchable(text: $query, prompt: String(localized: "Search your recipes"))
        }
    }

    private var filtered: [Post] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return recipes }
        return recipes.filter { ($0.caption ?? "").localizedCaseInsensitiveContains(trimmed) }
    }

    private var list: some View {
        List(filtered) { post in
            let planned = alreadyPlanned.contains(post.id)
            Button {
                onPick(post)
                dismiss()
            } label: {
                RecipePickerRow(post: post, isAlreadyPlanned: planned)
            }
            .buttonStyle(.borderless)
            .disabled(planned)
            .listRowBackground(Theme.background)
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }
}

private struct RecipePickerRow: View {
    @Environment(\.colorScheme) private var colorScheme

    let post: Post
    let isAlreadyPlanned: Bool

    var body: some View {
        HStack(spacing: 10) {
            Photo(key: photoKey, url: (post.thumbURL ?? post.primaryPhotoURL)?.asBackendURL)
                .frame(width: 44, height: 44)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 14.5, weight: .semibold))
                    .foregroundStyle(colorScheme == .dark ? Theme.textDark : Theme.textLight)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                if isAlreadyPlanned {
                    Text("Already planned")
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.muted(for: colorScheme))
                }
            }

            Spacer(minLength: 0)
        }
        .padding(.vertical, 4)
        .opacity(isAlreadyPlanned ? 0.5 : 1)
        .contentShape(Rectangle())
    }

    private var photoKey: FoodPalette.Key {
        let keys = FoodPalette.Key.allCases
        return keys[abs(post.id) % keys.count]
    }

    private var title: String {
        RecipeTitle.from(caption: post.caption)
    }
}

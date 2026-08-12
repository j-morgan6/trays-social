import SwiftUI

/// The week's shopping checklist, grouped per planned recipe.
///
/// **Deliberately plain.** Items are never merged across recipes, quantities
/// are never summed or converted, and there is no share sheet, export, or
/// shoppable link anywhere — a grocery list that turns into a storefront is
/// exactly what the product's north star rules out. There is also no
/// "3 of 8 checked" counter: it is not aggregation in spirit, but it is the
/// cheapest thing to misread as one and it buys nothing.
struct GroceryListView: View {
    let viewModel: MealPlannerViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            if viewModel.groceryGroups.isEmpty {
                EditorialEmptyState(
                    title: String(localized: "Your grocery list is empty"),
                    subtitle: String(localized: "Plan a recipe to build your list.")
                )
            } else if !viewModel.hasGroceryItems {
                // Distinct from the empty case: recipes ARE planned, they just
                // carry no ingredient lines. Nothing the user can act on, so
                // the copy must not tell them to plan more.
                EditorialEmptyState(
                    title: String(localized: "Nothing to shop for"),
                    subtitle: String(localized: "Your planned recipes don't list ingredients.")
                )
            } else {
                ForEach(viewModel.groceryGroups) { group in
                    GroceryRecipeSection(
                        group: group,
                        onToggle: { key, checked in
                            viewModel.toggleCheck(itemKey: key, to: checked)
                        }
                    )
                }
            }
        }
        .padding(.horizontal, 20)
    }
}

/// One recipe's ingredients.
private struct GroceryRecipeSection: View {
    @Environment(\.colorScheme) private var colorScheme

    let group: GroceryGroup
    let onToggle: (String, Bool) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Photo(key: photoKey, url: group.post.thumbURL)
                    .frame(width: 34, height: 34)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                Text(group.post.title)
                    .font(.system(size: 15, weight: .bold))
                    .tracking(-0.3)
                    .foregroundStyle(colorScheme == .dark ? Theme.textDark : Theme.textLight)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                Spacer(minLength: 0)
            }

            ForEach(group.items) { item in
                GroceryItemRow(item: item, onToggle: { onToggle(item.itemKey, !item.checked) })
            }
        }
    }

    private var photoKey: FoodPalette.Key {
        let keys = FoodPalette.Key.allCases
        return keys[abs(group.post.id) % keys.count]
    }
}

/// One ingredient line with its checkbox.
///
/// Checking is a write, but it is never gated server-side — a lapsed
/// subscriber keeps ticking items off. So no `PlusGate` here, by contract.
private struct GroceryItemRow: View {
    @Environment(\.colorScheme) private var colorScheme

    let item: GroceryItem
    let onToggle: () -> Void

    var body: some View {
        Button(action: onToggle) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Image(systemName: item.checked ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 17, weight: .regular))
                    .foregroundStyle(
                        item.checked
                            ? Theme.accentInk(for: colorScheme)
                            : Theme.muted(for: colorScheme).opacity(0.55)
                    )

                Text(label)
                    .font(.system(size: 14.5))
                    .foregroundStyle(
                        item.checked
                            ? Theme.muted(for: colorScheme)
                            : (colorScheme == .dark ? Theme.textDark : Theme.textLight)
                    )
                    .strikethrough(item.checked, color: Theme.muted(for: colorScheme))
                    .multilineTextAlignment(.leading)

                Spacer(minLength: 0)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.borderless)
        .accessibilityAddTraits(item.checked ? [.isButton, .isSelected] : .isButton)
    }

    /// The recipe's own words, joined verbatim. `measure` is string
    /// concatenation of the server's quantity and unit — no parsing, no math.
    private var label: String {
        guard let measure = item.measure else { return item.name }
        return "\(measure) \(item.name)"
    }
}

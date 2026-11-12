import SwiftUI

// MARK: - Recipe Body

/// W247: the recipe's Ingredients, Steps and Tools (Recipe artboard). When a
/// recipe has both ingredients and steps, an Ingredients / Steps switch
/// shows one at a time, as the artboard draws it; tools sit under the
/// ingredients. Ingredients sit in one card and tick off as the cook goes;
/// the ticks are local to this screen (`IngredientTicks`) and never saved.
/// Each step is its own card with an amber numeral.
struct RecipeBodySection: View {
    enum Tab: Hashable {
        case ingredients
        case steps
    }

    let post: Post
    @State private var ticks = IngredientTicks()
    @State private var tab: Tab = .ingredients

    private var hasIngredientsTab: Bool {
        !post.ingredients.isEmpty || !post.tools.isEmpty
    }

    private var showsSwitch: Bool {
        hasIngredientsTab && !post.cookingSteps.isEmpty
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if showsSwitch {
                SegmentedPills(
                    options: [
                        .init(value: Tab.ingredients, title: String(localized: "Ingredients")),
                        .init(value: Tab.steps, title: String(localized: "Steps")),
                    ],
                    selection: $tab
                )
                .padding(.top, 8)
            }

            if !showsSwitch || tab == .ingredients {
                ingredientsTab
            }
            if !showsSwitch || tab == .steps, !post.cookingSteps.isEmpty {
                methodList
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func heading(_ title: LocalizedStringKey) -> some View {
        Text(title)
            .roundedFont(20, weight: .heavy, relativeTo: .title3)
            .foregroundStyle(Theme.text)
            .accessibilityAddTraits(.isHeader)
    }

    @ViewBuilder
    private var ingredientsTab: some View {
        if !post.ingredients.isEmpty {
            ingredientsList
        }
        if !post.tools.isEmpty {
            toolsList
                .padding(.top, 12)
        }
    }

    private var ingredientsList: some View {
        VStack(alignment: .leading, spacing: 12) {
            if !showsSwitch {
                heading("Ingredients")
            }

            VStack(spacing: 0) {
                // Index keys: Ingredient.id repeats for duplicate rows.
                ForEach(Array(post.ingredients.enumerated()), id: \.offset) { index, ingredient in
                    if index > 0 {
                        Rectangle().fill(Theme.hairline).frame(height: 1)
                    }
                    IngredientTickRow(
                        quantity: Self.quantityText(for: ingredient),
                        name: ingredient.name,
                        isTicked: ticks.isTicked(index),
                        onToggle: { ticks.toggle(index) }
                    )
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 4)
            .cardSurface(cornerRadius: 22)
        }
    }

    private var methodList: some View {
        VStack(alignment: .leading, spacing: 12) {
            if !showsSwitch {
                heading("Steps")
            }

            ForEach(Array(post.cookingSteps.enumerated()), id: \.offset) { _, step in
                MethodStepCard(number: step.position, instruction: step.instruction)
            }
        }
    }

    private var toolsList: some View {
        VStack(alignment: .leading, spacing: 12) {
            heading("Tools")

            FlowLayout(spacing: 8) {
                ForEach(Array(post.tools.enumerated()), id: \.offset) { _, tool in
                    Text(tool.name)
                        .scaledFont(13, weight: .semibold, relativeTo: .footnote)
                        .foregroundStyle(Theme.primaryInk)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(Capsule(style: .continuous).fill(Theme.mintTint))
                }
            }
        }
    }

    static func quantityText(for ingredient: Ingredient) -> String {
        [ingredient.quantity, ingredient.unit]
            .compactMap { $0?.isEmpty == false ? $0 : nil }
            .joined(separator: " ")
    }
}

/// W247: one ingredient line. The whole row is the tick target: a 26pt
/// ring that fills emerald with a white check, and the line strikes through.
struct IngredientTickRow: View {
    static let ringSize: CGFloat = 26

    let quantity: String
    let name: String
    let isTicked: Bool
    let onToggle: () -> Void

    var body: some View {
        Button(action: onToggle) {
            HStack(alignment: .center, spacing: 14) {
                TickRing(isTicked: isTicked)

                if !quantity.isEmpty {
                    Text(quantity)
                        .strikethrough(isTicked, color: Theme.muted)
                        .scaledFont(15.5, weight: .bold, relativeTo: .body)
                        .foregroundStyle(isTicked ? Theme.muted : Theme.text)
                        .frame(minWidth: 68, alignment: .leading)
                }

                Text(name)
                    .strikethrough(isTicked, color: Theme.muted)
                    .scaledFont(15.5, relativeTo: .body)
                    .foregroundStyle(isTicked ? Theme.muted : Theme.text)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.vertical, 12)
            .frame(minHeight: 54)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(quantity.isEmpty ? name : "\(quantity) \(name)"))
        .accessibilityAddTraits(isTicked ? [.isButton, .isSelected] : .isButton)
    }
}

/// The tick ring: a strong hairline ring, filled emerald with a white check
/// once ticked (Components token map).
struct TickRing: View {
    let isTicked: Bool

    var body: some View {
        ZStack {
            if isTicked {
                Circle().fill(Theme.primary)
                Image(systemName: "checkmark")
                    .font(.system(size: 12, weight: .heavy))
                    .foregroundStyle(Theme.onPrimary)
            } else {
                Circle().strokeBorder(Theme.hairlineStrong, lineWidth: 2)
            }
        }
        .frame(width: IngredientTickRow.ringSize, height: IngredientTickRow.ringSize)
        .accessibilityHidden(true)
    }
}

/// W247: one method step on its own card.
struct MethodStepCard: View {
    static let discSize: CGFloat = 32

    let number: Int
    let instruction: String

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Text(verbatim: "\(number)")
                .roundedFont(15, weight: .heavy, relativeTo: .subheadline)
                .foregroundStyle(Theme.text)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .frame(width: Self.discSize, height: Self.discSize)
                .background(Circle().fill(Theme.accentMuted))
                .accessibilityHidden(true)

            Text(instruction)
                .scaledFont(16, relativeTo: .body)
                .foregroundStyle(Theme.text)
                .lineSpacing(3)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .cardSurface(cornerRadius: 20)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text("Step \(number). \(instruction)"))
    }
}

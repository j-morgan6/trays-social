import SwiftUI

/// W249: the editor's Preview (Create artboard, state 4): the recipe as
/// others will see it, before posting, built from the recipe detail's own
/// title block, meta row, cook's note and step cards (listed in one scroll
/// rather than behind the detail's Ingredients / Steps switch). Post from here, or go
/// back to editing. Nothing here is sent until Post.
struct RecipeDraftPreview: View {
    let draft: RecipeDraft
    let photo: Image?
    let onBack: () -> Void
    let onPost: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            topBar
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    photoBlock
                    head
                }
            }
        }
        .background(Theme.background.ignoresSafeArea())
        .accessibilityAddTraits(.isModal)
        .accessibilityAction(.escape, onBack)
    }

    private var topBar: some View {
        HStack {
            Button(String(localized: "Back to editing"), action: onBack)
            Spacer(minLength: 12)
            Button(String(localized: "Post"), action: onPost)
        }
        .scaledFont(16, weight: .semibold, relativeTo: .body)
        .foregroundStyle(Theme.primaryInk)
        .buttonStyle(.plain)
        .frame(minHeight: 44)
        .padding(.horizontal, 20)
        .padding(.vertical, 6)
        .background(Theme.background)
        .overlay(alignment: .bottom) {
            Rectangle().fill(Theme.hairlineStrong).frame(height: 1)
        }
    }

    private var photoBlock: some View {
        Theme.creamOrLift
            .aspectRatio(4 / 5, contentMode: .fit)
            .overlay {
                if let photo {
                    photo.resizable().scaledToFill()
                } else {
                    Text("No photo yet")
                        .scaledFont(13, weight: .semibold, relativeTo: .footnote)
                        .foregroundStyle(Theme.muted)
                }
            }
            .clipped()
            .accessibilityHidden(true)
    }

    private var head: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label(String(localized: "Preview · only you can see this"), systemImage: "eye")
                .scaledFont(12.5, weight: .bold, relativeTo: .caption)
                .foregroundStyle(Theme.text)
                .padding(.vertical, 5)
                .padding(.horizontal, 11)
                .background(Capsule(style: .continuous).fill(Theme.accentMuted))
            RecipeTitleBlock(kicker: draft.kicker, title: draft.title)
            HStack(spacing: 8) {
                AvatarSlot(url: nil, size: 22)
                Text("You")
                    .scaledFont(14, weight: .semibold, relativeTo: .subheadline)
                    .foregroundStyle(Theme.text)
            }
            if !draft.capsules.isEmpty {
                RecipeMetaRow(capsules: draft.capsules)
            }
            if !draft.note.isEmpty {
                CookNote(label: String(localized: "From you"), text: draft.note)
            }
            if !draft.ingredients.isEmpty {
                sectionTitle(String(localized: "Ingredients"))
                VStack(spacing: 0) {
                    ForEach(Array(draft.ingredients.enumerated()), id: \.offset) { _, ingredient in
                        ingredientRow(ingredient)
                    }
                }
            }
            if !draft.tools.isEmpty {
                sectionTitle(String(localized: "Tools"))
                FlowLayout(spacing: 8) {
                    ForEach(Array(draft.tools.enumerated()), id: \.offset) { _, tool in
                        Text(tool)
                            .scaledFont(13, weight: .semibold, relativeTo: .footnote)
                            .foregroundStyle(Theme.primaryInk)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 7)
                            .background(Capsule(style: .continuous).fill(Theme.mintTint))
                    }
                }
            }
            if !draft.steps.isEmpty {
                sectionTitle(String(localized: "Steps"))
                VStack(spacing: 10) {
                    ForEach(Array(draft.steps.enumerated()), id: \.offset) { index, step in
                        MethodStepCard(number: index + 1, instruction: step)
                    }
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 22)
        .padding(.bottom, 32)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            UnevenRoundedRectangle(topLeadingRadius: 26, topTrailingRadius: 26, style: .continuous)
                .fill(Theme.background)
        )
        .offset(y: -26)
        .padding(.bottom, -26)
    }

    private func sectionTitle(_ text: String) -> some View {
        Text(text)
            .roundedFont(18, weight: .heavy, relativeTo: .headline)
            .foregroundStyle(Theme.text)
            .accessibilityAddTraits(.isHeader)
            .padding(.top, 6)
    }

    private func ingredientRow(_ ingredient: RecipeDraft.Ingredient) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            if !ingredient.amount.isEmpty {
                Text(ingredient.amount)
                    .scaledFont(15.5, weight: .semibold, relativeTo: .body)
                    .frame(minWidth: 70, alignment: .leading)
            }
            Text(ingredient.name)
                .scaledFont(15.5, relativeTo: .body)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .foregroundStyle(Theme.text)
        .padding(.vertical, 10)
        .overlay(alignment: .bottom) {
            Rectangle().fill(Theme.hairline).frame(height: 1)
        }
        .accessibilityElement(children: .combine)
    }
}

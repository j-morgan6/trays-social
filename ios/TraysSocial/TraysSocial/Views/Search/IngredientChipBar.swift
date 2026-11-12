import SwiftUI

/// Sits under the single search box (W205): the ingredient chips, a hint
/// that return adds a chip, the chip limit, and recently used chips.
///
/// W243: chips wrap (canvas "Chips") using the shared `IngredientChip` and
/// `RecentChip`. Also shown by the classic `FindView`. Insets itself by
/// `HomeMetrics.inset`.
struct IngredientChipBar: View {
    let viewModel: IngredientSearchViewModel

    private var isTyping: Bool {
        !viewModel.draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if !viewModel.chips.isEmpty {
                FlowLayout(spacing: 8) {
                    ForEach(viewModel.chips, id: \.self) { chip in
                        IngredientChip(name: chip) { viewModel.removeChip(chip) }
                    }
                }
                .padding(.top, 12)
            }
            if !viewModel.canAddMore {
                note(String(localized: "Up to 10 ingredients"))
            } else if viewModel.chips.count < 2, isTyping || !viewModel.chips.isEmpty {
                note(String(localized: "Press return to add an ingredient. Add two or more to see what you can make."))
            }
            if !viewModel.suggestions.isEmpty, !isTyping, viewModel.canAddMore {
                recent
            }
        }
        .padding(.horizontal, HomeMetrics.inset)
    }

    private func note(_ text: String) -> some View {
        Text(text)
            .scaledFont(13, relativeTo: .footnote)
            .foregroundStyle(Theme.muted)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.top, 10)
            .padding(.horizontal, 4)
    }

    private var recent: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Recently used")
                .roundedFont(15, weight: .bold, relativeTo: .subheadline)
                .foregroundStyle(Theme.text)
                .accessibilityAddTraits(.isHeader)
            FlowLayout(spacing: 8) {
                ForEach(viewModel.suggestions, id: \.self) { chip in
                    RecentChip(name: chip) { viewModel.addChip(chip) }
                }
            }
        }
        .padding(.top, 18)
    }
}

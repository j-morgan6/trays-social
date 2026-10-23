import SwiftUI

/// Sits under the single search box (W205): the ingredient chip row, a hint
/// that return adds a chip, the chip limit, and recently used chips.
///
/// Pads its own content (16pt) like the other search sections, because
/// `SectionHeader` carries a built-in 20pt inset; outer padding would double it.
struct IngredientChipBar: View {
    @Environment(\.colorScheme) private var colorScheme
    let viewModel: IngredientSearchViewModel

    private var isTyping: Bool {
        !viewModel.draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if !viewModel.chips.isEmpty {
                chipRow
            }
            if !viewModel.canAddMore {
                note(String(localized: "Up to 10 ingredients"))
            } else if viewModel.chips.count < 2, isTyping || !viewModel.chips.isEmpty {
                note(String(localized: "Press return to add an ingredient. Add two or more to see what you can make."))
            }
            if !viewModel.suggestions.isEmpty, !isTyping, viewModel.canAddMore {
                recentRow
            }
        }
    }

    private func note(_ text: String) -> some View {
        Text(text)
            .font(.footnote)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 16)
    }

    private var chipRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(viewModel.chips, id: \.self) { chip in
                    Button { viewModel.removeChip(chip) } label: {
                        HStack(spacing: 4) {
                            Text(chip)
                            Image(systemName: "xmark").font(.system(size: 10, weight: .bold))
                        }
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Theme.accentInk(for: colorScheme))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Capsule().fill(Theme.accentMuted))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(Text("Remove \(chip)"))
                }
            }
            .padding(.horizontal, 16)
        }
    }

    private var recentRow: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader(label: String(localized: "Recently used"))
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(viewModel.suggestions, id: \.self) { chip in
                        FilterChip(label: "+ \(chip)", isActive: false) { viewModel.addChip(chip) }
                    }
                }
                .padding(.horizontal, 16)
            }
        }
    }
}

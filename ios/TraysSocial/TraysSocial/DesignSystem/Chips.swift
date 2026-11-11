import SwiftUI

/// W239: an ingredient chip under the search field (Components artboard,
/// "Chips"). Amber-muted capsule with an amber ring; the remove control has
/// a 32pt hit area.
struct IngredientChip: View {
    let name: String
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: 2) {
            Text(name)
                .scaledFont(14.5, weight: .semibold, relativeTo: .subheadline)
                .foregroundStyle(Theme.text)
                .lineLimit(1)
            Button(action: onRemove) {
                Image(systemName: "xmark")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Theme.text)
                    .frame(width: 32, height: 32)
            }
            .buttonStyle(ChipRemoveButtonStyle())
            .accessibilityLabel(String(localized: "Remove \(name)"))
        }
        .padding(.leading, 15)
        .padding(.trailing, 4)
        .frame(minHeight: 40)
        .background(Capsule(style: .continuous).fill(Theme.accentMuted))
        .overlay(Capsule(style: .continuous).strokeBorder(Theme.accentBorder, lineWidth: 1))
    }
}

private struct ChipRemoveButtonStyle: ButtonStyle {
    func makeBody(configuration: ButtonStyleConfiguration) -> some View {
        configuration.label
            .background(Circle().fill(configuration.isPressed ? Theme.accentPressed : .clear))
            .contentShape(Circle())
    }
}

/// W239: a "Recently used" ingredient chip with a plus, shown when the
/// search field is empty.
struct RecentChip: View {
    let name: String
    let onAdd: () -> Void

    var body: some View {
        Button(action: onAdd) {
            HStack(spacing: 6) {
                Image(systemName: "plus")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Theme.primaryInk)
                    .accessibilityHidden(true)
                Text(name)
                    .scaledFont(14.5, weight: .medium, relativeTo: .subheadline)
                    .foregroundStyle(Theme.text)
                    .lineLimit(1)
            }
            .padding(.leading, 12)
            .padding(.trailing, 15)
            .frame(minHeight: 40)
            .background(Capsule(style: .continuous).fill(Theme.surface))
            .overlay(Capsule(style: .continuous).strokeBorder(Theme.border, lineWidth: 1))
            .contentShape(Capsule(style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(String(localized: "Add \(name)"))
    }
}

private struct ChipsGallery: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                IngredientChip(name: "chicken") {}
                IngredientChip(name: "rice") {}
            }
            HStack(spacing: 8) {
                RecentChip(name: "garlic") {}
                RecentChip(name: "eggs") {}
            }
        }
        .padding()
        .background(Theme.background)
    }
}

#Preview("Chips · light") {
    ChipsGallery().preferredColorScheme(.light)
}

#Preview("Chips · dark") {
    ChipsGallery().preferredColorScheme(.dark)
}

#Preview("Chips · largest text") {
    ChipsGallery().dynamicTypeSize(.accessibility5)
}

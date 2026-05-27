import SwiftUI

/// Filter chip used in `FindView`'s horizontal chip row. Mirrors the
/// prototype's chip styling at prototype.jsx lines 588-609:
///
/// - **Active**  – `Theme.accentMuted` fill (rgba(255,179,0,0.25)),
///   `Theme.accentInk(for:)` label, 600 weight, 1pt accent-border
///   stroke.
/// - **Inactive** – `Theme.surface` fill, primary text label, 500
///   weight, 1pt hairline stroke.
///
/// Multiple chips can be active simultaneously — the parent owns the
/// selection set and toggles via `onTap`.
struct FilterChip: View {
    @Environment(\.colorScheme) private var colorScheme
    let label: String
    let isActive: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            Text(label)
                .font(.system(size: 13, weight: isActive ? .semibold : .medium))
                .tracking(-0.065)
                .foregroundStyle(labelColor)
                .padding(.horizontal, 14)
                .frame(height: 34)
                .background(
                    Capsule(style: .continuous).fill(backgroundFill)
                )
                .overlay(
                    Capsule(style: .continuous)
                        .stroke(strokeColor, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .accessibilityAddTraits(isActive ? [.isSelected, .isButton] : .isButton)
    }

    private var labelColor: Color {
        if isActive { return Theme.accentInk(for: colorScheme) }
        return colorScheme == .dark ? Theme.textDark : Theme.textLight
    }

    private var backgroundFill: Color {
        isActive ? Theme.accentMuted : Theme.surface
    }

    private var strokeColor: Color {
        isActive ? Theme.accentBorder : Theme.hairline(for: colorScheme)
    }
}

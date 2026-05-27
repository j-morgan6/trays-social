import SwiftUI

/// Single tab segment inside `TopPill`. Three of these sit side-by-side
/// for Feed / My Tray / Find.
///
/// State styling matches the Pass 1 prototype:
/// - Active:  `Theme.accentMuted` fill, full-opacity `Theme.text*` label,
///            `.semibold` weight, and `[.isSelected, .isButton]`
///            accessibility traits so VoiceOver reads "selected".
/// - Inactive: clear fill, muted label, regular weight, `.isButton` only.
/// - Pressed: `Theme.accentPressed` fill (40% amber) during the touch.
///
/// Communicates active state via both color AND weight per the
/// accessibility rule that color must never be the sole signal.
struct TabSegment: View {
    @Environment(\.colorScheme) private var colorScheme
    let label: String
    let isActive: Bool
    let action: () -> Void

    @State private var isPressed = false

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 14, weight: isActive ? .semibold : .regular))
                .foregroundStyle(activeLabelColor)
                .frame(maxWidth: .infinity, minHeight: 44)
                .background(
                    Capsule(style: .continuous)
                        .fill(backgroundFill)
                )
        }
        .buttonStyle(.plain)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in isPressed = true }
                .onEnded { _ in isPressed = false }
        )
        .accessibilityLabel(label)
        .accessibilityAddTraits(isActive ? [.isSelected, .isButton] : .isButton)
    }

    private var activeLabelColor: Color {
        if isActive {
            colorScheme == .dark ? Theme.textDark : Theme.textLight
        } else {
            Theme.muted(for: colorScheme)
        }
    }

    private var backgroundFill: Color {
        if isPressed, isActive {
            Theme.accentPressed
        } else if isPressed {
            Theme.accentMuted.opacity(0.5)
        } else if isActive {
            Theme.accentMuted
        } else {
            .clear
        }
    }
}

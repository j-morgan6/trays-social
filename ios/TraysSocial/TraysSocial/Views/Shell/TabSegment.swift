import SwiftUI

/// Single tab segment inside `TopPill`. Three of these sit side-by-side
/// for Home / My Tray / Search (or Feed / My Tray / Find).
///
/// W239 (redesign canvas, "Floating pills"):
/// - Active:  emerald (`Theme.primary`) capsule, white label (cream in
///            dark), `.semibold`, and `[.isSelected, .isButton]`
///            accessibility traits so VoiceOver reads "selected".
/// - Inactive: clear fill, muted label, medium weight, `.isButton` only.
/// - Pressed: `Theme.primaryLight` when active, a lift capsule otherwise.
///
/// Communicates active state via both color AND weight per the
/// accessibility rule that color must never be the sole signal.
struct TabSegment: View {
    let label: LocalizedStringKey
    let isActive: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .scaledFont(14, weight: isActive ? .semibold : .medium, relativeTo: .subheadline)
                .padding(.horizontal, 15)
                .frame(minHeight: 44)
        }
        .buttonStyle(TabSegmentStyle(isActive: isActive))
        .accessibilityLabel(label)
        .accessibilityShowsLargeContentViewer()
        .accessibilityAddTraits(isActive ? [.isSelected, .isButton] : .isButton)
    }
}

private struct TabSegmentStyle: ButtonStyle {
    let isActive: Bool

    func makeBody(configuration: ButtonStyleConfiguration) -> some View {
        configuration.label
            .foregroundStyle(isActive ? Theme.onPrimary : Theme.muted)
            .background {
                Capsule(style: .continuous)
                    .fill(fill(isPressed: configuration.isPressed))
                    .padding(.vertical, 3)
            }
            .contentShape(Capsule(style: .continuous))
    }

    private func fill(isPressed: Bool) -> Color {
        if isActive {
            isPressed ? Theme.primaryLight : Theme.primary
        } else if isPressed {
            Theme.lift
        } else {
            .clear
        }
    }
}

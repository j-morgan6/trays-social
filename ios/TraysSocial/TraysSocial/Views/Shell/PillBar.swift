import SwiftUI

/// Reusable floating-pill container for the nav shell.
///
/// Applies the Pass 1 prototype's pill chrome:
/// `.ultraThinMaterial` backdrop + a tinted `Theme.pillBg(for:)` fill
/// (light: rgba(255,255,255,0.78), dark: rgba(32,32,30,0.72)) + a 1pt
/// hairline stroke + a 22pt-corner capsule shape. The content is
/// horizontally laid out by callers; this container only owns chrome.
///
/// Both TopPill and BottomPill wrap their contents in a PillBar so the
/// shell stays visually coherent across the two surfaces.
struct PillBar<Content: View>: View {
    @Environment(\.colorScheme) private var colorScheme
    @ViewBuilder let content: () -> Content

    var body: some View {
        HStack(spacing: 8) {
            content()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            ZStack {
                Capsule(style: .continuous)
                    .fill(.ultraThinMaterial)
                Capsule(style: .continuous)
                    .fill(Theme.pillBg(for: colorScheme))
            }
        )
        .overlay(
            Capsule(style: .continuous)
                .stroke(Theme.hairline(for: colorScheme), lineWidth: 1)
        )
        .clipShape(Capsule(style: .continuous))
    }
}

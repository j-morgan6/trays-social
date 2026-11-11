import SwiftUI

/// Reusable floating-pill container for the nav shell.
///
/// W239 (redesign canvas, "Floating pills"): `.ultraThinMaterial` tinted
/// with `Theme.pill` (light rgba(255,255,255,0.78), dark
/// rgba(32,32,30,0.72)), an inset strong hairline, and a soft shadow. The
/// content is laid out horizontally by callers; this container only owns
/// chrome.
///
/// TopPill (tabs and bell) and BottomPill (Create and avatar) wrap their
/// contents in a PillBar so the shell stays visually coherent.
struct PillBar<Content: View>: View {
    var horizontalPadding: CGFloat = 4
    var verticalPadding: CGFloat = 1
    var spacing: CGFloat = 2
    @ViewBuilder let content: () -> Content

    var body: some View {
        HStack(spacing: spacing) {
            content()
        }
        .padding(.horizontal, horizontalPadding)
        .padding(.vertical, verticalPadding)
        .background {
            ZStack {
                Capsule(style: .continuous).fill(.ultraThinMaterial)
                Capsule(style: .continuous).fill(Theme.pill)
            }
        }
        .overlay(Capsule(style: .continuous).strokeBorder(Theme.hairlineStrong, lineWidth: 1))
        .clipShape(Capsule(style: .continuous))
        .shadow(color: Theme.shadow, radius: 12, y: 8)
    }
}

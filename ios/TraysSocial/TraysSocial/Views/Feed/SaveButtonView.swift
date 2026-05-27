import SwiftUI

/// Bookmark toggle for FeedCardView. Mirrors the prototype's
/// `SaveButton` (prototype.jsx lines 405-440):
/// - Unsaved → outline "+" on a 32pt circle with translucent dark fill.
/// - Saved → filled "bookmark.fill" on a 32pt amber circle with a soft
///   amber drop shadow.
///
/// Toggling to saved runs the **savePop** animation: a 380ms spring with
/// a slight overshoot (matches the prototype's
/// `cubic-bezier(.34,1.56,.64,1)`). Toggling to unsaved runs **saveOut**
/// — a faster 240ms ease without spring. Reduce Motion bypasses both
/// animations entirely (instant icon swap).
///
/// The button does NOT call the network itself. It exposes an `onSave`
/// closure receiving the new saved state and lets the parent ViewModel
/// handle the API call optimistically.
struct SaveButtonView: View {
    let isSaved: Bool
    let onSave: (Bool) -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var didInitialize = false
    @State private var iconScale: CGFloat = 1.0

    var body: some View {
        Button(action: handleTap) {
            ZStack {
                Circle()
                    .fill(isSaved ? Theme.accent : Color.black.opacity(0.42))
                    .frame(width: 32, height: 32)
                    .shadow(
                        color: isSaved ? Theme.accent.opacity(0.35) : Color.black.opacity(0.25),
                        radius: isSaved ? 6 : 2,
                        y: isSaved ? 4 : 1
                    )

                Image(systemName: isSaved ? "bookmark.fill" : "plus")
                    .font(.system(size: isSaved ? 14 : 16, weight: .semibold))
                    .foregroundStyle(isSaved ? Theme.inkOnAccent : Color.white)
                    .scaleEffect(iconScale)
                    .id(isSaved)
                    .transition(.opacity)
            }
            .frame(width: 44, height: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isSaved ? "Saved" : "Save to tray")
        .onAppear { didInitialize = true }
    }

    private func handleTap() {
        let next = !isSaved
        onSave(next)

        guard didInitialize, !reduceMotion else { return }

        if next {
            iconScale = 0.6
            withAnimation(.spring(response: 0.38, dampingFraction: 0.55, blendDuration: 0)) {
                iconScale = 1.0
            }
        } else {
            iconScale = 1.15
            withAnimation(.easeOut(duration: 0.24)) {
                iconScale = 1.0
            }
        }
    }
}

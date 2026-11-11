import SwiftUI

// MARK: - Primitives

/// A rounded rectangle used as a loading placeholder. W239: a lift fill
/// that pulses from full to half opacity over 1.5s (static with Reduce
/// Motion) instead of the old translating shimmer. All skeleton shapes are
/// .accessibilityHidden so VoiceOver doesn't announce each rectangle —
/// wrap a group in `.skeletonGroup(label:)` to announce the load state once.
struct SkeletonShape: View {
    var width: CGFloat?
    var height: CGFloat = 0
    var cornerRadius: CGFloat = 8
    /// When set, the shape sizes to this width:height aspect ratio and
    /// `height` is ignored — used for full-width photo blocks that must
    /// match an aspect-ratio'd real image (e.g. the 1:1 feed photo).
    var aspectRatio: CGFloat?
    var fill: Color = Theme.lift

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous).fill(fill)
        Group {
            if let aspectRatio {
                shape.aspectRatio(aspectRatio, contentMode: .fit)
            } else {
                shape.frame(width: width, height: height)
            }
        }
        .skeletonPulse()
        .accessibilityHidden(true)
    }
}

/// A circular skeleton placeholder, sized to match avatar dimensions.
struct SkeletonCircle: View {
    var size: CGFloat
    var fill: Color = Theme.lift

    var body: some View {
        Circle()
            .fill(fill)
            .frame(width: size, height: size)
            .skeletonPulse()
            .accessibilityHidden(true)
    }
}

/// W239: opacity 1 to 0.5 and back over 1.5s. Reduce Motion keeps the
/// placeholder static, per the app-flow Reduce Motion table.
enum SkeletonPulseOpacity {
    static func value(reduceMotion: Bool, dimmed: Bool) -> Double {
        reduceMotion || !dimmed ? 1 : 0.5
    }
}

private struct SkeletonPulse: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var dimmed = false

    func body(content: Content) -> some View {
        content
            .opacity(SkeletonPulseOpacity.value(reduceMotion: reduceMotion, dimmed: dimmed))
            .onAppear(perform: start)
            .onChange(of: reduceMotion) { _, reduced in
                if reduced {
                    var transaction = Transaction()
                    transaction.disablesAnimations = true
                    withTransaction(transaction) { dimmed = false }
                } else {
                    start()
                }
            }
    }

    private func start() {
        guard !reduceMotion else { return }
        withAnimation(.easeInOut(duration: 0.75).repeatForever(autoreverses: true)) {
            dimmed = true
        }
    }
}

extension View {
    /// Pulse a skeleton placeholder (no-op with Reduce Motion).
    func skeletonPulse() -> some View {
        modifier(SkeletonPulse())
    }
}

// MARK: - Fade wrapper

/// Wraps a skeleton cluster at a loading->content swap site so the load
/// state (a) fades in/out instead of snapping, and (b) does not flash a
/// single frame on instant (cached) loads — it only becomes visible
/// after a short delay, so a sub-180ms fetch shows no skeleton at all.
///
/// Removal is animated by the parent: put
/// `.animation(.easeInOut(duration: 0.18), value: <loadingFlag>)` on the
/// container that owns the `if <loadingFlag> { SkeletonFade { … } }`
/// branch so the `.transition(.opacity)` here fires on the way out.
///
/// Honors Reduce Motion: the fade-in is skipped (instant show) while the
/// pulse itself is already disabled in the primitives.
struct SkeletonFade<Content: View>: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ViewBuilder var content: () -> Content
    @State private var shown = false

    var body: some View {
        content()
            .opacity(shown ? 1 : 0)
            // Asymmetric so the two opacity drivers don't fight: insertion
            // is handled solely by the debounced `shown` fade below
            // (identity here), removal by the parent's
            // `.animation(value:)` driving this opacity transition.
            .transition(.asymmetric(insertion: .identity, removal: .opacity))
            .task {
                // Debounce: a fast-cached load finishes inside this window
                // and the branch is removed before `shown` ever flips, so
                // no skeleton frame is shown.
                try? await Task.sleep(for: .milliseconds(180))
                guard !Task.isCancelled else { return }
                if reduceMotion {
                    shown = true
                } else {
                    withAnimation(.easeInOut(duration: 0.18)) { shown = true }
                }
            }
    }
}

// MARK: - Group helpers

extension View {
    /// Wrap a cluster of skeletons so VoiceOver announces "Loading <thing>"
    /// once instead of stepping through each invisible rectangle.
    func skeletonGroup(label: String) -> some View {
        accessibilityElement(children: .ignore)
            .accessibilityLabel(label)
            .accessibilityAddTraits(.updatesFrequently)
    }
}

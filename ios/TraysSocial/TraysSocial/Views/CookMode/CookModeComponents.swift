import SwiftUI

// W247: the pieces of Cook mode (Recipe artboard, "Cook mode").

/// Close, "Step N of M" and the "Screen stays on" reassurance.
struct CookModeHeader: View {
    let progressLabel: String
    let onClose: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(Theme.text)
                    .frame(width: 44, height: 44)
                    .background(Circle().fill(Theme.surface))
                    .overlay(Circle().strokeBorder(Theme.hairlineStrong, lineWidth: 1))
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text("Close cook mode"))

            Text(progressLabel)
                .roundedFont(17, weight: .heavy, relativeTo: .headline)
                .foregroundStyle(Theme.text)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityAddTraits(.isHeader)

            Label(String(localized: "Screen stays on"), systemImage: "sun.max")
                .scaledFont(12.5, relativeTo: .caption)
                .foregroundStyle(Theme.muted)
                .lineLimit(1)
                .fixedSize()
        }
    }
}

/// One segment per step: amber for done and current, a strong hairline for
/// the rest (Components token map).
struct CookProgressSegments: View {
    let segments: [CookProgress.Segment]
    var reduceMotion = false

    var body: some View {
        HStack(spacing: 6) {
            ForEach(Array(segments.enumerated()), id: \.offset) { _, segment in
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .fill(Self.fill(for: segment))
                    .frame(maxWidth: .infinity)
                    .frame(height: 6)
            }
        }
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.25), value: segments)
    }

    static func fill(for segment: CookProgress.Segment) -> Color {
        switch segment {
        case .done, .current: Theme.accent
        case .upcoming: Theme.hairlineStrong
        }
    }
}

/// The Terms of Service §10 food-safety note on the first step.
struct FoodSafetyNote: View {
    var body: some View {
        // Verbatim ToS §10 wording; the localization key is the whole sentence.
        // swiftlint:disable:next line_length
        Text("Recipes are user-submitted. We don't verify ingredients, allergens, or food safety — cook at your own risk.")
            .scaledFont(13.5, relativeTo: .footnote)
            .foregroundStyle(Theme.muted)
            .fixedSize(horizontal: false, vertical: true)
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Theme.creamOrLift))
            .accessibilityAddTraits(.isStaticText)
    }
}

/// The recipe line ("Title · serves N") and the step, large enough to read
/// from the stove.
struct CookStepContent: View {
    let recipeLine: String
    let instruction: String

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text(recipeLine)
                .scaledFont(13.5, weight: .semibold, relativeTo: .subheadline)
                .foregroundStyle(Theme.muted)
                .fixedSize(horizontal: false, vertical: true)
            Text(instruction)
                .roundedFont(27, weight: .bold, relativeTo: .title)
                .foregroundStyle(Theme.text)
                .lineSpacing(6)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityElement(children: .combine)
    }
}

/// Back and an amber Next (Done cooking on the last step), 60pt high, Next
/// the wider of the two. Stacks at the largest text sizes so neither label
/// is clipped.
struct CookModeNavButtons: View {
    static let minHeight: CGFloat = 60

    let canGoBack: Bool
    let isLastStep: Bool
    let onBack: () -> Void
    let onNext: () -> Void

    var body: some View {
        ViewThatFits(in: .horizontal) {
            CookNavRow(spacing: 12) {
                backButton
                nextButton
            }
            VStack(spacing: 10) {
                nextButton
                backButton
            }
        }
    }

    private var backButton: some View {
        Button(action: onBack) {
            Text("Back")
        }
        .buttonStyle(SecondaryButtonStyle(fillsWidth: true, minHeight: Self.minHeight))
        .disabled(!canGoBack)
    }

    private var nextButton: some View {
        Button(action: onNext) {
            Text(isLastStep ? String(localized: "Done cooking") : String(localized: "Next step"))
                .lineLimit(1)
        }
        .buttonStyle(AccentButtonStyle(fillsWidth: true, minHeight: Self.minHeight))
    }
}

/// Two buttons side by side, the second 1.6 times as wide as the first (the
/// Recipe artboard's Back / Next). Measured without a proposal it reports
/// the buttons' natural widths, so `ViewThatFits` can fall back to a stack.
struct CookNavRow: Layout {
    var spacing: CGFloat = 12
    static let ratio: CGFloat = 1.6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache _: inout ()) -> CGSize {
        let ideal = subviews.map { $0.sizeThatFits(.unspecified) }
        let height = ideal.map(\.height).max() ?? 0
        guard let width = proposal.width else {
            // Natural width: wide enough that the narrower share still fits
            // its label.
            let first = ideal.first?.width ?? 0
            let second = ideal.dropFirst().first?.width ?? 0
            let unit = max(first, second / Self.ratio)
            return CGSize(width: unit * (1 + Self.ratio) + spacing, height: height)
        }
        return CGSize(width: width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal _: ProposedViewSize, subviews: Subviews, cache _: inout ()) {
        let unit = max(0, bounds.width - spacing) / (1 + Self.ratio)
        var x = bounds.minX
        for (index, subview) in subviews.enumerated() {
            let width = index == 0 ? unit : unit * Self.ratio
            subview.place(
                at: CGPoint(x: x, y: bounds.minY),
                proposal: ProposedViewSize(width: width, height: bounds.height)
            )
            x += width + spacing
        }
    }
}

/// The finished screen: a mint check, "Recipe complete" and, only when the
/// server flag is on, one sponsored card. No ads during the cooking steps.
struct CookCompletionContent: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "checkmark")
                .font(.system(size: 30, weight: .heavy))
                .foregroundStyle(Theme.primaryInk)
                .frame(width: 76, height: 76)
                .background(Circle().fill(Theme.mintTint))
                .accessibilityHidden(true)

            Text("Recipe complete")
                .roundedFont(.emptyHeadline)
                .foregroundStyle(Theme.text)
                .multilineTextAlignment(.center)

            if AdSettings.shared.config?.enabled == true {
                SponsoredCardView(slot: AdSlot(slot: 0, placement: "cook_mode_finish"))
                    .padding(.top, 8)
            }
        }
        .padding(.horizontal, 24)
        .frame(maxWidth: .infinity)
        .transition(.opacity)
    }
}

import SwiftUI

/// One selectable plan row on the paywall.
///
/// Split out of `PaywallView` to keep that struct under swiftlint's
/// `type_body_length`, and because the card is the piece most likely to be
/// restyled independently of the sheet around it.
struct PaywallPlanCard: View {
    let plan: PlanOption
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 20, style: .continuous)
        Button(action: onSelect) {
            HStack(alignment: .center, spacing: 12) {
                radio
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .scaledFont(16, weight: .bold, relativeTo: .headline)
                        .foregroundStyle(Theme.text)
                    if let trialLine {
                        Text(trialLine)
                            .scaledFont(13, weight: .semibold, relativeTo: .footnote)
                            .foregroundStyle(Theme.primaryInk)
                    }
                    // The price stays at least as prominent as the trial line:
                    // rounded, heavy and in text colour.
                    Text(priceLine)
                        .roundedFont(15, weight: .heavy, relativeTo: .subheadline)
                        .foregroundStyle(Theme.text)
                }
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(shape.fill(Theme.surface))
            // More artboard: a hairline ring at rest; selected, an amber ring
            // inside a soft amber halo.
            .overlay(
                shape.strokeBorder(
                    isSelected ? Theme.accent : Theme.hairlineStrong,
                    lineWidth: isSelected ? 2 : 1
                )
            )
            .background {
                if isSelected {
                    shape.inset(by: -2).stroke(Theme.accentMuted, lineWidth: 4)
                }
            }
            .contentShape(shape)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }

    /// A 24pt radio: a hairline circle at rest, a thick amber ring when
    /// selected.
    private var radio: some View {
        Circle()
            .strokeBorder(
                isSelected ? Theme.accent : Theme.hairlineStrong,
                lineWidth: isSelected ? 7 : 2
            )
            .frame(width: 24, height: 24)
            .accessibilityHidden(true)
    }

    private var title: String {
        plan.isYearly ? String(localized: "Yearly") : String(localized: "Monthly")
    }

    private var trialLine: String? {
        switch plan.freeTrial {
        case .week: String(localized: "First week free")
        case .month: String(localized: "First month free")
        case .other: String(localized: "Free trial included")
        case nil: nil
        }
    }

    /// Always interpolates `Product.displayPrice`, which is storefront- and
    /// locale-correct. Never a hardcoded figure.
    private var priceLine: String {
        let hasTrial = plan.freeTrial != nil
        if plan.isYearly {
            return hasTrial
                ? String(format: String(localized: "Then %@ per year"), plan.displayPrice)
                : String(format: String(localized: "%@ per year"), plan.displayPrice)
        }
        return hasTrial
            ? String(format: String(localized: "Then %@ per month"), plan.displayPrice)
            : String(format: String(localized: "%@ per month"), plan.displayPrice)
    }
}

/// Previews only. The price is a placeholder, never a figure: real prices
/// always come from StoreKit.
private struct PaywallPlanCardGallery: View {
    var body: some View {
        VStack(spacing: 10) {
            PaywallPlanCard(
                plan: PlanOption(id: "yearly", displayPrice: "[PRICE]", period: .year, freeTrial: .week),
                isSelected: true,
                onSelect: {}
            )
            PaywallPlanCard(
                plan: PlanOption(id: "monthly", displayPrice: "[PRICE]", period: .month, freeTrial: nil),
                isSelected: false,
                onSelect: {}
            )
        }
        .padding(24)
        .background(Theme.background)
    }
}

#Preview("Plan cards · light") {
    PaywallPlanCardGallery().preferredColorScheme(.light)
}

#Preview("Plan cards · dark") {
    PaywallPlanCardGallery().preferredColorScheme(.dark)
}

#Preview("Plan cards · largest text") {
    PaywallPlanCardGallery().dynamicTypeSize(.accessibility5)
}

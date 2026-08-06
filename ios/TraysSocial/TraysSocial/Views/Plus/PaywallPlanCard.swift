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

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Button(action: onSelect) {
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                        .foregroundStyle(Theme.text)
                    if let trialLine {
                        Text(trialLine)
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(Theme.accentInk(for: colorScheme))
                    }
                    Text(priceLine)
                        .font(.subheadline)
                        .foregroundStyle(Theme.textSecondary)
                }
                .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 8)
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(isSelected ? Theme.accentInk(for: colorScheme) : Theme.subtle(for: colorScheme))
                    .accessibilityHidden(true)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.surface)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(
                        isSelected ? Theme.accentBorder : Theme.hairline(for: colorScheme),
                        lineWidth: isSelected ? 2 : 1
                    )
            )
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
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

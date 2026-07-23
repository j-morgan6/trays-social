import SwiftUI

/// W158: sponsored card rendered inline in feed-shaped lists (Feed and
/// the Cook Mode completion screen). Mirrors `FeedCardView`'s shell —
/// Theme.surface background, 18pt continuous corners, hairline stroke,
/// same outer padding rhythm — but carries no like/comment/save
/// affordances and never navigates. The creative comes from
/// `AdProvider.current` (stubbed house ad for now).
struct SponsoredCardView: View {
    @Environment(\.colorScheme) private var colorScheme
    let slot: AdSlot

    @State private var showReportSheet = false

    private var creative: AdCreative {
        AdProvider.current.creative(for: slot)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(alignment: .center) {
                // High-contrast disclosure label — primary text color on
                // purpose (not the subtle gray) so the sponsored state is
                // unambiguous at a glance.
                Text("Sponsored")
                    .font(.system(size: 11, weight: .semibold))
                    .tracking(0.8)
                    .textCase(.uppercase)
                    .foregroundStyle(colorScheme == .dark ? Theme.textDark : Theme.textLight)

                Spacer(minLength: 8)

                Menu {
                    Button {
                        showReportSheet = true
                    } label: {
                        Label {
                            Text("Report this ad")
                        } icon: {
                            Image(systemName: "flag")
                        }
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(Theme.subtle(for: colorScheme))
                        .frame(width: 28, height: 28)
                        .contentShape(Rectangle())
                }
                .accessibilityLabel(String(localized: "Report this ad"))
            }

            Text(creative.title)
                .font(.system(size: 14, weight: .semibold))
                .tracking(-0.14)
                .foregroundStyle(colorScheme == .dark ? Theme.textDark : Theme.textLight)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)

            Text(creative.body)
                .font(.system(size: 12.5))
                .foregroundStyle(Theme.muted(for: colorScheme))
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 14)
        .padding(.top, 12)
        .padding(.bottom, 14)
        .background(Theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Theme.hairline(for: colorScheme), lineWidth: 1)
        )
        .shadow(color: colorScheme == .dark ? .clear : Color.black.opacity(0.025), radius: 2, y: 1)
        .padding(.horizontal, 16)
        .padding(.bottom, 18)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilitySummary)
        .accessibilityAction(named: Text("Report this ad")) {
            showReportSheet = true
        }
        .sheet(isPresented: $showReportSheet) {
            ReportSheetView(
                targetType: "ad",
                targetId: slot.reportTargetID,
                adContext: "placement=\(slot.placement) slot=\(slot.slot)"
            )
        }
    }

    private var accessibilitySummary: String {
        "\(String(localized: "Sponsored")), \(creative.title), \(creative.body)"
    }
}

#Preview("SponsoredCardView · light") {
    SponsoredCardView(slot: AdSlot(slot: 0, placement: "feed"))
        .padding(.vertical, 20)
        .background(Theme.bgLight)
        .preferredColorScheme(.light)
}

#Preview("SponsoredCardView · dark") {
    SponsoredCardView(slot: AdSlot(slot: 0, placement: "feed"))
        .padding(.vertical, 20)
        .background(Theme.bgDark)
        .preferredColorScheme(.dark)
}

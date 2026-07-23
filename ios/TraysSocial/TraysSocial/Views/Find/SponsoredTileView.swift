import SwiftUI

/// W158: sponsored tile for the Find trending grid. Mirrors `GridCard`'s
/// geometry (1:1.1 aspect, 14pt continuous corners) but uses a flat
/// Theme.surface fill instead of a photo — house creative only, no
/// navigation. Reporting goes through the same sheet as the feed card.
struct SponsoredTileView: View {
    @Environment(\.colorScheme) private var colorScheme
    let slot: AdSlot

    @State private var showReportSheet = false

    private var creative: AdCreative {
        AdProvider.current.creative(for: slot)
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Theme.surface

            VStack(alignment: .leading, spacing: 6) {
                Text("Sponsored")
                    .font(.system(size: 10, weight: .semibold))
                    .tracking(0.8)
                    .textCase(.uppercase)
                    .foregroundStyle(colorScheme == .dark ? Theme.textDark : Theme.textLight)

                Text(creative.title)
                    .font(.system(size: 13.5, weight: .semibold))
                    .tracking(-0.135)
                    .foregroundStyle(colorScheme == .dark ? Theme.textDark : Theme.textLight)
                    .lineLimit(3)
                    .multilineTextAlignment(.leading)

                Spacer(minLength: 0)
            }
            .padding(12)
            .padding(.trailing, 20)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

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
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Theme.subtle(for: colorScheme))
                    .frame(width: 26, height: 26)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel(String(localized: "Report this ad"))
            .padding(4)
        }
        .aspectRatio(1.0 / 1.1, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Theme.hairline(for: colorScheme), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.04), radius: 2, y: 1)
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
        "\(String(localized: "Sponsored")), \(creative.title)"
    }
}

#Preview("SponsoredTileView") {
    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
        SponsoredTileView(slot: AdSlot(slot: 0, placement: "find"))
        SponsoredTileView(slot: AdSlot(slot: 1, placement: "find"))
    }
    .padding(20)
    .background(Theme.bgLight)
}

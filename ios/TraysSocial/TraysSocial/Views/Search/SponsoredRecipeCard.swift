import SwiftUI

/// W243: a sponsored card in Search grids (Components artboard, "Sponsored
/// tile"). Same footprint as `RecipeCard` at 4:3 so the grid never shifts:
/// a placeholder photo with a "Sponsored" pill, the creative title, and a
/// "Sponsored · partner recipe" byline. House creative only, no navigation;
/// reporting goes through the same sheet as `SponsoredTileView`.
struct SponsoredRecipeCard: View {
    let slot: AdSlot

    @State private var showReportSheet = false

    private var creative: AdCreative {
        AdProvider.current.creative(for: slot)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            PhotoSlot(url: nil, cornerRadius: 15)
                .aspectRatio(4.0 / 3.0, contentMode: .fit)
                .overlay(alignment: .topLeading) { sponsoredPill.padding(8) }
                .overlay(alignment: .topTrailing) { reportMenu.padding(4) }
            VStack(alignment: .leading, spacing: 7) {
                Text(creative.title)
                    .roundedFont(.cardTitle)
                    .foregroundStyle(Theme.text)
                    .lineLimit(2, reservesSpace: true)
                    .multilineTextAlignment(.leading)
                // Same height as RecipeCard's byline, which holds a 22pt
                // avatar, so a sponsored card ends level with its neighbour.
                Text("Sponsored · partner recipe")
                    .scaledFont(12.5, relativeTo: .caption)
                    .foregroundStyle(Theme.muted)
                    .lineLimit(1)
                    .frame(minHeight: 22, alignment: .leading)
            }
            .padding(.top, 9)
            .padding(.horizontal, 6)
            .padding(.bottom, 6)
        }
        .padding(6)
        .cardSurface(cornerRadius: 21)
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

    private var sponsoredPill: some View {
        Text("Sponsored")
            .scaledFont(11.5, weight: .bold, relativeTo: .caption)
            .foregroundStyle(Theme.text)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(Capsule(style: .continuous).fill(Theme.surface))
    }

    private var reportMenu: some View {
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
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Theme.text)
                .frame(width: 32, height: 32)
                .background(Circle().fill(Theme.surface))
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .accessibilityLabel(String(localized: "Report this ad"))
    }

    private var accessibilitySummary: String {
        "\(String(localized: "Sponsored")), \(creative.title)"
    }
}

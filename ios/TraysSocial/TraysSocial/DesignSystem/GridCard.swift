import SwiftUI

/// 2-column grid tile composing a `Photo` background, a bottom-anchored
/// dark scrim, and a white title. Mirrors the prototype's `GridCard`
/// (prototype.jsx lines 323-341) — aspect ratio 1:1.1, 14pt radius,
/// title 13.5pt semibold with a soft text shadow for legibility on
/// light photo gradients.
struct GridCard: View {
    let photoKey: FoodPalette.Key
    let title: String

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            Photo(key: photoKey)

            // Bottom scrim — clear at the top 30%, 55% black at the
            // bottom. Same stops as Theme.scrimGradient (W127) but kept
            // inline so this card never needs to read the gradient via
            // .foregroundStyle, which would break it (it's a
            // LinearGradient, not a Color).
            LinearGradient(
                stops: [
                    .init(color: .clear, location: 0.3),
                    .init(color: Color.black.opacity(0.55), location: 1.0),
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            Text(title)
                .font(.system(size: 13.5, weight: .semibold))
                .tracking(-0.135)
                .foregroundStyle(Color.white)
                .shadow(color: Color.black.opacity(0.35), radius: 2, y: 1)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
                .padding(.horizontal, 12)
                .padding(.bottom, 10)
        }
        .aspectRatio(1.0 / 1.1, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.black.opacity(0.03), lineWidth: 0.5)
        )
        .shadow(color: Color.black.opacity(0.04), radius: 2, y: 1)
    }
}

private struct GridCardPreviewData {
    let key: FoodPalette.Key
    let title: String
}

private let gridCardSamples: [GridCardPreviewData] = [
    .init(key: .tomato, title: "Sunday short ribs over polenta"),
    .init(key: .greens, title: "Charred broccolini with anchovy butter"),
    .init(key: .lemon, title: "Lemon ricotta pancakes"),
    .init(key: .cocoa, title: "Cocoa nib bark with sea salt"),
]

#Preview("GridCard · light") {
    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
        ForEach(gridCardSamples.indices, id: \.self) { i in
            GridCard(photoKey: gridCardSamples[i].key, title: gridCardSamples[i].title)
        }
    }
    .padding(20)
    .background(Theme.bgLight)
    .preferredColorScheme(.light)
}

#Preview("GridCard · dark") {
    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
        ForEach(gridCardSamples.indices, id: \.self) { i in
            GridCard(photoKey: gridCardSamples[i].key, title: gridCardSamples[i].title)
        }
    }
    .padding(20)
    .background(Theme.bgDark)
    .preferredColorScheme(.dark)
}

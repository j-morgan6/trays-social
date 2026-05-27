import SwiftUI

/// Gradient-based food placeholder. Mirrors the prototype's `Photo`
/// component (prototype.jsx lines 67-93) — a three-stop radial
/// gradient from a `FoodPalette` key, layered with a faint diagonal
/// stripe texture and a dark blob in the bottom-right for depth.
///
/// Pure visual: no AsyncImage and no networking. Real-photo loading
/// is a separate concern (tracked under the iOS performance Goal).
struct Photo: View {
    let key: FoodPalette.Key
    var label: String?

    var body: some View {
        let colors = FoodPalette.colors(for: key)

        ZStack(alignment: .bottomLeading) {
            RadialGradient(
                stops: [
                    .init(color: colors[0], location: 0.0),
                    .init(color: colors[1], location: 0.48),
                    .init(color: colors[2], location: 1.0),
                ],
                center: UnitPoint(x: 0.28, y: 0.22),
                startRadius: 0,
                endRadius: 380
            )

            stripeTexture
                .allowsHitTesting(false)

            RadialGradient(
                colors: [Color.black.opacity(0.28), .clear],
                center: UnitPoint(x: 0.70, y: 0.75),
                startRadius: 0,
                endRadius: 220
            )
            .allowsHitTesting(false)

            if let label {
                Text(label.uppercased())
                    .font(.system(size: 10, weight: .regular, design: .monospaced))
                    .tracking(0.6)
                    .foregroundStyle(Color.white.opacity(0.78))
                    .padding(10)
            }
        }
        .compositingGroup()
    }

    /// Repeating 1pt diagonal lines at 132°, ~14pt gap, ~4.5% white.
    /// Matches the prototype's repeating-linear-gradient stripe layer.
    private var stripeTexture: some View {
        GeometryReader { proxy in
            let diagonal = sqrt(proxy.size.width * proxy.size.width + proxy.size.height * proxy.size.height)
            let lineCount = Int(diagonal / 14) + 2
            ZStack {
                ForEach(0 ..< lineCount, id: \.self) { i in
                    Rectangle()
                        .fill(Color.white.opacity(0.045))
                        .frame(width: 1, height: diagonal * 1.4)
                        .offset(x: CGFloat(i) * 14 - diagonal / 2)
                        .rotationEffect(.degrees(42))
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height, alignment: .center)
            .clipped()
        }
    }
}

#Preview("Photo · light") {
    LazyVGrid(columns: [GridItem(.adaptive(minimum: 120))], spacing: 12) {
        ForEach(FoodPalette.Key.allCases, id: \.self) { k in
            Photo(key: k, label: k.rawValue)
                .aspectRatio(1, contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
    .padding()
    .preferredColorScheme(.light)
}

#Preview("Photo · dark") {
    LazyVGrid(columns: [GridItem(.adaptive(minimum: 120))], spacing: 12) {
        ForEach(FoodPalette.Key.allCases, id: \.self) { k in
            Photo(key: k, label: k.rawValue)
                .aspectRatio(1, contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
    .padding()
    .preferredColorScheme(.dark)
}

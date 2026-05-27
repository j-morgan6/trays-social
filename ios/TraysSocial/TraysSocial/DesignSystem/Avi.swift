import SwiftUI

/// Circular avatar with a single initial on a two-stop linear gradient.
/// Mirrors the prototype's `Avi` component (prototype.jsx lines
/// 94-113).
///
/// `palette` picks one of 9 hand-tuned gradient pairs. `border` adds a
/// 1pt inset ring; the ring color adapts to the active color scheme.
/// The initial is sized to ~40% of the avatar's diameter so it scales
/// across the 24pt/36pt/72pt sizes used in the prototype.
struct Avi: View {
    enum Palette: String, CaseIterable, Hashable {
        case warm, sage, amber, plum, sky, clay, rose, sea, cocoa

        var colors: [Color] {
            switch self {
            case .warm: [Color(hex: 0xD9A56F), Color(hex: 0x8E5A2C)]
            case .sage: [Color(hex: 0x9DBF73), Color(hex: 0x3F5E2D)]
            case .amber: [Color(hex: 0xE8C054), Color(hex: 0x9E7320)]
            case .plum: [Color(hex: 0xB084A0), Color(hex: 0x5E3F50)]
            case .sky: [Color(hex: 0x8FAEC3), Color(hex: 0x3E596A)]
            case .clay: [Color(hex: 0xD38F5A), Color(hex: 0x7A3F1F)]
            case .rose: [Color(hex: 0xE0A097), Color(hex: 0x933E36)]
            case .sea: [Color(hex: 0x80B0A7), Color(hex: 0x2E574E)]
            case .cocoa: [Color(hex: 0xA57F5D), Color(hex: 0x4B2F1A)]
            }
        }
    }

    @Environment(\.colorScheme) private var colorScheme
    let initial: String
    var size: CGFloat = 36
    var palette: Palette = .warm
    var border: Bool = false

    var body: some View {
        Circle()
            .fill(
                LinearGradient(
                    colors: palette.colors,
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .frame(width: size, height: size)
            .overlay(
                Text(String(initial.prefix(1)).uppercased())
                    .font(.system(size: size * 0.40, weight: .semibold))
                    .tracking(-0.2)
                    .foregroundStyle(Color.white)
            )
            .overlay(
                Group {
                    if border {
                        Circle()
                            .inset(by: 0.5)
                            .stroke(borderColor, lineWidth: 1)
                    }
                }
            )
    }

    private var borderColor: Color {
        colorScheme == .dark
            ? Color.white.opacity(0.18)
            : Color.black.opacity(0.10)
    }
}

#Preview("Avi · light") {
    HStack(spacing: 12) {
        ForEach(Avi.Palette.allCases, id: \.self) { p in
            Avi(initial: String(p.rawValue.prefix(1)), size: 44, palette: p, border: true)
        }
    }
    .padding()
    .preferredColorScheme(.light)
}

#Preview("Avi · dark") {
    HStack(spacing: 12) {
        ForEach(Avi.Palette.allCases, id: \.self) { p in
            Avi(initial: String(p.rawValue.prefix(1)), size: 44, palette: p, border: true)
        }
    }
    .padding()
    .preferredColorScheme(.dark)
}

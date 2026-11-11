import SwiftUI

/// W239: the soft card the redesign puts recipes, rows and planner days on.
/// Light mode: a surface fill with a two-layer 5-7% shadow. Dark mode: no
/// shadow (it would be invisible), an inset hairline instead.
struct CardSurface: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme
    let cornerRadius: CGFloat
    let fill: Color

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        content
            .background {
                if colorScheme == .dark {
                    shape.fill(fill)
                } else {
                    shape.fill(fill)
                        .shadow(color: Theme.textLight.opacity(0.05), radius: 1, y: 1)
                        .shadow(color: Theme.textLight.opacity(0.07), radius: 11, y: 8)
                }
            }
            .overlay {
                if colorScheme == .dark {
                    shape.strokeBorder(Theme.hairline, lineWidth: 1)
                }
            }
    }
}

extension View {
    /// Wrap content in the redesign's soft card.
    func cardSurface(cornerRadius: CGFloat, fill: Color = Theme.surface) -> some View {
        modifier(CardSurface(cornerRadius: cornerRadius, fill: fill))
    }
}

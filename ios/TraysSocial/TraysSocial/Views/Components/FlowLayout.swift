import SwiftUI

// MARK: - Flow Layout

// W247: moved unchanged out of PostDetailView.swift. Used by the recipe
// detail tools, CreatePostView, IngredientChipBar and the Search previews.

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache _: inout ()) -> CGSize {
        let result = layout(subviews: subviews, proposal: proposal)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache _: inout ()) {
        let result = layout(subviews: subviews, proposal: proposal)
        for (index, position) in result.positions.enumerated() {
            let point = CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y)
            subviews[index].place(at: point, proposal: .unspecified)
        }
    }

    private func layout(subviews: Subviews, proposal: ProposedViewSize) -> (size: CGSize, positions: [CGPoint]) {
        // Pre-measure every subview so we can compute a finite fallback width
        // when SwiftUI calls us during a measurement pass with an unspecified proposal.
        let sizes = subviews.map { $0.sizeThatFits(.unspecified) }
        let naturalWidth = sizes.reduce(0) { $0 + $1.width }
            + CGFloat(max(0, sizes.count - 1)) * spacing

        // If the parent proposes a finite width, wrap to fit it.
        // If the proposal is nil/infinite (measurement phase), use the natural
        // single-row width so we NEVER report .infinity back up the view tree.
        let maxWidth: CGFloat = {
            if let proposed = proposal.width, proposed.isFinite {
                return proposed
            }
            return naturalWidth
        }()

        var positions: [CGPoint] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var maxRowWidth: CGFloat = 0

        for size in sizes {
            if x + size.width > maxWidth, x > 0 {
                maxRowWidth = max(maxRowWidth, x - spacing)
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            positions.append(CGPoint(x: x, y: y))
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
        }
        // Account for the final row.
        maxRowWidth = max(maxRowWidth, x - (sizes.isEmpty ? 0 : spacing))

        // Report the actual content extent, not the proposed width — this prevents
        // the layout from telling its parent "I need infinite width" and forcing
        // the enclosing ScrollView/VStack wider than the viewport.
        return (CGSize(width: maxRowWidth, height: y + rowHeight), positions)
    }
}

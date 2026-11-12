import SwiftUI

/// Horizontal shelf of collection cards in My Tray (W245 restyle).
///
/// Horizontal rather than a vertical section on purpose: the shelf sits inside
/// the tray's single vertical `ScrollView`, and a vertical section would push
/// the lists further down with every collection the user adds, changing the
/// tray's scroll shape over time. A fixed-height shelf does not.
///
/// W245: shown whenever Plus is visible, even with no collections, so the
/// "New collection" tile and a one-line note invite the first one. Every card
/// reserves two lines for its name, so cards in the row are the same size.
struct CollectionShelf: View {
    let collections: [RecipeCollection]
    let isPlus: Bool
    let onNewCollection: () -> Void
    let onRename: (RecipeCollection) -> Void
    /// Rename is a gated write, but the control still renders for a lapsed
    /// subscriber and routes here — hiding it would remove the moment-of-need
    /// trigger entirely and leave the user with no explanation for a menu item
    /// that silently disappeared.
    let onRenameLocked: () -> Void
    let onDelete: (RecipeCollection) -> Void

    static let cardWidth: CGFloat = 156

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: 12) {
                    ForEach(collections) { collection in
                        card(collection)
                    }
                    PlusGate(.collections) {
                        onNewCollection()
                    } label: {
                        NewCollectionTile()
                    }
                    .buttonStyle(.borderless)
                }
                // Lets the "New collection" tile stretch to the cards' height.
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, HomeMetrics.inset)
                .padding(.bottom, 12)
            }
            .scrollClipDisabled()

            if collections.isEmpty {
                Text("Group recipes for weeknights, guests, or a baking project.")
                    .scaledFont(13, relativeTo: .footnote)
                    .foregroundStyle(Theme.muted)
                    .padding(.horizontal, HomeMetrics.inset)
            }
        }
    }

    private func card(_ collection: RecipeCollection) -> some View {
        NavigationLink(value: CollectionRoute(id: collection.id, name: collection.name)) {
            CollectionShelfCard(collection: collection)
        }
        .buttonStyle(.borderless)
        // A pending row has a negative id; GET /collections/-1 is a 404.
        .disabled(collection.isPending)
        .contextMenu {
            // Rename routes to the paywall when locked rather than
            // vanishing. PlusGate can't be used here: its own
            // .plusPaywall sheet lives inside the menu's content
            // hierarchy, which is destroyed on dismiss, so the sheet
            // would never present. Delete is never gated at all —
            // the server's graceful re-lock contract, mirrored.
            Button {
                isPlus ? onRename(collection) : onRenameLocked()
            } label: {
                Label(String(localized: "Rename"), systemImage: "pencil")
            }
            Button(role: .destructive) {
                onDelete(collection)
            } label: {
                Label(String(localized: "Delete"), systemImage: "trash")
            }
        }
    }
}

/// One collection card: a square cover, the name (two lines reserved) and a
/// count. A distinct type rather than RecipeCard: a collection has no author
/// or cook time, and a fixed width keeps it safe inside a horizontal
/// `ScrollView`, which proposes unbounded width.
struct CollectionShelfCard: View {
    let collection: RecipeCollection

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            PhotoSlot(url: collection.coverURL, cornerRadius: 15)
                .aspectRatio(1, contentMode: .fit)
            VStack(alignment: .leading, spacing: 7) {
                Text(collection.name)
                    .roundedFont(15, weight: .bold, relativeTo: .subheadline)
                    .foregroundStyle(Theme.text)
                    .lineLimit(2, reservesSpace: true)
                    .multilineTextAlignment(.leading)
                Text(MyTrayCopy.recipeCount(collection.itemCount))
                    .scaledFont(12.5, relativeTo: .caption)
                    .foregroundStyle(Theme.muted)
                    .lineLimit(1)
            }
            .padding(.top, 9)
            .padding(.horizontal, 6)
            .padding(.bottom, 6)
        }
        .padding(6)
        .frame(width: CollectionShelf.cardWidth)
        .cardSurface(cornerRadius: 21)
        .opacity(collection.isPending ? 0.6 : 1)
        .accessibilityElement(children: .combine)
    }
}

/// Trailing "New collection" tile: a dashed outline the same size as a card.
private struct NewCollectionTile: View {
    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: "plus")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(Theme.primaryInk)
                .accessibilityHidden(true)
            Text("New collection")
                .scaledFont(14, weight: .semibold, relativeTo: .subheadline)
                .foregroundStyle(Theme.text)
                .multilineTextAlignment(.center)
                .lineLimit(2)
        }
        .padding(.horizontal, 10)
        .frame(width: CollectionShelf.cardWidth)
        .frame(minHeight: CollectionShelf.cardWidth, maxHeight: .infinity)
        .overlay(
            RoundedRectangle(cornerRadius: 21, style: .continuous)
                .strokeBorder(Theme.hairlineStrong, style: StrokeStyle(lineWidth: 1.5, dash: [6, 4]))
        )
        .contentShape(RoundedRectangle(cornerRadius: 21, style: .continuous))
    }
}

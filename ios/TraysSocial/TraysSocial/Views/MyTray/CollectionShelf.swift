import SwiftUI

/// Horizontal shelf of collection cards, rendered above the Recipes grid in
/// My Tray.
///
/// Horizontal rather than a vertical section on purpose: the shelf sits inside
/// the tray's single vertical `ScrollView`, and a vertical section would push
/// the Recipes grid further down with every collection the user adds, changing
/// the tray's scroll shape over time. A fixed-height shelf does not.
///
/// The caller renders this only when collections exist, so a user with none
/// sees byte-identical layout to before W177.
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

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(collections) { collection in
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

                PlusGate(.collections) {
                    onNewCollection()
                } label: {
                    NewCollectionTile()
                }
                .buttonStyle(.borderless)
            }
            .padding(.horizontal, 20)
        }
        .scrollClipDisabled()
    }
}

/// One collection tile: cover photo, scrim, name, and an item count line.
///
/// A distinct type rather than a reuse of `GridCard`: that card's
/// `.aspectRatio(1/1.1, contentMode: .fit)` with no width constraint is a
/// layout hazard inside a horizontal `ScrollView`, which proposes unbounded
/// width (see swiftui-layout-pitfalls).
private struct CollectionShelfCard: View {
    let collection: RecipeCollection

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            Photo(key: photoKey, url: collection.coverURL)

            LinearGradient(
                stops: [
                    .init(color: .clear, location: 0.3),
                    .init(color: Color.black.opacity(0.55), location: 1.0),
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            VStack(alignment: .leading, spacing: 2) {
                Text(collection.name)
                    .font(.system(size: 13.5, weight: .semibold))
                    .tracking(-0.135)
                    .foregroundStyle(Color.white)
                    .shadow(color: Color.black.opacity(0.35), radius: 2, y: 1)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                Text(countLabel)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.82))
                    .shadow(color: Color.black.opacity(0.35), radius: 2, y: 1)
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 10)
        }
        .frame(width: 132, height: 150)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .opacity(collection.isPending ? 0.6 : 1)
        .accessibilityElement(children: .combine)
    }

    /// Same stable-key trick as `MyTrayView.photoKey(for:)` — a collection
    /// without a cover always draws the same gradient rather than flickering
    /// between reloads.
    private var photoKey: FoodPalette.Key {
        let keys = FoodPalette.Key.allCases
        return keys[abs(collection.id) % keys.count]
    }

    private var countLabel: String {
        switch collection.itemCount {
        case 0: String(localized: "No recipes yet")
        case 1: String(localized: "1 recipe")
        default: String(localized: "\(collection.itemCount) recipes")
        }
    }
}

/// Trailing "add" tile. Reuses `TrayEmptyView`'s dashed-amber vocabulary so it
/// reads as native to the tray rather than a bolted-on button.
private struct NewCollectionTile: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "folder.badge.plus")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(Theme.accentInk(for: colorScheme))
            Text(String(localized: "New collection"))
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Theme.accentInk(for: colorScheme))
                .multilineTextAlignment(.center)
                .lineLimit(2)
        }
        .padding(.horizontal, 10)
        .frame(width: 132, height: 150)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Theme.accent.opacity(0.04))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(
                    dashedBorderColor,
                    style: StrokeStyle(lineWidth: 1.5, dash: [6, 4])
                )
        )
    }

    private var dashedBorderColor: Color {
        colorScheme == .dark
            ? Color(red: 255 / 255, green: 179 / 255, blue: 0 / 255, opacity: 0.42)
            : Color(red: 255 / 255, green: 143 / 255, blue: 0 / 255, opacity: 0.55)
    }
}

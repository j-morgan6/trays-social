import SwiftUI

/// Context-menu content for a tray card: add this recipe to a collection.
///
/// PRESENTATION CONSTRAINT — this is the app's first `.contextMenu`, and it
/// imposes one rule worth stating up front: a `.sheet` or `.alert` attached
/// *inside* a context-menu builder never presents, because the menu's content
/// hierarchy is torn down the instant the menu dismisses. So this view owns no
/// presentation of its own. It flips state or calls a closure, and the
/// `.plusPaywall` / `.sheet` modifiers live on My Tray's root ScrollView.
struct AddToCollectionMenu: View {
    let post: Post
    let isPlus: Bool
    let viewModel: CollectionsViewModel
    let onNewCollection: () -> Void

    var body: some View {
        if isPlus {
            if viewModel.collections.isEmpty {
                Button(action: onNewCollection) {
                    Label(String(localized: "New collection"), systemImage: "folder.badge.plus")
                }
            } else {
                Menu {
                    ForEach(viewModel.collections) { collection in
                        Button {
                            viewModel.addPost(post, to: collection.id)
                        } label: {
                            Text(collection.name)
                        }
                        .disabled(collection.isPending)
                    }
                    Divider()
                    Button(action: onNewCollection) {
                        Label(String(localized: "New collection"), systemImage: "folder.badge.plus")
                    }
                } label: {
                    Label(
                        String(localized: "Add to collection"),
                        systemImage: "rectangle.stack.badge.plus"
                    )
                }
            }
        } else {
            // The entry EXISTS for a free or lapsed user and routes to the
            // paywall in context. Hiding it would make the feature invisible
            // to exactly the people it is meant to convert — and moment-of-need
            // is the only place W176's rules allow the paywall to appear.
            Button {
                viewModel.requestAddWhileLocked(post)
            } label: {
                Label(
                    String(localized: "Add to collection"),
                    systemImage: "rectangle.stack.badge.plus"
                )
            }
        }
    }
}

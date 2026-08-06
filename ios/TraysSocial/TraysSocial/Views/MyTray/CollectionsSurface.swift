import SwiftUI

/// Every presentation and cross-screen sync the collections shelf needs,
/// bundled as one modifier on My Tray's root ScrollView.
///
/// Two reasons it is a `ViewModifier` and not six modifiers inlined in
/// `MyTrayView`:
///
/// 1. `MyTrayView.swift` is already 300+ lines against swiftlint's 400-line
///    warning, and `ProfileView.swift` is the cautionary tale of what happens
///    when a screen keeps absorbing "just one more" modifier.
/// 2. These MUST live on the root ScrollView, never inside the context-menu
///    builder. A `.sheet` or `.alert` attached inside a `.contextMenu` never
///    presents — the menu's content hierarchy is destroyed on dismiss. Keeping
///    them together in one named modifier makes that non-obvious rule hard to
///    accidentally undo.
struct CollectionsSurface: ViewModifier {
    @Environment(AppState.self) private var appState

    let viewModel: CollectionsViewModel
    @Binding var formMode: CollectionFormMode?
    @Binding var pendingDelete: RecipeCollection?

    func body(content: Content) -> some View {
        content
            .task { await viewModel.load() }
            .sheet(item: $formMode) { mode in
                CollectionFormSheet(mode: mode, viewModel: viewModel)
            }
            .alert(
                String(localized: "Delete collection"),
                isPresented: Binding(
                    get: { pendingDelete != nil },
                    set: {
                        if !$0 {
                            pendingDelete = nil
                        }
                    }
                ),
                presenting: pendingDelete
            ) { collection in
                Button(String(localized: "Cancel"), role: .cancel) {}
                Button(String(localized: "Delete"), role: .destructive) {
                    viewModel.deleteCollection(id: collection.id)
                }
            } message: { _ in
                Text("This removes the collection only. Your saved recipes stay in your tray.")
            }
            // The server can still refuse a gated write if entitlement lapsed
            // mid-session; the ViewModel flips needsPaywall and the paywall
            // presents here, in context, rather than as an error toast.
            .plusPaywall(
                isPresented: Binding(
                    get: { viewModel.needsPaywall },
                    set: { presented in
                        viewModel.needsPaywall = presented
                        // Closed without subscribing: `onUnlocked` will not run,
                        // so a remembered add-intent would otherwise outlive the
                        // interaction and be consumed by some later create.
                        if !presented, !appState.isPlus {
                            viewModel.cancelPendingAdd()
                        }
                    }
                ),
                feature: .collections,
                onUnlocked: {
                    Task {
                        await viewModel.refresh()
                        // Finish what the user was doing before the paywall
                        // interrupted them. A fresh subscriber has no
                        // collections yet, so we open the create form and the
                        // add lands once the collection exists.
                        if viewModel.replayPendingAdd() {
                            formMode = .create
                        }
                    }
                }
            )
            // My Tray never unmounts (the tab shell keeps all three alive), so
            // `.task` does not re-fire when the user comes back from a
            // collection. These two are what keep the shelf's counts honest.
            .onReceive(NotificationCenter.default.publisher(for: .collectionItemRemoved)) { note in
                if let id = note.userInfo?["collectionId"] as? Int {
                    viewModel.applyItemRemoved(collectionId: id)
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .collectionItemRestored)) { note in
                if let id = note.userInfo?["collectionId"] as? Int {
                    viewModel.applyItemRestored(collectionId: id)
                }
            }
    }
}

import SwiftUI

/// What the form sheet is doing. `Identifiable` so `MyTrayView` can drive it
/// with `.sheet(item:)`, which avoids the stale-payload race a
/// `.sheet(isPresented:)` plus a separate `selectedCollection` would have.
enum CollectionFormMode: Identifiable, Hashable {
    case create
    case rename(RecipeCollection)

    var id: String {
        switch self {
        case .create: "create"
        case let .rename(collection): "rename-\(collection.id)"
        }
    }
}

/// Create / rename form, modeled on `FeedbackView`'s NavigationStack + Form +
/// cancellation/confirmation toolbar.
///
/// Validates client-side before dismissing: the three common rejections
/// (empty, over 60 characters, duplicate name) surface inline here rather than
/// as an optimistic row that appears and then vanishes when the server's 422
/// lands.
struct CollectionFormSheet: View {
    let mode: CollectionFormMode
    let viewModel: CollectionsViewModel

    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var validation: CollectionNameValidation?
    @State private var didSubmit = false
    @FocusState private var nameFocused: Bool

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField(String(localized: "Collection name"), text: $name)
                        .textInputAutocapitalization(.words)
                        .submitLabel(.done)
                        .focused($nameFocused)
                        .onSubmit(submit)
                        .onChange(of: name) { _, _ in validation = nil }
                }

                if let message = validation?.message {
                    Section {
                        Text(message)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "Cancel")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(confirmTitle, action: submit)
                }
            }
        }
        .onAppear {
            if case let .rename(collection) = mode {
                name = collection.name
            }
            nameFocused = true
        }
        .onDisappear {
            // Backed out of the create we opened to finish an add-to-collection
            // that was interrupted by the paywall. The remembered recipe dies
            // with this sheet — otherwise the next unrelated collection they
            // create would silently inherit it. `.onDisappear` rather than the
            // Cancel button so a swipe-to-dismiss counts too, and only when
            // nothing was submitted (on the success path `confirmCreate` claims
            // the intent later, after this sheet is already gone).
            if case .create = mode, !didSubmit {
                viewModel.cancelPendingAdd()
            }
        }
    }

    private var title: String {
        switch mode {
        case .create: String(localized: "New collection")
        case .rename: String(localized: "Rename collection")
        }
    }

    private var confirmTitle: String {
        switch mode {
        case .create: String(localized: "Create")
        case .rename: String(localized: "Save")
        }
    }

    private func submit() {
        let result: CollectionNameValidation = switch mode {
        case .create:
            viewModel.createCollection(name: name)
        case let .rename(collection):
            viewModel.renameCollection(id: collection.id, to: name)
        }

        if case .valid = result {
            didSubmit = true
            dismiss()
        } else {
            validation = result
        }
    }
}

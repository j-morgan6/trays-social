import SwiftUI

/// W258 (Create artboard): the Add to a collection (Optional) card. The
/// user's collections as toggle chips, in the shelf's order, plus New, which
/// opens the same form My Tray uses and selects what it creates. The editor
/// shows this card only to Plus users whose collections loaded
/// (`CollectionPickerState.visibility`); the adds themselves run after the
/// post is published, never here.
struct CollectionPickerCard: View {
    @Bindable var viewModel: CreatePostViewModel
    @State private var formMode: CollectionFormMode?

    private var collections: CollectionsViewModel {
        viewModel.collections
    }

    var body: some View {
        EditorCard(String(localized: "Add to a collection"), aside: String(localized: "Optional")) {
            FlowLayout(spacing: 8) {
                ForEach(collections.collections) { collection in
                    ToggleChip(
                        title: collection.name,
                        isSelected: viewModel.collectionPicker.isSelected(collection.id)
                    ) {
                        viewModel.collectionPicker.toggle(collection.id)
                    }
                }
                NewCollectionChip { formMode = .create }
            }
        }
        .disabled(viewModel.isBusy)
        .sheet(item: $formMode) { mode in
            CollectionFormSheet(mode: mode, viewModel: collections) { pendingID in
                viewModel.collectionPicker.selectNew(pendingID)
            }
        }
        // A collection deleted elsewhere, or a create confirmed or rolled
        // back, keeps the selection pointing at real rows.
        .onChange(of: collections.collections) { _, current in
            viewModel.collectionPicker.sync(with: current, confirmed: collections.confirmedIDs)
        }
        // A create refused for a lapsed subscription flips needsPaywall,
        // which nothing in the editor presents: say so with the create
        // toast instead of a paywall in the middle of posting.
        .onChange(of: collections.needsPaywall) { _, needsPaywall in
            guard needsPaywall else { return }
            collections.needsPaywall = false
            Toast.collectionCreateFailed.show()
        }
    }
}

/// New, at the end of the chips: a plus and "New", read as "New collection".
private struct NewCollectionChip: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: "plus")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Theme.primaryInk)
                    .accessibilityHidden(true)
                Text(String(localized: "New"))
                    .scaledFont(14.5, weight: .medium, relativeTo: .subheadline)
                    .foregroundStyle(Theme.text)
                    .lineLimit(1)
            }
            .padding(.leading, 12)
            .padding(.trailing, 15)
            .frame(minHeight: 40)
            .background(Capsule(style: .continuous).fill(Theme.surface))
            .overlay(Capsule(style: .continuous).strokeBorder(Theme.border, lineWidth: 1))
            .contentShape(Capsule(style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(String(localized: "New collection"))
    }
}

@MainActor
private enum CollectionPickerPreviewData {
    static func viewModel(names: [String], selected: [Int] = []) -> CreatePostViewModel {
        let viewModel = CreatePostViewModel()
        viewModel.collections.collections = names.enumerated().map { index, name in
            RecipeCollection(id: index + 1, name: name, itemCount: 0, coverPhotoUrl: nil, insertedAt: Date())
        }
        for id in selected {
            viewModel.collectionPicker.toggle(id)
        }
        return viewModel
    }
}

#Preview("Collection picker · none yet") {
    CollectionPickerCard(viewModel: CollectionPickerPreviewData.viewModel(names: []))
        .padding()
        .background(Theme.background)
}

#Preview("Collection picker · several") {
    CollectionPickerCard(viewModel: CollectionPickerPreviewData.viewModel(
        names: ["Weeknights", "Soups", "Date night", "Meal prep"],
        selected: [2, 1]
    ))
    .padding()
    .background(Theme.background)
}

#Preview("Collection picker · dark") {
    CollectionPickerCard(viewModel: CollectionPickerPreviewData.viewModel(
        names: ["Weeknights", "Soups"],
        selected: [1]
    ))
    .padding()
    .background(Theme.background)
    .preferredColorScheme(.dark)
}

#Preview("Collection picker · largest text") {
    CollectionPickerCard(viewModel: CollectionPickerPreviewData.viewModel(
        names: ["Weeknights", "Soups"],
        selected: [1]
    ))
    .padding()
    .background(Theme.background)
    .dynamicTypeSize(.accessibility5)
}

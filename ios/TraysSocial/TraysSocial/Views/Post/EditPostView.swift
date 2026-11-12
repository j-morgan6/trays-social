import PhotosUI
import SwiftUI

/// W149: edit form for a post the current user owns. Text + photo scope only
/// (caption, cooking time, servings, optional new photo) — no ingredient/step/
/// tool/tag editing. Presented as a sheet from PostDetailView's overflow menu.
///
/// W249: the same look as the recipe editor (Create artboard): the photo slot
/// with a Change pill, the Basics card (name and a line over the caption,
/// time and serves) and an amber Save changes bar with a spinner while
/// saving. Save errors stay in place, in amber; nothing toasts.
struct EditPostView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel: EditPostViewModel
    @State private var selectedPhoto: PhotosPickerItem?
    @FocusState private var focus: EditorField?
    private let postViewModel: PostViewModel

    init(post: Post, postViewModel: PostViewModel) {
        self.init(viewModel: EditPostViewModel(post: post), postViewModel: postViewModel)
    }

    /// Previews hand in a view model in a given state.
    init(viewModel: EditPostViewModel, postViewModel: PostViewModel) {
        _viewModel = State(initialValue: viewModel)
        self.postViewModel = postViewModel
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    EditorPhotoSlot(
                        image: viewModel.newPhotoImage,
                        remoteURL: viewModel.currentPhotoURL?.asBackendURL,
                        selection: $selectedPhoto,
                        emptySubtitle: String(localized: "Choose a photo of the finished dish.")
                    )

                    RecipeBasicsCard(
                        caption: $viewModel.caption,
                        minutes: $viewModel.cookingTimeMinutes,
                        servings: $viewModel.servings,
                        showsRecipeFields: viewModel.isRecipe,
                        focus: $focus
                    )

                    if let error = viewModel.errorMessage {
                        EditorAttentionNote(message: error)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 16)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(Theme.background)
            .safeAreaInset(edge: .bottom) {
                EditorActionBar(
                    title: String(localized: "Save changes"),
                    busyLabel: String(localized: "Saving"),
                    isBusy: viewModel.isSaving,
                    action: save
                )
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Theme.background, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .scaledFont(16, weight: .medium, relativeTo: .body)
                        .foregroundStyle(Theme.text)
                }
                ToolbarItem(placement: .principal) {
                    Text(viewModel.isRecipe ? String(localized: "Edit recipe") : String(localized: "Edit post"))
                        .roundedFont(17, weight: .heavy, relativeTo: .headline)
                        .foregroundStyle(Theme.text)
                        .accessibilityAddTraits(.isHeader)
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button(String(localized: "Done")) { focus = nil }
                        .foregroundStyle(Theme.primaryInk)
                }
            }
            .onChange(of: selectedPhoto) {
                viewModel.selectedPhoto = selectedPhoto
                Task { await viewModel.loadPhoto() }
            }
        }
        .tint(Theme.primary)
    }

    private func save() {
        guard !viewModel.isSaving else { return }
        focus = nil
        Task {
            if await viewModel.save(into: postViewModel) {
                dismiss()
            }
        }
    }
}

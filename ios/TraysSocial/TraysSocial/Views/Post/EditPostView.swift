import PhotosUI
import SwiftUI

/// W149: edit form for a post the current user owns. Text + photo scope only
/// (caption, cooking time, servings, optional new photo) — no ingredient/step/
/// tool/tag editing. Presented as a sheet from PostDetailView's overflow menu.
struct EditPostView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel: EditPostViewModel
    @State private var selectedPhoto: PhotosPickerItem?
    private let postViewModel: PostViewModel

    init(post: Post, postViewModel: PostViewModel) {
        _viewModel = State(initialValue: EditPostViewModel(post: post))
        self.postViewModel = postViewModel
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    sectionLabel("PHOTOGRAPH")
                    photoSection

                    sectionLabel(viewModel.isRecipe ? "TITLE & COOK'S NOTE" : "CAPTION")
                    TextField("Caption", text: $viewModel.caption, axis: .vertical)
                        .lineLimit(3 ... 6)
                        .textFieldStyle(.plain)
                        .padding(12)
                        .background(Theme.surface)
                        .clipShape(RoundedRectangle(cornerRadius: 12))

                    if viewModel.isRecipe {
                        sectionLabel("TIMING")
                        timingFields
                    }

                    if let error = viewModel.errorMessage {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }
                .padding(16)
            }
            .background(Theme.background)
            .navigationTitle("Edit Post")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task {
                            if await viewModel.save(into: postViewModel) { dismiss() }
                        }
                    }
                    .disabled(viewModel.isSaving)
                }
            }
            .onChange(of: selectedPhoto) {
                viewModel.selectedPhoto = selectedPhoto
                Task { await viewModel.loadPhoto() }
            }
        }
    }

    // MARK: - Sections

    private var photoSection: some View {
        Group {
            if let image = viewModel.newPhotoImage {
                image
                    .resizable()
                    .scaledToFill()
            } else if let url = viewModel.currentPhotoURL?.asBackendURL {
                CachedAsyncImage(url: url) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    Rectangle().fill(Theme.surface)
                }
            } else {
                Rectangle().fill(Theme.surface)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 200)
        .clipped()
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(alignment: .bottomTrailing) {
            PhotosPicker(selection: $selectedPhoto, matching: .images) {
                Text("Change")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(.ultraThinMaterial)
                    .clipShape(Capsule())
                    .padding(8)
            }
        }
    }

    private var timingFields: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Cook time (min)").font(.caption).foregroundStyle(.gray)
                TextField("30", text: $viewModel.cookingTimeMinutes)
                    .keyboardType(.numberPad)
                    .textFieldStyle(.plain)
                    .padding(12)
                    .background(Theme.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            VStack(alignment: .leading, spacing: 4) {
                Text("Servings").font(.caption).foregroundStyle(.gray)
                TextField("4", text: $viewModel.servings)
                    .keyboardType(.numberPad)
                    .textFieldStyle(.plain)
                    .padding(12)
                    .background(Theme.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .foregroundStyle(.gray)
            .tracking(0.5)
    }
}

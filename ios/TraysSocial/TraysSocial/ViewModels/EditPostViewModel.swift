import PhotosUI
import SwiftUI

/// W149: backs EditPostView. Owns the edit form's state and the photo-upload
/// step, then hands the resolved change to `PostViewModel.applyEdit`, which
/// performs the optimistic update + PATCH + rollback. Scope is text + photo
/// only — ingredients/steps/tools/tags are intentionally not represented here.
@MainActor
@Observable
final class EditPostViewModel {
    var caption: String
    var cookingTimeMinutes: String
    var servings: String
    var selectedPhoto: PhotosPickerItem?
    var newPhotoData: Data?
    var newPhotoImage: Image?
    var isSaving = false
    var errorMessage: String?

    let isRecipe: Bool
    let currentPhotoURL: String?

    init(post: Post) {
        caption = post.caption ?? ""
        cookingTimeMinutes = post.cookingTimeMinutes.map(String.init) ?? ""
        servings = post.servings.map(String.init) ?? ""
        isRecipe = post.isRecipe
        currentPhotoURL = post.primaryPhotoURL
    }

    func loadPhoto() async {
        guard let item = selectedPhoto else { return }
        if let data = try? await item.loadTransferable(type: Data.self) {
            newPhotoData = data
            if let uiImage = UIImage(data: data) {
                newPhotoImage = Image(uiImage: uiImage)
            }
        }
    }

    /// The parsed, editable field values. Exposed so tests can assert the edit
    /// builds a payload from only caption/cooking time/servings (text scope).
    var editedFields: (caption: String, cookingTimeMinutes: Int?, servings: Int?) {
        (caption.trimmingCharacters(in: .whitespacesAndNewlines), Int(cookingTimeMinutes), Int(servings))
    }

    /// Validates, uploads a newly-picked photo (only if one was chosen — an
    /// unchanged photo is never re-uploaded), then hands the change to
    /// `PostViewModel.applyEdit`. Returns true when the sheet should dismiss.
    func save(into postViewModel: PostViewModel) async -> Bool {
        let fields = editedFields
        // Recipe-type posts still require a cooking time after an edit.
        if isRecipe, fields.cookingTimeMinutes == nil {
            errorMessage = "Recipes need a cooking time."
            return false
        }

        isSaving = true
        errorMessage = nil

        var newPhotoURL: String?
        if let newPhotoData {
            do {
                newPhotoURL = try await APIClient.shared.upload(
                    path: "/uploads", imageData: newPhotoData, filename: "photo.jpg"
                )
            } catch {
                errorMessage = "Couldn't upload the photo. Try again."
                isSaving = false
                return false
            }
        }

        postViewModel.applyEdit(
            caption: fields.caption,
            cookingTimeMinutes: fields.cookingTimeMinutes,
            servings: fields.servings,
            newPhotoURL: newPhotoURL
        )
        isSaving = false
        return true
    }
}

import SwiftUI
import UIKit

// W249: preview galleries for the recipe editor's designed states (Create
// artboard): empty, filling in, missing photo, posting, the Preview, Posted
// (W257), and the edit form. Photos are a flat generated fill, never an asset.

@MainActor
private enum EditorPreviewData {
    static var photo: Image {
        let size = CGSize(width: 400, height: 300)
        let image = UIGraphicsImageRenderer(size: size).image { context in
            UIColor(Theme.cream).setFill()
            context.fill(CGRect(origin: .zero, size: size))
        }
        return Image(uiImage: image)
    }

    static func filled(publishing: Bool = false, error: String? = nil, withPhoto: Bool = true) -> CreatePostViewModel {
        let viewModel = CreatePostViewModel()
        viewModel.caption = "Sesame chicken thighs\nWe make this most Tuesdays. The thighs stay juicy."
        viewModel.cookingTimeMinutes = "35"
        viewModel.servings = "2"
        viewModel.ingredients = [
            .init(name: "bone-in chicken thighs", quantity: "4", unit: ""),
            .init(name: "soy sauce", quantity: "2", unit: "tbsp"),
            .init(name: "honey", quantity: "1", unit: "tbsp"),
        ]
        viewModel.steps = [
            .init(description: "Heat the oven to 220C. Pat the chicken dry and season with salt."),
            .init(description: "Sear skin-side down until deep golden."),
        ]
        viewModel.tools = ["Cast iron pan"]
        viewModel.tags = "weeknight, chicken"
        if withPhoto {
            viewModel.photoData = Data([0])
            viewModel.photoImage = photo
        }
        viewModel.isPublishing = publishing
        viewModel.errorMessage = error
        return viewModel
    }

    static func missingPhoto() -> CreatePostViewModel {
        filled(error: "Please select a photo", withPhoto: false)
    }
}

#Preview("Create · empty") {
    CreatePostView()
        .environment(AppState())
}

#Preview("Create · filling in") {
    CreatePostView(viewModel: EditorPreviewData.filled())
        .environment(AppState())
}

#Preview("Create · filling in · dark") {
    CreatePostView(viewModel: EditorPreviewData.filled())
        .environment(AppState())
        .preferredColorScheme(.dark)
}

#Preview("Create · missing photo") {
    CreatePostView(viewModel: EditorPreviewData.missingPhoto())
        .environment(AppState())
}

#Preview("Create · posting") {
    CreatePostView(viewModel: EditorPreviewData.filled(publishing: true))
        .environment(AppState())
}

#Preview("Create · largest text") {
    CreatePostView(viewModel: EditorPreviewData.filled())
        .environment(AppState())
        .dynamicTypeSize(.accessibility5)
}

#Preview("Preview") {
    RecipeDraftPreview(
        draft: RecipeDraft.make(from: EditorPreviewData.filled()),
        photo: EditorPreviewData.photo,
        onBack: {},
        onPost: {}
    )
}

#Preview("Preview · dark, long title") {
    let viewModel = EditorPreviewData.filled()
    viewModel.caption = "Slow-roasted sesame and honey chicken thighs with crispy garlic\nWorth the wait."
    return RecipeDraftPreview(
        draft: RecipeDraft.make(from: viewModel),
        photo: nil,
        onBack: {},
        onPost: {}
    )
    .preferredColorScheme(.dark)
}

#Preview("Posted") {
    PostedView(
        summary: PostedSummary(post: PreviewData.post(7, "Sesame chicken thighs")),
        onViewRecipe: {},
        onDone: {}
    )
}

#Preview("Posted · dark") {
    PostedView(
        summary: PostedSummary(post: PreviewData.post(7, "Sesame chicken thighs")),
        onViewRecipe: {},
        onDone: {}
    )
    .preferredColorScheme(.dark)
}

#Preview("Posted · largest text") {
    PostedView(
        summary: PostedSummary(post: PreviewData.post(7, "Sesame chicken thighs")),
        onViewRecipe: {},
        onDone: {}
    )
    .dynamicTypeSize(.accessibility5)
}

#Preview("Edit · recipe") {
    EditPostView(post: PreviewData.recipe(), postViewModel: PostViewModel())
}

#Preview("Edit · saving, dark") {
    let viewModel = EditPostViewModel(post: PreviewData.recipe())
    viewModel.isSaving = true
    return EditPostView(viewModel: viewModel, postViewModel: PostViewModel())
        .preferredColorScheme(.dark)
}

#Preview("Edit · upload error") {
    let viewModel = EditPostViewModel(post: PreviewData.post(7, "Toast and jam", type: "post"))
    viewModel.errorMessage = "Failed to upload photo"
    return EditPostView(viewModel: viewModel, postViewModel: PostViewModel())
}

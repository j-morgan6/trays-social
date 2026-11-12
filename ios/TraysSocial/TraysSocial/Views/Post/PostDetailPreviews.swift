import SwiftUI

// W247: preview galleries for the Recipe artboard's detail states: a recipe
// with notes, a saved recipe, your own recipe, a legacy photo post, loading, the two load
// failures, and the notes loading, failed and empty. Light, dark and largest
// text.

private struct NotesLoadError: Error {}

/// The loaded screen as PostDetailView draws it: the content with the
/// action pill floating at the bottom.
@MainActor
private func screen(_ post: Post, isOwner: Bool = false, comments: [Comment] = []) -> some View {
    ZStack(alignment: .bottom) {
        PostDetailContent(post: post, isOwner: isOwner, comments: .init(comments: comments))
        RecipeActionBar(
            isOwner: isOwner,
            isSaved: post.bookmarkedByCurrentUser == true,
            showsCookMode: post.isRecipe && !post.cookingSteps.isEmpty
        )
        .padding(.bottom, 24)
    }
    .background(Theme.background)
    .ignoresSafeArea(edges: .top)
}

@MainActor
private func recipe() -> some View {
    screen(PreviewData.recipe(liked: true), comments: PreviewData.comments)
}

@MainActor
private func saved() -> some View {
    screen(PreviewData.recipe(saved: true))
}

@MainActor
private func ownRecipe() -> some View {
    screen(PreviewData.recipe(), isOwner: true)
}

@MainActor
private func longTitle() -> some View {
    let caption = "Slow roasted tomato and white bean soup with crispy sage, garlic oil and a big pile of toast"
    return screen(PreviewData.recipe(caption: caption))
}

@MainActor
private func legacyPhoto() -> some View {
    screen(PreviewData.legacyPhoto)
}

@MainActor
private func loading() -> some View {
    ScrollView {
        SkeletonPostDetail()
    }
    .skeletonGroup(label: "Loading recipe")
    .background(Theme.background)
}

@MainActor
private func notFound() -> some View {
    PostUnavailableSurface(copy: .decide(notFound: true), onRetry: {}, onBack: {})
}

@MainActor
private func loadFailed() -> some View {
    PostUnavailableSurface(copy: .decide(notFound: false), onRetry: {}, onBack: {})
}

@MainActor
private func notes(_ state: PostDetailContent.CommentsState) -> some View {
    ScrollView {
        CommentsSection(
            post: PreviewData.recipe(),
            comments: state.comments,
            isLoading: state.isLoading,
            loadAttempted: state.loadAttempted,
            error: state.error,
            onRetry: {}
        )
    }
    .background(Theme.background)
}

#Preview("Recipe · light") {
    recipe().preferredColorScheme(.light)
}

#Preview("Recipe · dark") {
    recipe().preferredColorScheme(.dark)
}

#Preview("Recipe · largest text") {
    recipe().dynamicTypeSize(.accessibility5)
}

#Preview("Saved · light") {
    saved().preferredColorScheme(.light)
}

#Preview("Saved · dark") {
    saved().preferredColorScheme(.dark)
}

#Preview("Your own recipe · light") {
    ownRecipe().preferredColorScheme(.light)
}

#Preview("Legacy photo post · largest text") {
    legacyPhoto().dynamicTypeSize(.accessibility5)
}

#Preview("Long title · largest text") {
    longTitle().dynamicTypeSize(.accessibility5)
}

#Preview("Legacy photo post · light") {
    legacyPhoto().preferredColorScheme(.light)
}

#Preview("Legacy photo post · dark") {
    legacyPhoto().preferredColorScheme(.dark)
}

#Preview("Loading · light") {
    loading().preferredColorScheme(.light)
}

#Preview("Loading · dark") {
    loading().preferredColorScheme(.dark)
}

#Preview("Not found · light") {
    notFound().preferredColorScheme(.light)
}

#Preview("Load failed · dark") {
    loadFailed().preferredColorScheme(.dark)
}

#Preview("Load failed · largest text") {
    loadFailed().dynamicTypeSize(.accessibility5)
}

#Preview("Notes loading · light") {
    notes(.init(isLoading: true, loadAttempted: false)).preferredColorScheme(.light)
}

#Preview("Notes failed · dark") {
    notes(.init(error: NotesLoadError())).preferredColorScheme(.dark)
}

#Preview("Notes empty · light") {
    notes(.init()).preferredColorScheme(.light)
}

import SwiftUI

// W247: preview galleries for Cook mode: the first step (with the food-safety
// note), a middle step, the last step and the completion screen. Light, dark
// and largest text.

@MainActor
private func cook(_ progress: CookProgress) -> some View {
    let post = PreviewData.recipe()
    return CookModeView(
        steps: post.cookingSteps,
        title: RecipeTitle.from(caption: post.caption, fallback: "Recipe"),
        servings: post.servings,
        progress: progress
    )
}

private let stepCount = PreviewData.recipe().cookingSteps.count

#Preview("First step · light") {
    cook(CookProgress(stepCount: stepCount)).preferredColorScheme(.light)
}

#Preview("First step · dark") {
    cook(CookProgress(stepCount: stepCount)).preferredColorScheme(.dark)
}

#Preview("First step · largest text") {
    cook(CookProgress(stepCount: stepCount)).dynamicTypeSize(.accessibility5)
}

#Preview("Middle step · light") {
    cook(CookProgress(stepCount: stepCount, current: 1)).preferredColorScheme(.light)
}

#Preview("Last step · dark") {
    cook(CookProgress(stepCount: stepCount, current: stepCount - 1)).preferredColorScheme(.dark)
}

#Preview("Last step · largest text") {
    cook(CookProgress(stepCount: stepCount, current: stepCount - 1)).dynamicTypeSize(.accessibility5)
}

#Preview("Complete · light") {
    cook(CookProgress(stepCount: stepCount, current: stepCount - 1, isComplete: true)).preferredColorScheme(.light)
}

#Preview("Complete · dark") {
    cook(CookProgress(stepCount: stepCount, current: stepCount - 1, isComplete: true)).preferredColorScheme(.dark)
}

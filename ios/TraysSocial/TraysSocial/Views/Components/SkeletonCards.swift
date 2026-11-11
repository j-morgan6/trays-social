import SwiftUI

/// W239: loading placeholder shaped like `RecipeCard`, inside the same
/// soft card so the swap to content does not shift the layout.
struct SkeletonRecipeCard: View {
    var photoAspectRatio: CGFloat = 4.0 / 3.0

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            SkeletonShape(cornerRadius: 15, aspectRatio: photoAspectRatio)
            SkeletonShape(height: 11, cornerRadius: 6)
                .padding(.trailing, 28)
                .padding(.top, 4)
            SkeletonShape(width: 70, height: 11, cornerRadius: 6)
        }
        .padding(.top, 6)
        .padding(.horizontal, 6)
        .padding(.bottom, 12)
        .cardSurface(cornerRadius: 21)
        .accessibilityHidden(true)
    }
}

/// W239: loading placeholder shaped like `RowCard`.
struct SkeletonRowCard: View {
    var body: some View {
        HStack(spacing: 14) {
            SkeletonShape(width: 72, height: 72, cornerRadius: 14)
            VStack(alignment: .leading, spacing: 8) {
                SkeletonShape(height: 11, cornerRadius: 6)
                    .padding(.trailing, 40)
                SkeletonShape(width: 90, height: 11, cornerRadius: 6)
            }
            Spacer(minLength: 0)
        }
        .padding(8)
        .cardSurface(cornerRadius: 20)
        .accessibilityHidden(true)
    }
}

private struct SkeletonCardsGallery: View {
    var body: some View {
        VStack(spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                SkeletonRecipeCard()
                SkeletonRecipeCard(photoAspectRatio: 4.0 / 5.0)
            }
            SkeletonRowCard()
        }
        .padding()
        .background(Theme.background)
    }
}

#Preview("Skeleton cards · light") {
    SkeletonCardsGallery().preferredColorScheme(.light)
}

#Preview("Skeleton cards · dark") {
    SkeletonCardsGallery().preferredColorScheme(.dark)
}

#Preview("Skeleton cards · largest text") {
    SkeletonCardsGallery().dynamicTypeSize(.accessibility5)
}

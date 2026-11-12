import SwiftUI

/// W243: loading placeholders for Search, each shaped like the results it
/// replaces (Main artboard, Search state e). Pulses come from the shared
/// skeleton primitives, which stay still under Reduce Motion.
private let gridColumns = [GridItem(.flexible(), spacing: 12), GridItem(.flexible())]

private func headingBar(_ width: CGFloat) -> some View {
    SkeletonShape(width: width, height: 16, cornerRadius: 6)
        .padding(.top, 30)
        .padding(.bottom, 12)
}

/// Browse is loading: six tiles and four recipe cards.
struct SearchBrowseSkeleton: View {
    var body: some View {
        SkeletonFade {
            VStack(alignment: .leading, spacing: 0) {
                headingBar(90)
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible())], spacing: 10) {
                    ForEach(0 ..< 6, id: \.self) { _ in
                        SkeletonShape(height: 96, cornerRadius: 20)
                    }
                }
                headingBar(160)
                LazyVGrid(columns: gridColumns, spacing: 12) {
                    ForEach(0 ..< 4, id: \.self) { _ in SkeletonRecipeCard() }
                }
            }
            .padding(.horizontal, HomeMetrics.inset)
            .skeletonGroup(label: String(localized: "Loading search results"))
        }
    }
}

/// One term is searching: Cooks panel, two row groups, then Everyone.
struct SearchTermSkeleton: View {
    var body: some View {
        SkeletonFade {
            VStack(alignment: .leading, spacing: 0) {
                headingBar(70)
                VStack(spacing: 12) {
                    ForEach(0 ..< 2, id: \.self) { _ in
                        HStack(spacing: 12) {
                            SkeletonCircle(size: 48)
                            SkeletonShape(width: 100, height: 11, cornerRadius: 6)
                            Spacer(minLength: 0)
                            SkeletonShape(width: 44, height: 11, cornerRadius: 6)
                        }
                    }
                }
                .padding(14)
                .cardSurface(cornerRadius: 22)
                rows(heading: 110, count: 3)
                rows(heading: 180, count: 3)
                headingBar(90)
                LazyVGrid(columns: gridColumns, spacing: 12) {
                    ForEach(0 ..< 4, id: \.self) { _ in SkeletonRecipeCard() }
                }
            }
            .padding(.horizontal, HomeMetrics.inset)
            .skeletonGroup(label: String(localized: "Loading search results"))
        }
    }

    private func rows(heading: CGFloat, count: Int) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            headingBar(heading)
            VStack(spacing: 10) {
                ForEach(0 ..< count, id: \.self) { _ in SkeletonRowCard() }
            }
        }
    }
}

/// Two or more ingredients are matching: summary block, then two row groups.
struct SearchIngredientSkeleton: View {
    var body: some View {
        SkeletonFade {
            VStack(alignment: .leading, spacing: 0) {
                SkeletonShape(height: 84, cornerRadius: 22)
                    .padding(.top, 24)
                headingBar(160)
                VStack(spacing: 10) {
                    ForEach(0 ..< 2, id: \.self) { _ in SkeletonRowCard() }
                }
                headingBar(120)
                VStack(spacing: 10) {
                    ForEach(0 ..< 4, id: \.self) { _ in SkeletonRowCard() }
                }
            }
            .padding(.horizontal, HomeMetrics.inset)
            .skeletonGroup(label: String(localized: "Loading search results"))
        }
    }
}

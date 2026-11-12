import SwiftUI

/// W245: the profile skeleton: the cream header's shape (a 96pt circle and
/// bars) over the same 4:3 grid the recipes use. Pulses stop under Reduce
/// Motion.
struct ProfileSkeleton: View {
    var body: some View {
        SkeletonFade {
            VStack(alignment: .leading, spacing: 30) {
                VStack(spacing: 14) {
                    SkeletonCircle(size: 96)
                    SkeletonShape(width: 160, height: 28, cornerRadius: 8)
                    SkeletonShape(width: 90, height: 12, cornerRadius: 6)
                    SkeletonShape(width: 200, height: 36, cornerRadius: 8)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
                .background(
                    RoundedRectangle(cornerRadius: 28, style: .continuous).fill(Theme.creamOrLift)
                )
                .padding(.horizontal, HomeMetrics.inset)
                LazyVGrid(columns: PostGrid.columns, alignment: .leading, spacing: PostGrid.spacing) {
                    ForEach(0 ..< 4, id: \.self) { _ in
                        SkeletonRecipeCard()
                    }
                }
                .padding(.horizontal, HomeMetrics.inset)
            }
            .allowsHitTesting(false)
            .skeletonGroup(label: String(localized: "Loading profile"))
        }
    }
}

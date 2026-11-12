import SwiftUI

/// W245: My Tray's list skeleton, the same 4:3 grid the lists use. Pulses
/// stop under Reduce Motion (SkeletonPulse).
struct MyTrayListSkeleton: View {
    var body: some View {
        SkeletonFade {
            LazyVGrid(columns: PostGrid.columns, alignment: .leading, spacing: PostGrid.spacing) {
                ForEach(0 ..< 4, id: \.self) { _ in
                    SkeletonRecipeCard()
                }
            }
            .padding(.horizontal, HomeMetrics.inset)
            .allowsHitTesting(false)
            .skeletonGroup(label: String(localized: "Loading your tray"))
        }
    }
}

/// W245: a failed read on My Tray, a collection or a profile. The failure is
/// logged by the view model; this never toasts (refresh failures are silent).
struct TrayLoadErrorView: View {
    let title: String
    var subtitle = String(localized: "Check your connection and try again.")
    /// nil hides Try again (a retry that cannot succeed).
    let onRetry: (() -> Void)?

    var body: some View {
        VStack(spacing: 18) {
            Circle()
                .fill(Theme.lift)
                .frame(width: 64, height: 64)
                .overlay {
                    Image(systemName: "wifi.slash")
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundStyle(Theme.muted)
                }
                .accessibilityHidden(true)
            EmptyStateBlock(
                title: title,
                subtitle: subtitle,
                topPadding: 0,
                chrome: .plain,
                action: onRetry.map { .init(title: String(localized: "Try again"), isPrimary: true, perform: $0) }
            )
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 40)
    }
}

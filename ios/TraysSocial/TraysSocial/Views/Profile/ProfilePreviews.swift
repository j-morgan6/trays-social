import SwiftUI

// W245: preview galleries for a cook's tray (Friend's tray artboard): a
// friend (Follow and Following), your own tray, a cook with no recipes,
// loading and the error state. Light, dark and largest text.

private func tray(_ user: User, posts: [Post], isOwn: Bool = false) -> some View {
    NavigationStack {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                ProfileHeader(user: user, isOwnProfile: isOwn, onToggleFollow: {})
                    .padding(.horizontal, HomeMetrics.inset)
                    .padding(.top, 6)
                ProfileRecipes(user: user, posts: posts, isOwnProfile: isOwn)
            }
            .padding(.bottom, 60)
        }
        .background(Theme.background)
    }
}

private let bio = "Cooks for four on weeknights. Mostly rice, beans and whatever the market has."

private func friend() -> some View {
    tray(
        PreviewData.user("noor", bio: bio, following: false),
        posts: PreviewData.saved + PreviewData.ownRecipes + [PreviewData.legacyPhoto]
    )
}

private func following() -> some View {
    tray(PreviewData.user("averyverylongusername_thirty00", bio: bio, following: true), posts: PreviewData.saved)
}

private func own() -> some View {
    tray(PreviewData.user("ren", bio: bio), posts: PreviewData.ownRecipes, isOwn: true)
}

private func noRecipes() -> some View {
    tray(PreviewData.user("sam", counts: (0, 3), following: false), posts: [])
}

#Preview("Friend's tray · light") { friend() }
#Preview("Friend's tray · dark") { friend().preferredColorScheme(.dark) }
#Preview("Friend's tray · largest text") { friend().dynamicTypeSize(.accessibility5) }
#Preview("Friend's tray following · light") { following() }
#Preview("Own tray · light") { own() }
#Preview("Own tray · dark") { own().preferredColorScheme(.dark) }
#Preview("Own tray · largest text") { own().dynamicTypeSize(.accessibility5) }
#Preview("No recipes · light") { noRecipes() }
#Preview("Profile loading · light") { ScrollView { ProfileSkeleton() }.background(Theme.background) }
#Preview("Profile error · light") {
    TrayLoadErrorView(title: "Couldn't load this tray", onRetry: {}).background(Theme.background)
}

#Preview("Profile error · dark") {
    TrayLoadErrorView(title: "Couldn't load this tray", onRetry: {})
        .background(Theme.background)
        .preferredColorScheme(.dark)
}

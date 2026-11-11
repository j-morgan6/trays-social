import SwiftUI

/// Bottom floating pill in the nav shell. Two slots only — Create on the
/// left and the user's Profile avatar on the right. Settings is
/// intentionally absent (it lives inside Profile).
///
/// W239 (redesign canvas, "Floating pills"): Create is an amber
/// "plus Create" capsule with ink-on-accent text, because amber is the
/// "make something" colour; the avatar is a 44pt circle. D92: the pill
/// hugs its content and AppShellView centers it horizontally.
struct BottomPill: View {
    var profilePhotoURL: String?
    var onCreateTap: () -> Void
    var onProfileTap: () -> Void

    private let avatarDiameter: CGFloat = 44

    var body: some View {
        PillBar(horizontalPadding: 5, verticalPadding: 5, spacing: 6) {
            createButton
            profileButton
        }
        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
    }

    private var createButton: some View {
        Button(action: onCreateTap) {
            HStack(spacing: 8) {
                Image(systemName: "plus")
                    .font(.system(size: 16, weight: .bold))
                Text("Create")
                    .scaledFont(15, weight: .semibold, relativeTo: .body)
            }
            .foregroundStyle(Theme.inkOnAccent)
            .padding(.leading, 10)
            .padding(.trailing, 18)
            .frame(minHeight: 44)
            .background(Capsule(style: .continuous).fill(Theme.accent))
            .contentShape(Capsule(style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Create new post")
    }

    private var profileButton: some View {
        Button(action: onProfileTap) {
            avatar
                .frame(width: avatarDiameter, height: avatarDiameter)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Your profile")
    }

    @ViewBuilder
    private var avatar: some View {
        if let urlString = profilePhotoURL, let url = urlString.asBackendURL {
            CachedAsyncImage(url: url) { image in
                image.resizable().scaledToFill()
            } placeholder: {
                Circle().fill(Theme.creamOrLift)
            }
            .frame(width: avatarDiameter, height: avatarDiameter)
            .clipShape(Circle())
            // Force SwiftUI to invalidate AsyncImage identity when the
            // URL changes (e.g. after the user uploads a new profile
            // photo). Without this, AsyncImage's internal URLCache hit
            // path can keep displaying the previous image. (D34.)
            .id(url)
        } else {
            Image(systemName: "person.fill")
                .font(.system(size: 18))
                .foregroundStyle(Theme.muted)
                .frame(width: avatarDiameter, height: avatarDiameter)
                .background(Circle().fill(Theme.creamOrLift))
        }
    }
}

#Preview("BottomPill · light") {
    BottomPill(onCreateTap: {}, onProfileTap: {})
        .padding()
        .background(Theme.background)
        .preferredColorScheme(.light)
}

#Preview("BottomPill · dark") {
    BottomPill(onCreateTap: {}, onProfileTap: {})
        .padding()
        .background(Theme.background)
        .preferredColorScheme(.dark)
}

#Preview("BottomPill · largest text") {
    BottomPill(onCreateTap: {}, onProfileTap: {})
        .padding()
        .background(Theme.background)
        .dynamicTypeSize(.accessibility5)
}

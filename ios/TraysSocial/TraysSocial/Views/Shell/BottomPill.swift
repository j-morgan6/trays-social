import SwiftUI

/// Bottom floating pill in the nav shell. Two slots only — a Create
/// FAB on the left and the user's Profile avatar on the right. Settings
/// is intentionally absent (it lives inside Profile).
///
/// Both buttons are 40pt circles to keep the visual balance Pass 1
/// implied; the touch targets are 44pt frames so accessibility stays
/// per HIG. D76: the previous 44/36 mismatch + edge-pushed Spacer
/// looked broken; HStack with explicit spacing keeps them close-but-
/// not-touching inside the pill.
struct BottomPill: View {
    var profilePhotoURL: String?
    var onCreateTap: () -> Void
    var onProfileTap: () -> Void

    private let buttonDiameter: CGFloat = 40

    var body: some View {
        PillBar {
            HStack(spacing: 14) {
                createFab
                profileButton
            }
            .frame(maxWidth: .infinity)
        }
    }

    private var createFab: some View {
        Button(action: onCreateTap) {
            Image(systemName: "plus")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(Theme.inkOnAccent)
                .frame(width: buttonDiameter, height: buttonDiameter)
                .background(
                    Circle().fill(Theme.accent)
                )
                .shadow(color: Theme.accent.opacity(0.35), radius: 8, y: 4)
                .frame(width: 44, height: 44) // HIG touch target
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Create new post")
    }

    private var profileButton: some View {
        Button(action: onProfileTap) {
            avatar
                .frame(width: 44, height: 44) // HIG touch target
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
                Circle().fill(Color(.systemGray4))
            }
            .frame(width: buttonDiameter, height: buttonDiameter)
            .clipShape(Circle())
            // Force SwiftUI to invalidate AsyncImage identity when the
            // URL changes (e.g. after the user uploads a new profile
            // photo). Without this, AsyncImage's internal URLCache hit
            // path can keep displaying the previous image. (D34.)
            .id(url)
        } else {
            Image(systemName: "person.fill")
                .font(.system(size: 18))
                .foregroundStyle(Theme.textSecondary)
                .frame(width: buttonDiameter, height: buttonDiameter)
                .background(Circle().fill(Color(.systemGray5)))
        }
    }
}

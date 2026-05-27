import SwiftUI

/// Bottom floating pill in the nav shell. Two slots only — a Create
/// FAB on the left and the user's Profile avatar on the right. Settings
/// is intentionally absent (it lives inside Profile).
///
/// The Create FAB is a 44pt amber circle with a plus glyph and a soft
/// amber drop shadow; the avatar is a 36pt circle that falls back to
/// `person.fill` when no `profilePhotoURL` is provided.
struct BottomPill: View {
    var profilePhotoURL: String?
    var onCreateTap: () -> Void
    var onProfileTap: () -> Void

    var body: some View {
        PillBar {
            createFab
            Spacer(minLength: 0)
            profileButton
        }
    }

    private var createFab: some View {
        Button(action: onCreateTap) {
            Image(systemName: "plus")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(Theme.inkOnAccent)
                .frame(width: 44, height: 44)
                .background(
                    Circle().fill(Theme.accent)
                )
                .shadow(color: Theme.accent.opacity(0.35), radius: 8, y: 4)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Create new post")
    }

    private var profileButton: some View {
        Button(action: onProfileTap) {
            avatar
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Your profile")
    }

    @ViewBuilder
    private var avatar: some View {
        if let urlString = profilePhotoURL, let url = urlString.asBackendURL {
            AsyncImage(url: url) { image in
                image.resizable().scaledToFill()
            } placeholder: {
                Circle().fill(Color(.systemGray4))
            }
            .frame(width: 36, height: 36)
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
                .frame(width: 36, height: 36)
                .background(Circle().fill(Color(.systemGray5)))
        }
    }
}

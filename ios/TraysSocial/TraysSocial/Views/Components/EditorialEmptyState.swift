import SwiftUI

/// Editorial empty-state primitive: serif italic title + optional
/// secondary subtext, centered with generous vertical padding so it
/// reads as a deliberate state rather than a blank screen.
///
/// Used by `BlockedUsersView`, `FollowListView`, and other places that
/// need a "zero results" surface that matches the project's editorial
/// voice. Pre-empts ad-hoc `Text("No X")` calls that would drift
/// visually over time.
struct EditorialEmptyState: View {
    let title: String
    var subtitle: String?
    var topPadding: CGFloat = 60

    var body: some View {
        VStack(spacing: 6) {
            Text(title)
                .font(.serifItalic(17))
                .foregroundStyle(Theme.text)
                .multilineTextAlignment(.center)

            if let subtitle, !subtitle.isEmpty {
                Text(subtitle)
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 30)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, topPadding)
    }
}

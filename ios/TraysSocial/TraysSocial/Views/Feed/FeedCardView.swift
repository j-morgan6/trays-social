import SwiftUI

/// Feed card ported from the Pass 1 prototype's `FeedCard`
/// (prototype.jsx lines 344-404).
///
/// Layout (top → bottom):
///   1. Header row: 30pt `Avi` + `@handle` + relative time
///   2. Square photo with optional cook-time badge top-left (recipes
///      only) and `SaveButtonView` top-right
///   3. Title (14pt semibold) + like/comment counts row
struct FeedCardView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.colorScheme) private var colorScheme
    let post: Post
    var onSaveTap: ((Bool) -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            photoBlock
            content
        }
        .background(Theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Theme.hairline(for: colorScheme), lineWidth: 1)
        )
        .shadow(color: colorScheme == .dark ? .clear : Color.black.opacity(0.025), radius: 2, y: 1)
        .padding(.horizontal, 16)
        .padding(.bottom, 18)
    }

    // MARK: - Header

    private var header: some View {
        Button {
            appState.navigationPath.append(post.user.username)
        } label: {
            HStack(spacing: 10) {
                Avi(
                    initial: String(post.user.username.prefix(1)),
                    size: 30,
                    palette: aviPalette(for: post),
                    border: true
                )
                Text("@\(post.user.username)")
                    .font(.system(size: 13.5, weight: .semibold))
                    .tracking(-0.135)
                    .foregroundStyle(colorScheme == .dark ? Theme.textDark : Theme.textLight)
                    .lineLimit(1)
                    .truncationMode(.tail)
                Spacer(minLength: 8)
                Text(post.insertedAt.timeAgo())
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.subtle(for: colorScheme))
                    .lineLimit(1)
                    .layoutPriority(1)
            }
            .padding(.horizontal, 14)
            .padding(.top, 12)
            .padding(.bottom, 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("@\(post.user.username), posted \(post.insertedAt.timeAgo())")
    }

    // MARK: - Photo + overlays

    private var photoBlock: some View {
        ZStack(alignment: .topLeading) {
            Photo(key: photoKey(for: post), url: post.primaryPhotoURL?.asBackendURL)
                .aspectRatio(1, contentMode: .fit)
                .clipped()

            if post.isRecipe, let badgeText = cookTimeBadgeText {
                cookTimeBadge(text: badgeText)
                    .padding(10)
            }

            SaveButtonView(
                isSaved: post.bookmarkedByCurrentUser ?? false,
                onSave: { newValue in onSaveTap?(newValue) }
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
            .padding(6)
        }
    }

    private func cookTimeBadge(text: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: "clock")
                .font(.system(size: 10, weight: .semibold))
            Text(text)
                .font(.system(size: 11, weight: .medium))
                .tracking(-0.055)
        }
        .foregroundStyle(Color.white)
        .padding(.horizontal, 9)
        .padding(.vertical, 6)
        .background(
            Capsule(style: .continuous)
                .fill(Color.black.opacity(0.55))
        )
    }

    private var cookTimeBadgeText: String? {
        guard let minutes = post.cookingTimeMinutes else { return nil }
        let time = formatCookTime(minutes: minutes)
        if let servings = post.servings {
            return "\(time) · \(servings) servings"
        }
        return time
    }

    private func formatCookTime(minutes: Int) -> String {
        let h = minutes / 60
        let m = minutes % 60
        if h == 0 { return "\(m) min" }
        if m == 0 { return "\(h)h" }
        return "\(h)h \(m)m"
    }

    // MARK: - Content

    private var content: some View {
        VStack(alignment: .leading, spacing: 9) {
            Text(cardTitle)
                .font(.system(size: 14, weight: .semibold))
                .tracking(-0.14)
                .foregroundStyle(colorScheme == .dark ? Theme.textDark : Theme.textLight)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 16) {
                metricLabel(icon: "heart", value: post.likeCount)
                metricLabel(icon: "bubble.left", value: post.commentCount)
            }
            .foregroundStyle(Theme.muted(for: colorScheme))
        }
        .padding(.horizontal, 14)
        .padding(.top, 12)
        .padding(.bottom, 14)
    }

    private func metricLabel(icon: String, value: Int) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .regular))
            Text("\(value)")
                .font(.system(size: 12, weight: .medium))
        }
    }

    private var cardTitle: String {
        let raw = (post.caption ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !raw.isEmpty else { return "Untitled" }
        let candidate = raw.components(separatedBy: CharacterSet(charactersIn: ".!?\n"))
            .first?
            .trimmingCharacters(in: .whitespaces) ?? raw
        return candidate.isEmpty ? "Untitled" : candidate
    }

    private func photoKey(for post: Post) -> FoodPalette.Key {
        let keys = FoodPalette.Key.allCases
        return keys[abs(post.id) % keys.count]
    }

    private func aviPalette(for post: Post) -> Avi.Palette {
        let palettes = Avi.Palette.allCases
        return palettes[abs(post.user.id) % palettes.count]
    }
}

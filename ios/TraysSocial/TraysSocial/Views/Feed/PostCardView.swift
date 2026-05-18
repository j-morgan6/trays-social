import SwiftUI

/// Editorial recipe card — mirrors the web Feed card from the Claude
/// Design handoff (lib/trays_social_web/live/feed_live/index.html.heex).
/// Photo on top, serif recipe title as the visual anchor, structured
/// metadata row, quiet engagement row.
struct PostCardView: View {
    @Environment(AppState.self) private var appState
    let post: Post
    var onTrayTap: (() -> Void)?
    var onLikeTap: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            heroPhoto
            content
        }
        .background(Theme.surface)
        .overlay(
            Rectangle()
                .stroke(Color.white.opacity(0.06), lineWidth: 0.5)
        )
    }

    // MARK: - Hero

    private var heroPhoto: some View {
        Group {
            if let photoURL = post.primaryPhotoURL {
                AsyncImage(url: photoURL.asBackendURL) { phase in
                    switch phase {
                    case let .success(image):
                        image
                            .resizable()
                            .scaledToFill()
                            .frame(maxWidth: .infinity)
                            .frame(height: 280)
                            .clipped()
                    case .failure:
                        photoPlaceholder
                    default:
                        photoPlaceholder
                            .overlay { ProgressView().tint(.gray) }
                    }
                }
            } else {
                photoPlaceholder
            }
        }
    }

    private var photoPlaceholder: some View {
        Rectangle()
            .fill(Color(.systemGray6))
            .frame(height: 280)
    }

    // MARK: - Content

    private var content: some View {
        VStack(alignment: .leading, spacing: 10) {
            byline
            recipeTitle
            metadataRow
            if !bodyText.isEmpty {
                cooksNote
            }
            Divider()
                .background(Color.white.opacity(0.08))
                .padding(.top, 6)
            engagementRow
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
    }

    // MARK: - Subviews

    private var byline: some View {
        Button {
            appState.navigationPath.append(post.user.username)
        } label: {
            HStack(spacing: 10) {
                avatar
                Text(post.user.username)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.text)
                Text("·")
                    .foregroundStyle(Theme.textSecondary)
                Text(post.insertedAt.timeAgo())
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.textSecondary)
                Spacer(minLength: 0)
            }
        }
        .buttonStyle(.borderless)
    }

    private var avatar: some View {
        Group {
            if let url = post.user.profilePhotoUrl, let imageURL = url.asBackendURL {
                AsyncImage(url: imageURL) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    Circle().fill(Color(.systemGray4))
                }
                .frame(width: 28, height: 28)
                .clipShape(Circle())
            } else {
                Circle()
                    .fill(Theme.primary)
                    .frame(width: 28, height: 28)
                    .overlay(
                        Text(String(post.user.username.prefix(1)).uppercased())
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.white)
                    )
            }
        }
    }

    /// Serif recipe title — derived from the first sentence/line of the
    /// caption, same convention the web card uses.
    private var recipeTitle: some View {
        Text(titleText)
            .font(.serif(28))
            .foregroundStyle(Theme.text)
            .fixedSize(horizontal: false, vertical: true)
            .lineLimit(2)
    }

    private var metadataRow: some View {
        HStack(spacing: 6) {
            if let time = post.cookingTimeMinutes {
                Image(systemName: "clock")
                    .font(.system(size: 10))
                Text("\(time) min")
            }
            if !post.ingredients.isEmpty {
                Text("·")
                Text("\(post.ingredients.count) ingredients")
            }
            if !post.tools.isEmpty {
                Text("·")
                Text("\(post.tools.count) tools")
            }
            if let servings = post.servings {
                Text("·")
                Text("serves \(servings)")
            }
        }
        .font(.system(size: 12))
        .foregroundStyle(Theme.textSecondary)
    }

    private var cooksNote: some View {
        Text(bodyText)
            .font(.system(size: 14))
            .foregroundStyle(Theme.text.opacity(0.9))
            .lineLimit(2)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var engagementRow: some View {
        HStack(spacing: 18) {
            Button {
                onLikeTap?()
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: post.likedByCurrentUser ? "heart.fill" : "heart")
                    Text("\(post.likeCount)")
                }
                .foregroundStyle(post.likedByCurrentUser ? Theme.primaryLight : Theme.textSecondary)
            }
            .buttonStyle(.borderless)

            HStack(spacing: 5) {
                Image(systemName: "bubble.right")
                Text("\(post.commentCount)")
            }
            .foregroundStyle(Theme.textSecondary)

            Button {
                onTrayTap?()
            } label: {
                Image(systemName: (post.bookmarkedByCurrentUser ?? false) ? "bookmark.fill" : "bookmark")
                    .foregroundStyle((post.bookmarkedByCurrentUser ?? false) ? Theme.primaryLight : Theme.textSecondary)
            }
            .buttonStyle(.borderless)

            Spacer()

            Image(systemName: "square.and.arrow.up")
                .foregroundStyle(Theme.textSecondary)
        }
        .font(.system(size: 12))
        // Touch targets stay 44pt without ballooning the visual row.
        .frame(minHeight: 24)
    }

    // MARK: - Title / body derivation

    /// First sentence (or line) of the caption — the editorial title.
    private var titleText: String {
        let raw = (post.caption ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !raw.isEmpty else { return "Untitled recipe" }

        let candidate = raw.components(separatedBy: CharacterSet(charactersIn: ".!?\n"))
            .first?
            .trimmingCharacters(in: .whitespaces) ?? raw

        return candidate.isEmpty ? "Untitled recipe" : candidate
    }

    /// Everything after the title — rendered as a quiet cook's note.
    private var bodyText: String {
        let raw = (post.caption ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let title = titleText
        guard raw.count > title.count else { return "" }

        return raw.dropFirst(title.count)
            .trimmingCharacters(in: CharacterSet(charactersIn: " \n\t.!?"))
    }
}

// MARK: - Badge Pill

//
// Compact rounded pill used by other screens (FindView) for chips.
// Lives here for now to avoid creating a new file; move to Components/
// if more screens need it.

struct BadgePill: View {
    let text: String
    let color: Color

    var body: some View {
        Text(text)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(color)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 6))
    }
}

// MARK: - Date Extension

extension Date {
    func timeAgo() -> String {
        let seconds = -timeIntervalSinceNow
        if seconds < 60 { return "now" }
        if seconds < 3600 { return "\(Int(seconds / 60))m" }
        if seconds < 86400 { return "\(Int(seconds / 3600))h" }
        if seconds < 604_800 { return "\(Int(seconds / 86400))d" }
        return "\(Int(seconds / 604_800))w"
    }
}

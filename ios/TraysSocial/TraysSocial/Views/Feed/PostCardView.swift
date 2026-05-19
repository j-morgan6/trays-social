import SwiftUI

/// Editorial recipe card — matches `IOSRecipeCard` from the Claude
/// Design handoff (design/handoff/trays-social/project/shared.jsx).
///
/// Layout (top → bottom):
///   1. Header row: avatar · cook + relative time · bookmark icon
///   2. Photo (320pt tall)
///   3. Serif 22pt title
///   4. Teaser caption (12pt muted)
///   5. Hairline + engagement row (heart, comment count, save count, share)
///
/// `isDiscovery` adds a Mint Whisper "Suggested" eyebrow next to the
/// cook's name — used for posts interleaved from Find into the feed.
struct PostCardView: View {
    @Environment(AppState.self) private var appState
    let post: Post
    var isDiscovery: Bool = false
    var onTrayTap: (() -> Void)?
    var onLikeTap: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            headerRow
            heroPhoto
            content
        }
        .background(Theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white.opacity(0.06), lineWidth: 0.5)
        )
    }

    // MARK: - Header row

    private var headerRow: some View {
        HStack(spacing: 10) {
            Button {
                appState.navigationPath.append(post.user.username)
            } label: {
                HStack(spacing: 10) {
                    avatar
                    VStack(alignment: .leading, spacing: 1) {
                        HStack(spacing: 6) {
                            Text(post.user.username)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(Theme.text)
                            if isDiscovery {
                                Text("· SUGGESTED")
                                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                                    .foregroundStyle(Theme.secondary)
                                    .tracking(1.2)
                            }
                        }
                        Text("\(post.insertedAt.timeAgo()) ago")
                            .font(.system(size: 11))
                            .foregroundStyle(Theme.textSecondary)
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Spacer(minLength: 0)

            Button {
                onTrayTap?()
            } label: {
                Image(systemName: bookmarked ? "bookmark.fill" : "bookmark")
                    .font(.system(size: 16))
                    .foregroundStyle(bookmarked ? Theme.accent : Theme.textSecondary)
            }
            .buttonStyle(.borderless)
        }
        .padding(.horizontal, 16)
        .padding(.top, 14)
        .padding(.bottom, 10)
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
                            .frame(height: 320)
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
            .frame(height: 320)
    }

    // MARK: - Content

    private var content: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(titleText)
                .font(.serif(22))
                .foregroundStyle(Theme.text)
                .fixedSize(horizontal: false, vertical: true)
                .lineLimit(2)

            if !teaserText.isEmpty {
                Text(teaserText)
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.textSecondary)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
                    .lineLimit(3)
            }

            Divider()
                .background(Color.white.opacity(0.08))
                .padding(.top, 6)

            engagementRow
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
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

            // Save COUNT (not a toggle — toggle lives in the header row).
            // Today there's no saves_count on the API; we surface the
            // current cook's own bookmark state as a hint instead.
            HStack(spacing: 5) {
                Image(systemName: "bookmark")
                Text(bookmarked ? "Saved" : "Save")
            }
            .foregroundStyle(Theme.textSecondary)

            Spacer()

            Image(systemName: "square.and.arrow.up")
                .foregroundStyle(Theme.textSecondary)
        }
        .font(.system(size: 12))
        .frame(minHeight: 24)
    }

    // MARK: - Subviews

    private var avatar: some View {
        Group {
            if let url = post.user.profilePhotoUrl, let imageURL = url.asBackendURL {
                AsyncImage(url: imageURL) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    Circle().fill(Color(.systemGray4))
                }
                .frame(width: 32, height: 32)
                .clipShape(Circle())
            } else {
                Circle()
                    .fill(Theme.primary)
                    .frame(width: 32, height: 32)
                    .overlay(
                        Text(String(post.user.username.prefix(1)).uppercased())
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.white)
                    )
            }
        }
    }

    // MARK: - Derived state

    private var bookmarked: Bool {
        post.bookmarkedByCurrentUser ?? false
    }

    /// First sentence (or line) of the caption — the editorial title.
    private var titleText: String {
        let raw = (post.caption ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !raw.isEmpty else { return "Untitled recipe" }
        let candidate = raw.components(separatedBy: CharacterSet(charactersIn: ".!?\n"))
            .first?
            .trimmingCharacters(in: .whitespaces) ?? raw
        return candidate.isEmpty ? "Untitled recipe" : candidate
    }

    /// Everything after the title — the muted teaser caption that sits
    /// below the serif title in the design.
    private var teaserText: String {
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

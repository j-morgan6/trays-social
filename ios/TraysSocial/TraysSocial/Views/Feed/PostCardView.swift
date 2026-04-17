import SwiftUI

struct PostCardView: View {
    @Environment(AppState.self) private var appState
    let post: Post
    var onTrayTap: (() -> Void)?
    var onLikeTap: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Photo with badges
            ZStack(alignment: .bottom) {
                if let photoURL = post.primaryPhotoURL {
                    AsyncImage(url: photoURL.asBackendURL) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .scaledToFill()
                                .frame(maxWidth: .infinity)
                                .frame(height: 300)
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

                // Badges overlay
                HStack {
                    // Cooking time + servings
                    HStack(spacing: 6) {
                        if let time = post.cookingTimeMinutes {
                            BadgePill(text: "\(time) min", color: .orange)
                        }
                        if let servings = post.servings {
                            BadgePill(text: "\(servings) servings", color: Color(.systemGray))
                        }
                    }

                    Spacer()
                }
                .padding(10)
            }

            // Post info
            VStack(alignment: .leading, spacing: 6) {
                // Title
                if let caption = post.caption, !caption.isEmpty {
                    Text(post.isRecipe ? caption : caption)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(Theme.text)
                        .lineLimit(2)
                }

                // Author + time + counts
                HStack {
                    Button {
                        appState.navigationPath.append(post.user.username)
                    } label: {
                        HStack(spacing: 6) {
                            Circle()
                                .fill(Color(.systemGray4))
                                .frame(width: 40, height: 40)
                                .overlay {
                                    if let url = post.user.profilePhotoUrl, let imageURL = url.asBackendURL {
                                        AsyncImage(url: imageURL) { image in
                                            image.resizable().scaledToFill()
                                        } placeholder: {
                                            Color.clear
                                        }
                                        .frame(width: 40, height: 40)
                                        .clipShape(Circle())
                                    }
                                }

                            Text(post.user.username)
                                .font(.headline)
                                .foregroundStyle(.gray)

                            Text("|")
                                .font(.subheadline)
                                .foregroundStyle(Color(.systemGray3))

                            Text(post.insertedAt.timeAgo())
                                .font(.subheadline)
                                .foregroundStyle(Color(.systemGray2))
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.borderless)

                    Spacer()

                    HStack(spacing: 4) {
                        Button(action: { onLikeTap?() }) {
                            Label("\(post.likeCount)", systemImage: post.likedByCurrentUser ? "heart.fill" : "heart")
                                .foregroundStyle(post.likedByCurrentUser ? .red : Color(.systemGray2))
                                .frame(minWidth: 44, minHeight: 44)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.borderless)

                        Label("\(post.commentCount)", systemImage: "bubble.right")
                            .frame(minWidth: 44, minHeight: 44)

                        Button(action: { onTrayTap?() }) {
                            Image(systemName: (post.bookmarkedByCurrentUser ?? false) ? "bookmark.fill" : "bookmark")
                                .foregroundStyle((post.bookmarkedByCurrentUser ?? false) ? Theme.accent : Color(.systemGray2))
                                .frame(minWidth: 44, minHeight: 44)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.borderless)
                    }
                    .font(.subheadline)
                    .foregroundStyle(Color(.systemGray2))
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .background(Theme.background)
    }

    private var photoPlaceholder: some View {
        Rectangle()
            .fill(Color(.systemGray6))
            .frame(height: 300)
    }

}

// MARK: - Badge Pill

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
        let seconds = -self.timeIntervalSinceNow
        if seconds < 60 { return "now" }
        if seconds < 3600 { return "\(Int(seconds / 60))m" }
        if seconds < 86400 { return "\(Int(seconds / 3600))h" }
        if seconds < 604800 { return "\(Int(seconds / 86400))d" }
        return "\(Int(seconds / 604800))w"
    }
}

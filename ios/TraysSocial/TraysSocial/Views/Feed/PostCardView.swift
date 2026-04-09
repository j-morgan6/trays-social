import SwiftUI

struct PostCardView: View {
    let post: Post
    var onTrayTap: (() -> Void)?
    var onUserTap: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Photo with badges
            ZStack(alignment: .bottom) {
                if let photoURL = post.primaryPhotoURL {
                    AsyncImage(url: fullURL(photoURL)) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .scaledToFill()
                                .frame(maxWidth: .infinity)
                                .frame(height: 240)
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
            .overlay(alignment: .topTrailing) {
                // + Tray button
                Button(action: { onTrayTap?() }) {
                    Text("+ Tray")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.orange)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(.ultraThinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .padding(10)
            }

            // Post info
            VStack(alignment: .leading, spacing: 6) {
                // Title
                if let caption = post.caption, !caption.isEmpty {
                    Text(post.isRecipe ? caption : caption)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.white)
                        .lineLimit(2)
                }

                // Author + time + counts
                HStack {
                    Button(action: { onUserTap?() }) {
                        HStack(spacing: 6) {
                            Circle()
                                .fill(Color(.systemGray4))
                                .frame(width: 20, height: 20)
                                .overlay {
                                    if let url = post.user.profilePhotoUrl, let imageURL = fullURL(url) {
                                        AsyncImage(url: imageURL) { image in
                                            image.resizable().scaledToFill()
                                        } placeholder: {
                                            Color.clear
                                        }
                                        .frame(width: 20, height: 20)
                                        .clipShape(Circle())
                                    }
                                }

                            Text(post.user.username)
                                .font(.caption)
                                .foregroundStyle(.gray)

                            Text("|")
                                .font(.caption2)
                                .foregroundStyle(Color(.systemGray3))

                            Text(post.insertedAt.timeAgo())
                                .font(.caption)
                                .foregroundStyle(Color(.systemGray2))
                        }
                    }
                    .buttonStyle(.plain)

                    Spacer()

                    HStack(spacing: 12) {
                        Label("\(post.likeCount)", systemImage: "heart")
                        Label("\(post.commentCount)", systemImage: "bubble.right")
                    }
                    .font(.caption)
                    .foregroundStyle(Color(.systemGray2))
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .background(.black)
    }

    private var photoPlaceholder: some View {
        Rectangle()
            .fill(Color(.systemGray6))
            .frame(height: 240)
    }

    private func fullURL(_ path: String) -> URL? {
        if path.hasPrefix("http") {
            return URL(string: path)
        }
        return URL(string: Configuration.apiBaseURL + path)
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

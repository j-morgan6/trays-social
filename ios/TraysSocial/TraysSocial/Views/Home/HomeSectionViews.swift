import SwiftUI

/// Small building blocks for HomeView, split out to keep HomeView's body
/// under the SwiftLint body-length limit. Tiles set their own text colour
/// because the `.borderless` NavigationLinks that host them tint labels.
enum HomeTiles {
    static func photoKey(_ id: Int) -> FoodPalette.Key {
        let keys = FoodPalette.Key.allCases
        return keys[abs(id) % keys.count]
    }
}

/// Compact "Jump back in" tile: thumbnail plus title.
struct JumpBackInTile: View {
    let post: Post

    var body: some View {
        HStack(spacing: 8) {
            Photo(key: HomeTiles.photoKey(post.id), url: post.thumbURL?.asBackendURL)
                .frame(width: 40, height: 40)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            Text(RecipeTitle.from(caption: post.caption))
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Theme.text)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
            Spacer(minLength: 0)
        }
        .padding(6)
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Theme.surface))
    }
}

/// Round avatar with the username underneath, used for Friends' trays and
/// suggested cooks.
struct CookAvatar: View {
    let id: Int
    let username: String
    let photoURL: String?
    var caption: String?

    var body: some View {
        VStack(spacing: 4) {
            Photo(key: HomeTiles.photoKey(id), url: photoURL?.asBackendURL)
                .frame(width: 56, height: 56)
                .clipShape(Circle())
            Text(username)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Theme.text)
                .lineLimit(1)
            if let caption {
                Text(caption).font(.system(size: 11)).foregroundStyle(.secondary)
            }
        }
        .frame(width: 72)
        .accessibilityElement(children: .combine)
    }
}

/// End-of-row card for the finite friends row.
struct CaughtUpCard: View {
    let isEmpty: Bool

    var body: some View {
        Text(isEmpty ? "Nothing new this week" : "You're caught up")
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
            .frame(width: 140, height: 154)
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [4]))
                    .foregroundStyle(.secondary.opacity(0.4))
            )
    }
}

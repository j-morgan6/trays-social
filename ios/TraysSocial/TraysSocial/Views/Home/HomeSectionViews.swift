import SwiftUI

/// Building blocks for HomeView (W241 redesign). Split out to keep each
/// view under the SwiftLint body-length limit.
enum HomeTiles {
    static func photoKey(_ id: Int) -> FoodPalette.Key {
        let keys = FoodPalette.Key.allCases
        return keys[abs(id) % keys.count]
    }
}

/// "Thursday evening" kicker over the rounded "What are you cooking?" line.
struct HomeGreetingHeader: View {
    struct Greeting {
        let kicker: String
        let question: String
    }

    let greeting: Greeting

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(greeting.kicker)
                .scaledFont(15, weight: .semibold, relativeTo: .subheadline)
                .foregroundStyle(Theme.muted)
            Text(greeting.question)
                .roundedFont(31, weight: .heavy, relativeTo: .largeTitle)
                .foregroundStyle(Theme.text)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, HomeMetrics.inset)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }
}

/// Section heading with the canvas spacing (30 above, 12 below). The shared
/// SectionHeader pads itself by 20; Home's inset is 18.
struct HomeSectionHeading: View {
    let label: String
    var onSeeAll: (() -> Void)?

    var body: some View {
        SectionHeader(label: label, onSeeAll: onSeeAll)
            .padding(.horizontal, HomeMetrics.inset - 20)
            .padding(.top, 30)
            .padding(.bottom, 12)
    }
}

/// A Home post as the shared RecipeCard.
struct HomeRecipeCard: View {
    let post: Post
    let aspectRatio: CGFloat
    var context: String?
    var isNew = false

    var body: some View {
        RecipeCard(
            title: RecipeTitle.from(caption: post.caption),
            photoURL: post.primaryPhotoURL?.asBackendURL,
            authorName: post.user.username,
            authorAvatarURL: post.user.profilePhotoUrl?.asBackendURL,
            context: context,
            cookTime: CookTime.label(minutes: post.cookingTimeMinutes),
            badge: isNew ? .new : nil,
            kind: post.isRecipe ? .recipe : .photoPost,
            photoAspectRatio: aspectRatio
        )
    }
}

/// Amber "Tonight" strip that opens the planner (Plus only).
struct HomeTonightStrip: View {
    let entry: MealPlanEntry
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                PhotoSlot(url: entry.post.thumbURL, cornerRadius: 22)
                    .frame(width: 44, height: 44)
                    .clipShape(Circle())
                VStack(alignment: .leading, spacing: 1) {
                    Text("Tonight")
                        .scaledFont(12.5, weight: .bold, relativeTo: .caption)
                        .foregroundStyle(Theme.text)
                    Text(entry.post.title)
                        .scaledFont(15, weight: .semibold, relativeTo: .subheadline)
                        .foregroundStyle(Theme.text)
                        .lineLimit(1)
                }
                Spacer(minLength: 8)
                weekChip
            }
            .padding(6)
            .frame(minHeight: 56)
            .background(Capsule(style: .continuous).fill(Theme.accentMuted))
            .overlay(Capsule(style: .continuous).strokeBorder(Theme.accentBorder, lineWidth: 1))
            .contentShape(Capsule(style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityHint(String(localized: "Opens the week planner"))
    }

    private var weekChip: some View {
        HStack(spacing: 4) {
            Text("Week")
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .accessibilityHidden(true)
        }
        .scaledFont(14, weight: .semibold, relativeTo: .subheadline)
        .foregroundStyle(Theme.text)
        .padding(.horizontal, 14)
        .frame(minHeight: 40)
        .background(Capsule(style: .continuous).fill(Theme.surface))
    }
}

/// Friend in the Friends' trays row: 64pt avatar and username. No new-count
/// badge or ring (D16 keeps that an idea).
struct HomeFriendAvatar: View {
    let username: String
    let photoURL: URL?

    var body: some View {
        VStack(spacing: 7) {
            AvatarSlot(url: photoURL, size: 64)
            Text(username)
                .scaledFont(13, weight: .semibold, relativeTo: .footnote)
                .foregroundStyle(Theme.text)
                .lineLimit(1)
                .truncationMode(.tail)
        }
        .frame(width: 70)
        .accessibilityElement(children: .combine)
    }
}

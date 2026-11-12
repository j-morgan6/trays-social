import SwiftUI

/// W247: the sheet under the hero (Recipe artboard). It rises over the
/// bottom of the photo with rounded top corners and holds, for a recipe, the
/// kicker and title, the cook's byline, the meta capsules, the Saved row, the
/// cook's note and the Helpful chip. A legacy photo post shows the byline,
/// its caption, the "photo post" note and the Helpful chip: no title, meta,
/// Saved row or cook's note.
struct RecipeHeadSheet: View {
    let post: Post
    let onOpenAuthor: () -> Void
    let onToggleLike: () -> Void

    private var isSaved: Bool {
        post.bookmarkedByCurrentUser == true
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if post.isRecipe {
                RecipeTitleBlock(
                    kicker: RecipeMeta.kicker(tags: post.tags),
                    title: RecipeTitle.from(caption: post.caption, fallback: String(localized: "Untitled recipe"))
                )
                .padding(.bottom, 14)
            }

            RecipeBylineRow(
                username: post.user.username,
                avatarURL: post.user.profilePhotoUrl?.asBackendURL,
                context: post.insertedAt.timeAgo(),
                onOpen: onOpenAuthor
            )

            if post.isRecipe {
                recipeDetails
            } else {
                legacyDetails
            }

            HelpfulChip(
                count: post.likeCount,
                isOn: post.likedByCurrentUser,
                action: onToggleLike
            )
            .padding(.top, 18)
        }
        .padding(.horizontal, 20)
        .padding(.top, 24)
        .padding(.bottom, 4)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            UnevenRoundedRectangle(
                topLeadingRadius: RecipeHero.sheetOverlap,
                topTrailingRadius: RecipeHero.sheetOverlap,
                style: .continuous
            )
            .fill(Theme.background)
        )
        .padding(.top, -RecipeHero.sheetOverlap)
    }

    @ViewBuilder
    private var recipeDetails: some View {
        let capsules = RecipeMeta.capsules(for: post)
        if !capsules.isEmpty {
            RecipeMetaRow(capsules: capsules)
                .padding(.top, 16)
        }

        if isSaved {
            SavedNote()
                .padding(.top, 12)
        }

        let note = RecipeTitle.note(caption: post.caption)
        if !note.isEmpty {
            CookNote(label: RecipeMeta.noteLabel(username: post.user.username), text: note)
                .padding(.top, 18)
        }
    }

    @ViewBuilder
    private var legacyDetails: some View {
        if let caption = post.caption?.trimmingCharacters(in: .whitespacesAndNewlines), !caption.isEmpty {
            Text(caption)
                .scaledFont(17, relativeTo: .body)
                .foregroundStyle(Theme.text)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 14)
        }
        Text("A photo post from before Trays had recipes. It can be saved, but has no ingredients or steps.")
            .scaledFont(13, relativeTo: .footnote)
            .foregroundStyle(Theme.muted)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Theme.lift))
            .padding(.top, 14)
    }
}

/// W247: the kicker (the recipe's first tags) over the rounded title. The
/// title is capped at three lines at every text size.
struct RecipeTitleBlock: View {
    static let titleLineLimit = 3

    let kicker: String?
    let title: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let kicker {
                Text(kicker)
                    .scaledFont(13.5, weight: .semibold, relativeTo: .subheadline)
                    .foregroundStyle(Theme.muted)
                    .lineLimit(1)
            }
            Text(title)
                .roundedFont(28, weight: .heavy, relativeTo: .title)
                .foregroundStyle(Theme.text)
                .lineLimit(Self.titleLineLimit)
                .truncationMode(.tail)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
        }
    }
}

/// W247: 40pt avatar, the cook and how long ago; opens the cook's tray.
struct RecipeBylineRow: View {
    let username: String
    let avatarURL: URL?
    let context: String
    let onOpen: () -> Void

    var body: some View {
        Button(action: onOpen) {
            HStack(spacing: 10) {
                AvatarSlot(url: avatarURL, size: 40)
                VStack(alignment: .leading, spacing: 1) {
                    Text(username)
                        .scaledFont(15, weight: .bold, relativeTo: .subheadline)
                        .foregroundStyle(Theme.text)
                        .lineLimit(1)
                        .truncationMode(.tail)
                    Text(context)
                        .scaledFont(13, relativeTo: .footnote)
                        .foregroundStyle(Theme.muted)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityHint(Text("Opens this cook's tray"))
    }
}

/// W247: the meta capsules (time, servings, ingredient count). They wrap
/// onto more lines at large text sizes rather than clipping.
struct RecipeMetaRow: View {
    let capsules: [RecipeMeta.Capsule]

    var body: some View {
        FlowLayout(spacing: 8) {
            ForEach(capsules) { capsule in
                RecipeMetaCapsule(capsule: capsule)
            }
        }
    }
}

/// One meta capsule: an icon and its value on the lift fill.
struct RecipeMetaCapsule: View {
    let capsule: RecipeMeta.Capsule

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: capsule.systemImage)
                .foregroundStyle(Theme.muted)
                .accessibilityHidden(true)
            Text(capsule.text)
                .foregroundStyle(Theme.text)
                .lineLimit(1)
        }
        .scaledFont(13.5, weight: .semibold, relativeTo: .subheadline)
        .padding(.horizontal, 12)
        .frame(minHeight: 34)
        .background(Capsule(style: .continuous).fill(Theme.lift))
    }
}

/// W247: the Saved row. Collections are not known on a post, so it names
/// My Tray, as the web recipe page does.
struct SavedNote: View {
    var body: some View {
        Label(String(localized: "Saved to My Tray"), systemImage: "checkmark")
            .scaledFont(13, weight: .bold, relativeTo: .footnote)
            .foregroundStyle(Theme.primaryInk)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Capsule(style: .continuous).fill(Theme.mintTint))
    }
}

/// W247: the rest of the caption as the cook's note, on a labelled cream
/// card ("From noor").
struct CookNote: View {
    let label: String
    let text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .scaledFont(12.5, weight: .bold, relativeTo: .caption)
                .foregroundStyle(Theme.muted)
            Text(text)
                .scaledFont(15, relativeTo: .body)
                .foregroundStyle(Theme.text)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(Theme.creamOrLift))
        .accessibilityElement(children: .combine)
    }
}

/// W247: the Helpful count as a quiet capsule. Save moved to the bottom
/// action pill.
private struct HelpfulChip: View {
    let count: Int
    let isOn: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(String(localized: "\(count) helpful"), systemImage: isOn ? "heart.fill" : "heart")
                .scaledFont(13.5, weight: .semibold, relativeTo: .subheadline)
                .foregroundStyle(isOn ? Theme.primaryInk : Theme.text)
                .padding(.horizontal, 14)
                .frame(minHeight: 36)
                .background(Capsule(style: .continuous).fill(isOn ? Theme.mintTint : Theme.lift))
                .contentShape(Capsule(style: .continuous))
        }
        .buttonStyle(.borderless)
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }
}

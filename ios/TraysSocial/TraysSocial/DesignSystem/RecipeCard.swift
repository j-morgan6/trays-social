import SwiftUI

/// W239: the redesign's recipe card (Components artboard, "Recipe card").
/// Used by Jump back in (4:3), the new-from-follows row (4:5) and the
/// masonry grids (mixed ratios). The cook is always named and the cook time
/// rides on the photo. Content only: callers wrap it in a NavigationLink or
/// a `.plain` Button.
struct RecipeCard: View {
    enum Badge: Equatable {
        case new
        case rank(Int)
    }

    enum Kind: Equatable {
        case recipe
        case photoPost
    }

    let title: String
    let photoURL: URL?
    let authorName: String
    var authorAvatarURL: URL?
    var context: String?
    var cookTime: String?
    var badge: Badge?
    var kind: Kind = .recipe
    var photoAspectRatio: CGFloat = 4.0 / 3.0

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            photo
            details
        }
        .padding(6)
        .cardSurface(cornerRadius: 21)
        .accessibilityElement(children: .combine)
    }

    private var photo: some View {
        PhotoSlot(url: photoURL, cornerRadius: 15)
            .aspectRatio(photoAspectRatio, contentMode: .fit)
            .overlay(alignment: .topLeading) { badgeView.padding(8) }
            .overlay(alignment: .bottomLeading) { timePill.padding(8) }
    }

    @ViewBuilder
    private var badgeView: some View {
        if kind == .photoPost {
            tag(Text("Photo"), fill: Theme.surface, foreground: Theme.text)
        } else if let badge {
            switch badge {
            case .new:
                tag(Text("New"), fill: Theme.accent, foreground: Theme.inkOnAccent)
            case let .rank(rank):
                tag(Text(verbatim: "#\(rank)"), fill: Theme.accent, foreground: Theme.inkOnAccent)
            }
        }
    }

    private func tag(_ text: Text, fill: Color, foreground: Color) -> some View {
        text
            .scaledFont(11.5, weight: .bold, relativeTo: .caption)
            .foregroundStyle(foreground)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(Capsule(style: .continuous).fill(fill))
    }

    @ViewBuilder
    private var timePill: some View {
        if kind == .recipe, let cookTime {
            Text(cookTime)
                .scaledFont(12, weight: .semibold, relativeTo: .caption)
                .foregroundStyle(Theme.text)
                .padding(.horizontal, 9)
                .padding(.vertical, 4)
                .background {
                    ZStack {
                        Capsule(style: .continuous).fill(.ultraThinMaterial)
                        Capsule(style: .continuous).fill(Theme.pill)
                    }
                }
        }
    }

    private var details: some View {
        VStack(alignment: .leading, spacing: 7) {
            titleText
            byline
        }
        .padding(.top, 9)
        .padding(.horizontal, 6)
        .padding(.bottom, 6)
    }

    @ViewBuilder
    private var titleText: some View {
        if kind == .photoPost {
            Text(title)
                .scaledFont(14, relativeTo: .subheadline)
                .foregroundStyle(Theme.text)
                .lineLimit(2)
        } else {
            Text(title)
                .roundedFont(.cardTitle)
                .foregroundStyle(Theme.text)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
        }
    }

    private var byline: some View {
        HStack(spacing: 6) {
            AvatarSlot(url: authorAvatarURL, size: 22)
            Text(authorName)
                .scaledFont(12.5, weight: .semibold, relativeTo: .caption)
                .foregroundStyle(Theme.text)
            if let context {
                Text(verbatim: "·")
                    .foregroundStyle(Theme.muted)
                Text(context)
                    .scaledFont(12.5, relativeTo: .caption)
                    .foregroundStyle(Theme.muted)
            }
        }
        .lineLimit(1)
    }
}

private struct RecipeCardGallery: View {
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            RecipeCard(
                title: "Miso butter salmon",
                photoURL: nil,
                authorName: "You",
                context: "Opened today",
                cookTime: "25 min"
            )
            RecipeCard(
                title: "Harissa chickpea stew",
                photoURL: nil,
                authorName: "Noor",
                context: "Yesterday",
                cookTime: "40 min",
                badge: .new,
                photoAspectRatio: 4.0 / 5.0
            )
        }
        .padding()
        .background(Theme.background)
    }
}

#Preview("RecipeCard · light") {
    RecipeCardGallery().preferredColorScheme(.light)
}

#Preview("RecipeCard · dark") {
    RecipeCardGallery().preferredColorScheme(.dark)
}

#Preview("RecipeCard · largest text") {
    RecipeCardGallery().dynamicTypeSize(.accessibility5)
}

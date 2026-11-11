import SwiftUI

/// W239: the redesign's row card (Components artboard, "Row card"), for
/// Search groups and ingredient results. Each row is its own small card so
/// a list reads like recipe cards on a counter, not a table. Content only:
/// callers wrap it in a NavigationLink or a `.plain` Button.
struct RowCard: View {
    enum Match: Equatable {
        case readyToCook
        case need(Int)
    }

    let title: String
    let photoURL: URL?
    var authorName: String?
    var authorAvatarURL: URL?
    var detail: String?
    var match: Match?
    var uses: String?
    var missing: [String] = []

    var body: some View {
        HStack(spacing: 14) {
            PhotoSlot(url: photoURL, cornerRadius: 14)
                .frame(width: 72, height: 72)
            VStack(alignment: .leading, spacing: 5) {
                Text(title)
                    .roundedFont(.cardTitle)
                    .foregroundStyle(Theme.text)
                    .lineLimit(1)
                byline
                matchRow
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Theme.muted)
                .accessibilityHidden(true)
        }
        .padding(.leading, 8)
        .padding(.vertical, 8)
        .padding(.trailing, 12)
        .cardSurface(cornerRadius: 20)
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private var byline: some View {
        if authorName != nil || detail != nil {
            HStack(spacing: 6) {
                if let authorName {
                    AvatarSlot(url: authorAvatarURL, size: 22)
                    Text(authorName)
                        .scaledFont(12.5, weight: .semibold, relativeTo: .caption)
                        .foregroundStyle(Theme.text)
                }
                if authorName != nil, detail != nil {
                    Text(verbatim: "·").foregroundStyle(Theme.muted)
                }
                if let detail {
                    Text(detail)
                        .scaledFont(12.5, relativeTo: .caption)
                        .foregroundStyle(Theme.muted)
                }
            }
            .lineLimit(1)
        }
    }

    @ViewBuilder
    private var matchRow: some View {
        if match != nil || uses != nil || !missing.isEmpty {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 8) { matchContent }
                VStack(alignment: .leading, spacing: 4) { matchContent }
            }
        }
    }

    @ViewBuilder
    private var matchContent: some View {
        if let match {
            matchPill(match)
        }
        if !missing.isEmpty {
            HStack(spacing: 4) {
                Text("missing:")
                    .fontWeight(.semibold)
                    .foregroundStyle(Theme.text)
                Text(missing.joined(separator: ", "))
                    .foregroundStyle(Theme.muted)
            }
            .scaledFont(12.5, relativeTo: .caption)
            .lineLimit(1)
        } else if let uses {
            Text(uses)
                .scaledFont(12.5, relativeTo: .caption)
                .foregroundStyle(Theme.muted)
                .lineLimit(1)
        }
    }

    private func matchPill(_ match: Match) -> some View {
        let isReady = match == .readyToCook
        let label = switch match {
        case .readyToCook: Text("Ready to cook")
        case let .need(count): Text("Need \(count)")
        }
        return label
            .scaledFont(12, weight: .bold, relativeTo: .caption)
            .foregroundStyle(isReady ? Theme.primaryInk : Theme.text)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(Capsule(style: .continuous).fill(isReady ? Theme.mintTint : Theme.accentMuted))
    }
}

private struct RowCardGallery: View {
    var body: some View {
        VStack(spacing: 10) {
            RowCard(
                title: "Garlic chicken and crispy rice",
                photoURL: nil,
                authorName: "Lucia",
                detail: "35 min",
                match: .readyToCook,
                uses: "Uses chicken, rice"
            )
            RowCard(
                title: "Ginger chicken rice bowls",
                photoURL: nil,
                authorName: "Noor",
                detail: "30 min",
                match: .need(2),
                missing: ["soy sauce", "ginger"]
            )
        }
        .padding()
        .background(Theme.background)
    }
}

#Preview("RowCard · light") {
    RowCardGallery().preferredColorScheme(.light)
}

#Preview("RowCard · dark") {
    RowCardGallery().preferredColorScheme(.dark)
}

#Preview("RowCard · largest text") {
    RowCardGallery().dynamicTypeSize(.accessibility5)
}

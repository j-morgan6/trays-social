import SwiftUI

/// Section header used by Home, Search, My Tray and other screens.
///
/// W239 (redesign canvas, "Section heading"): `.compact` is a plain,
/// sentence-case heading in the rounded design, 20pt bold, with an optional
/// muted aside or count and an optional "See all" in primary ink with a
/// 44pt hit height.
///
/// W144: opt-in `style: .editorial` renders the label at 22pt
/// semibold (matching FeedView's headline) and centers it. Used by
/// MyTrayView for the "Recipes" / "Saved posts" rows so they read at
/// the same scale as the top heading. The `onSeeAll` affordance is
/// suppressed in `.editorial` since it would look orphaned next to a
/// centered label.
struct SectionHeader: View {
    @Environment(\.colorScheme) private var colorScheme
    let label: String
    var count: Int?
    var onSeeAll: (() -> Void)?
    var style: Style = .compact
    /// Optional muted aside after the label, e.g. "Newest first".
    var aside: String?

    enum Style {
        case compact
        case editorial
    }

    var body: some View {
        switch style {
        case .compact: compactBody
        case .editorial: editorialBody
        }
    }

    private var compactBody: some View {
        HStack(alignment: .firstTextBaseline, spacing: 0) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(label)
                    .roundedFont(.section)
                    .foregroundStyle(Theme.text)
                if let aside {
                    Text(aside)
                        .scaledFont(13.5, relativeTo: .footnote)
                        .foregroundStyle(Theme.muted)
                } else if let count {
                    Text(count, format: .number)
                        .scaledFont(13.5, relativeTo: .footnote)
                        .foregroundStyle(Theme.muted)
                }
            }

            Spacer(minLength: 8)

            if let onSeeAll {
                Button(action: onSeeAll) {
                    Text("See all")
                        .scaledFont(14.5, weight: .semibold, relativeTo: .subheadline)
                        .foregroundStyle(Theme.primaryInk)
                        .frame(minHeight: 44)
                        .padding(.leading, 12)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(String(localized: "See all \(label.lowercased())"))
            }
        }
        .padding(.horizontal, 20)
    }

    private var editorialBody: some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text(label)
                .roundedFont(22, weight: .bold, relativeTo: .title2)
                .tracking(-0.44)
                .foregroundStyle(colorScheme == .dark ? Theme.textDark : Theme.textLight)
            if let count {
                Text("\(count)")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Theme.subtle(for: colorScheme))
            }
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .multilineTextAlignment(.center)
        .padding(.horizontal, 20)
    }
}

#Preview("SectionHeader · light") {
    VStack(alignment: .leading, spacing: 24) {
        SectionHeader(label: "Friends' trays", onSeeAll: {})
        SectionHeader(label: "My recipes", aside: "Newest first")
        SectionHeader(label: "Saved", count: 4)
    }
    .padding(.vertical)
    .background(Theme.background)
    .preferredColorScheme(.light)
}

#Preview("SectionHeader · dark") {
    VStack(alignment: .leading, spacing: 24) {
        SectionHeader(label: "Friends' trays", onSeeAll: {})
        SectionHeader(label: "My recipes", aside: "Newest first")
        SectionHeader(label: "Saved", count: 4)
    }
    .padding(.vertical)
    .background(Theme.background)
    .preferredColorScheme(.dark)
}

#Preview("SectionHeader · largest text") {
    VStack(alignment: .leading, spacing: 24) {
        SectionHeader(label: "Friends' trays", onSeeAll: {})
        SectionHeader(label: "My recipes", aside: "Newest first")
        SectionHeader(label: "Saved", count: 4)
    }
    .padding(.vertical)
    .background(Theme.background)
    .dynamicTypeSize(.accessibility5)
}

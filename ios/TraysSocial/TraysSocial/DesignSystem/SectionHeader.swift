import SwiftUI

/// Uppercase section header used by My Tray, Find, and other screens.
/// Mirrors the prototype's `SectionHeader` (prototype.jsx lines
/// 295-320): 11pt semibold uppercase label with 0.12em letter-spacing,
/// optional subtle count suffix, and an optional "See all" affordance
/// in amber-ink (mode-adaptive) with a chevron-right.
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
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(label.uppercased())
                    .font(.system(size: 11, weight: .semibold))
                    .tracking(1.32)
                    .foregroundStyle(Theme.muted(for: colorScheme))
                if let count {
                    Text("· \(count)")
                        .font(.system(size: 11, weight: .medium))
                        .tracking(1.32)
                        .foregroundStyle(Theme.subtle(for: colorScheme))
                }
            }

            Spacer(minLength: 8)

            if let onSeeAll {
                Button(action: onSeeAll) {
                    HStack(spacing: 4) {
                        Text("See all")
                            .font(.system(size: 12, weight: .medium))
                        Image(systemName: "chevron.right")
                            .font(.system(size: 10, weight: .semibold))
                    }
                    .foregroundStyle(Theme.accentInk(for: colorScheme))
                    .padding(4)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("See all \(label.lowercased())")
            }
        }
        .padding(.horizontal, 20)
    }

    private var editorialBody: some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text(label)
                .font(.system(size: 22, weight: .semibold))
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
        SectionHeader(label: "Recipes", count: 12, onSeeAll: {})
        SectionHeader(label: "Saved", count: 4)
        SectionHeader(label: "Trending this week")
    }
    .padding(.vertical)
    .background(Theme.bgLight)
    .preferredColorScheme(.light)
}

#Preview("SectionHeader · dark") {
    VStack(alignment: .leading, spacing: 24) {
        SectionHeader(label: "Recipes", count: 12, onSeeAll: {})
        SectionHeader(label: "Saved", count: 4)
        SectionHeader(label: "Trending this week")
    }
    .padding(.vertical)
    .background(Theme.bgDark)
    .preferredColorScheme(.dark)
}

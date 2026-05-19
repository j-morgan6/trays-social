import SwiftUI

/// Editorial iOS header — mirrors `IOSHeaderDark` from the Claude Design
/// handoff (design/handoff/trays-social/project/shared.jsx).
///
/// Layout:
/// ```
/// [Trays (serif, Mint Whisper)]  THU · MAY 15        [bell · amber dot]
/// Title (serif 34pt, white)
/// ```
///
/// `title` is the big serif page heading; `eyebrow` is the mono
/// date / context line next to the wordmark; `trailing` is whatever
/// belongs in the top-right (typically a bell + amber unread dot).
struct EditorialHeader<Trailing: View>: View {
    let title: String?
    let eyebrow: String?
    @ViewBuilder let trailing: () -> Trailing

    init(
        title: String? = nil,
        eyebrow: String? = nil,
        @ViewBuilder trailing: @escaping () -> Trailing = { EmptyView() }
    ) {
        self.title = title
        self.eyebrow = eyebrow
        self.trailing = trailing
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("Trays")
                    .font(.serif(20))
                    .foregroundStyle(Theme.secondary)

                if let eyebrow {
                    Text(eyebrow)
                        .font(.system(size: 9, weight: .medium, design: .monospaced))
                        .foregroundStyle(Theme.textSecondary)
                        .tracking(1.5)
                }

                Spacer(minLength: 0)

                trailing()
            }

            if let title {
                Text(title)
                    .font(.serif(34))
                    .foregroundStyle(Theme.text)
                    .tracking(-0.5)
            }
        }
        .padding(.top, 12)
        .padding(.bottom, 12)
        .padding(.horizontal, 20)
    }
}

/// Bell button used in the top-right of the editorial header. Lives
/// here so MainView and other screens don't re-implement it.
struct EditorialBellButton: View {
    var hasUnread: Bool = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "bell")
                .font(.system(size: 18, weight: .regular))
                .foregroundStyle(Theme.textSecondary)
                .overlay(alignment: .topTrailing) {
                    if hasUnread {
                        Circle()
                            .fill(Theme.accent)
                            .frame(width: 7, height: 7)
                            .offset(x: 2, y: -2)
                    }
                }
        }
        .buttonStyle(.plain)
    }
}

/// Today's date formatted as the design's mono eyebrow — e.g. `THU · MAY 15`.
enum EditorialDate {
    static var eyebrowToday: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE · MMM d"
        return formatter.string(from: Date()).uppercased()
    }
}

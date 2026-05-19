import SwiftUI

/// Editorial Notifications — matches `IOSNotifications` from the Claude
/// Design handoff (design/handoff/trays-social/project/ios-screens.jsx).
///
/// Serif "Notes for you" page heading + serif phrasing on each row
/// ("Maria saved your <recipe>") + amber unread tint + a 64pt photo
/// thumb on the right (or Follow Back button for follow events).
struct NotificationsView: View {
    @State private var viewModel = NotificationsViewModel()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                editorialHeading
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
                    .padding(.bottom, 12)

                if viewModel.isLoading {
                    ProgressView().tint(Theme.accent).padding(.top, 60)
                } else if viewModel.notifications.isEmpty {
                    emptyState
                } else {
                    notificationList
                    quietFooter
                }
            }
            .padding(.bottom, 32)
        }
        .background(Theme.background)
        .navigationTitle("Notes")
        .navigationBarTitleDisplayMode(.inline)
        .task { await viewModel.load() }
    }

    // MARK: - Heading

    private var editorialHeading: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Notes for you")
                .font(.serif(28))
                .foregroundStyle(Theme.text)

            let total = viewModel.notifications.count
            let unread = viewModel.notifications.count(where: { !$0.isRead })
            if total > 0 {
                Text("\(total) TODAY · \(unread) UNREAD")
                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                    .tracking(1.6)
                    .foregroundStyle(Theme.textSecondary)
            }
        }
    }

    // MARK: - List (flattened — no section headers, matching design)

    private var notificationList: some View {
        VStack(spacing: 0) {
            ForEach(viewModel.notifications) { notification in
                EditorialNotificationRow(notification: notification) {
                    viewModel.markRead([notification.id])
                }
                Divider().background(Color.white.opacity(0.06))
            }
        }
    }

    private var quietFooter: some View {
        Text("Quiet by design.")
            .font(.serifItalic(13))
            .foregroundStyle(Theme.textSecondary)
            .frame(maxWidth: .infinity)
            .padding(.top, 20)
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: 6) {
            Text("No notes yet.")
                .font(.serifItalic(17))
                .foregroundStyle(Theme.text)
            Text("Quiet by design. We don't ping you for the algorithm's sake.")
                .font(.system(size: 13))
                .foregroundStyle(Theme.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 80)
        .padding(.horizontal, 30)
    }
}

// MARK: - Editorial Notification Row

private struct EditorialNotificationRow: View {
    let notification: AppNotification
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(alignment: .top, spacing: 12) {
                avatar

                VStack(alignment: .leading, spacing: 4) {
                    phrasing
                    if let body = notificationBody {
                        Text(body)
                            .font(.serifItalic(12))
                            .foregroundStyle(Theme.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Text(notification.insertedAt.timeAgo())
                        .font(.system(size: 9, weight: .medium, design: .monospaced))
                        .tracking(1.4)
                        .foregroundStyle(Theme.textSecondary)
                        .padding(.top, 2)
                }

                Spacer(minLength: 0)

                trailing
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .background(rowBackground)
            .overlay(alignment: .leading) { unreadDot }
        }
        .buttonStyle(.plain)
    }

    private var rowBackground: some View {
        notification.isRead ? Color.clear : Theme.accent.opacity(0.05)
    }

    @ViewBuilder
    private var unreadDot: some View {
        if !notification.isRead {
            Circle()
                .fill(Theme.accent)
                .frame(width: 6, height: 6)
                .padding(.leading, 8)
        }
    }

    // MARK: Pieces

    private var avatar: some View {
        Circle()
            .fill(Theme.primary)
            .frame(width: 40, height: 40)
            .overlay(
                Text(initial)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
            )
            .overlay {
                if let urlString = notification.actor?.profilePhotoUrl,
                   let url = urlString.asBackendURL
                {
                    AsyncImage(url: url) { image in
                        image.resizable().scaledToFill()
                    } placeholder: { Color.clear }
                        .frame(width: 40, height: 40)
                        .clipShape(Circle())
                }
            }
    }

    private var phrasing: some View {
        Text(phraseAttributed)
            .font(.serif(14))
            .foregroundStyle(Theme.text)
            .lineSpacing(2)
            .fixedSize(horizontal: false, vertical: true)
    }

    @ViewBuilder
    private var trailing: some View {
        if let url = notification.post?.thumbnailUrl?.asBackendURL {
            AsyncImage(url: url) { image in
                image.resizable().scaledToFill()
            } placeholder: {
                Rectangle().fill(Color(.systemGray5))
            }
            .frame(width: 64, height: 64)
            .clipShape(RoundedRectangle(cornerRadius: 4))
        } else if notification.type == "follow" {
            Text("Follow back")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 10)
                .frame(height: 30)
                .background(Theme.primaryLight)
                .clipShape(Capsule())
        }
    }

    // MARK: Derived

    private var initial: String {
        let name = notification.actor?.username ?? "?"
        return String(name.prefix(1)).uppercased()
    }

    /// Editorial phrasing as an AttributedString — bolds the actor's
    /// name. The /notifications API today doesn't surface recipe
    /// captions or actor bios, so the recipe title becomes a generic
    /// "your recipe" reference (matches the design's structure without
    /// inventing copy).
    private var phraseAttributed: AttributedString {
        let actor = notification.actor?.username ?? "Someone"

        var s = switch notification.type {
        case "like":
            AttributedString("\(actor) found your recipe helpful")
        case "comment":
            AttributedString("\(actor) left a note on your recipe")
        case "follow":
            AttributedString("\(actor) followed you")
        default:
            AttributedString("\(actor) interacted with you")
        }

        if let range = s.range(of: actor) {
            s[range].font = .system(size: 14, weight: .semibold)
        }
        return s
    }

    /// Body line under the phrase. Not currently surfaced by the
    /// notifications payload — placeholder for when the API exposes
    /// comment excerpts or actor bios.
    private var notificationBody: String? {
        nil
    }
}

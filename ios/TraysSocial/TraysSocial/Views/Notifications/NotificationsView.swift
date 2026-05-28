import SwiftUI

/// Notifications screen ported from the Pass 1 prototype's
/// NotificationsScreen (prototype.jsx lines 654-695): a 30pt bold large
/// title + subtitle inside the pushed scroll content (the back button
/// + inline title come from the NavigationStack chrome), followed by a
/// rounded card containing a vertical list of notification rows.
///
/// Each row shows: 36pt `Avi`, amber-ink `@username` inline with the
/// action phrase, "Nm ago" / "Nd ago" subtle line, and an 8pt amber
/// unread dot trailing when the notification is unread.
///
/// Unread state stays visible on appear — tapping a row marks just
/// that notification read (not the whole list at once).
struct NotificationsView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(AppState.self) private var appState
    @State private var viewModel = NotificationsViewModel()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                headerSection
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
                    .padding(.bottom, 14)

                if viewModel.isLoading {
                    ProgressView()
                        .tint(Theme.accent)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 60)
                } else if viewModel.notifications.isEmpty {
                    emptyState
                } else {
                    notificationCard
                        .padding(.horizontal, 20)
                        .padding(.bottom, 24)
                }
            }
        }
        .background(Theme.background)
        .navigationTitle("Notifications")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await viewModel.load()
            // D72: keep the shell's bell dot in sync with the screen
            // we just rendered. Re-counts after markRead happen via
            // onChange below.
            appState.unreadNotificationCount = viewModel.unreadCount
        }
        .onChange(of: viewModel.notifications.map(\.isRead)) { _, _ in
            appState.unreadNotificationCount = viewModel.unreadCount
        }
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Notifications")
                .font(.system(size: 30, weight: .bold))
                .tracking(-0.75)
                .foregroundStyle(colorScheme == .dark ? Theme.textDark : Theme.textLight)

            if !viewModel.notifications.isEmpty {
                Text(subtitle)
                    .font(.system(size: 13.5))
                    .foregroundStyle(Theme.muted(for: colorScheme))
            }
        }
    }

    private var subtitle: String {
        let unread = viewModel.notifications.count(where: { !$0.isRead })
        switch unread {
        case 0: return "You're caught up."
        case 1: return "1 unread."
        default: return "\(unread) unread."
        }
    }

    private var notificationCard: some View {
        VStack(spacing: 0) {
            ForEach(Array(viewModel.notifications.enumerated()), id: \.element.id) { index, notification in
                NotificationRow(notification: notification) {
                    viewModel.markRead([notification.id])
                }
                if index < viewModel.notifications.count - 1 {
                    Rectangle()
                        .fill(Theme.hairline(for: colorScheme))
                        .frame(height: 1)
                }
            }
        }
        .background(Theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Theme.hairline(for: colorScheme), lineWidth: 1)
        )
    }

    private var emptyState: some View {
        VStack(spacing: 6) {
            Text("Nothing here yet")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(colorScheme == .dark ? Theme.textDark : Theme.textLight)
            Text("Quiet by design. We won't ping you for the algorithm's sake.")
                .font(.system(size: 13))
                .foregroundStyle(Theme.muted(for: colorScheme))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 80)
        .padding(.horizontal, 30)
    }
}

/// One row inside the notifications card. The unread dot is the only
/// visible difference between read and unread states — the row content
/// stays identical so the rhythm of the list isn't disrupted by reads.
private struct NotificationRow: View {
    @Environment(\.colorScheme) private var colorScheme
    let notification: AppNotification
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(alignment: .top, spacing: 12) {
                Avi(
                    initial: actorInitial,
                    size: 36,
                    palette: aviPalette,
                    border: true
                )

                VStack(alignment: .leading, spacing: 4) {
                    Text(phrase)
                        .font(.system(size: 14))
                        .lineSpacing(2)
                        .foregroundStyle(colorScheme == .dark ? Theme.textDark : Theme.textLight)
                        .fixedSize(horizontal: false, vertical: true)

                    Text("\(notification.insertedAt.timeAgo()) ago")
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.subtle(for: colorScheme))
                }

                Spacer(minLength: 0)

                if !notification.isRead {
                    Circle()
                        .fill(Theme.accent)
                        .frame(width: 8, height: 8)
                        .padding(.top, 14)
                        .accessibilityHidden(true)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 14)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
    }

    /// Pretty-print the notification with amber-ink @username highlight.
    private var phrase: AttributedString {
        let actor = notification.actor?.username ?? "Someone"
        let handle = "@\(actor) "
        let body = phraseBody(for: notification.type)

        var s = AttributedString(handle + body)
        if let range = s.range(of: handle) {
            s[range].font = .system(size: 14, weight: .semibold)
            s[range].foregroundColor = Theme.accentInk(for: colorScheme)
        }
        return s
    }

    private func phraseBody(for type: String) -> String {
        switch type {
        case "like": "liked your recipe."
        case "comment": "commented on your post."
        case "follow": "started following you."
        case "save": "saved your recipe."
        case "share": "shared a recipe with you."
        default: "interacted with you."
        }
    }

    private var actorInitial: String {
        String(notification.actor?.username.prefix(1) ?? "?").uppercased()
    }

    private var aviPalette: Avi.Palette {
        let palettes = Avi.Palette.allCases
        let key = notification.actor?.username.unicodeScalars.first.map { Int($0.value) } ?? 0
        return palettes[abs(key) % palettes.count]
    }

    private var accessibilityLabel: String {
        let actor = notification.actor?.username ?? "Someone"
        let body = phraseBody(for: notification.type)
        let unread = notification.isRead ? "" : ", unread"
        return "@\(actor) \(body) \(notification.insertedAt.timeAgo()) ago\(unread)"
    }
}

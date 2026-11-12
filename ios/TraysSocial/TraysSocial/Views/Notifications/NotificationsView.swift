import SwiftUI

/// Notifications, restyled to the More artboard ("Notifications"): a rounded
/// page title with the unread count and "Mark all read", then the list in
/// Today / This week / Earlier groups, each a soft card of rows. A row shows
/// the leading amber unread dot, the actor's avatar, "@username action", the
/// time, and the recipe's photo when the notification has one.
///
/// Unread state stays visible on appear — tapping a row marks just that
/// notification read; "Mark all read" marks the rest.
struct NotificationsView: View {
    @Environment(AppState.self) private var appState
    @State private var viewModel = NotificationsViewModel()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                headerSection
                    .padding(.horizontal, 18)
                    .padding(.top, 12)

                content
                    .padding(.bottom, 24)
            }
        }
        .background(Theme.background)
        .navigationTitle("Notifications")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Theme.background, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
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

    @ViewBuilder
    private var content: some View {
        switch ContentLoadState.decide(
            hasContent: !viewModel.notifications.isEmpty,
            hasLoaded: viewModel.hasLoaded,
            isLoading: viewModel.isLoading,
            loadFailed: viewModel.loadFailed
        ) {
        case .loading:
            NotificationsSkeleton()
                .padding(.horizontal, 18)
                .padding(.top, 22)
        case .error:
            // D95: the failure is logged by the view model; never toasted.
            TrayLoadErrorView(
                title: String(localized: "Notifications didn't load"),
                onRetry: { Task { await viewModel.load() } }
            )
            .padding(.horizontal, 18)
        case .empty:
            emptyState
        case .content:
            VStack(alignment: .leading, spacing: 22) {
                group(String(localized: "Today"), viewModel.todayNotifications)
                group(String(localized: "This week"), viewModel.thisWeekNotifications)
                group(String(localized: "Earlier"), viewModel.earlierNotifications)
            }
            .padding(.horizontal, 18)
            .padding(.top, 22)
        }
    }

    private var headerSection: some View {
        HStack(alignment: .bottom, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Notifications")
                    .roundedFont(32, weight: .heavy, relativeTo: .largeTitle)
                    .tracking(-0.6)
                    .foregroundStyle(Theme.text)
                    .accessibilityAddTraits(.isHeader)

                if !viewModel.notifications.isEmpty {
                    Text(subtitle)
                        .scaledFont(15, relativeTo: .subheadline)
                        .foregroundStyle(Theme.muted)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if viewModel.unreadCount > 0 {
                Button(String(localized: "Mark all read")) {
                    viewModel.markRead(viewModel.notifications.filter { !$0.isRead }.map(\.id))
                }
                .scaledFont(14.5, weight: .semibold, relativeTo: .subheadline)
                .foregroundStyle(Theme.primaryInk)
                .frame(minHeight: 44)
                .buttonStyle(.plain)
            }
        }
    }

    private var subtitle: String {
        let unread = viewModel.unreadCount
        if unread == 0 {
            return String(localized: "You're caught up.")
        }
        return String(localized: "\(unread) unread.")
    }

    /// One dated group; renders nothing when the group is empty.
    @ViewBuilder
    private func group(_ title: String, _ items: [AppNotification]) -> some View {
        if !items.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .roundedFont(17, weight: .heavy, relativeTo: .headline)
                    .foregroundStyle(Theme.text)
                    .accessibilityAddTraits(.isHeader)

                VStack(spacing: 0) {
                    ForEach(Array(items.enumerated()), id: \.element.id) { index, notification in
                        NotificationRow(notification: notification) {
                            viewModel.markRead([notification.id])
                        }
                        if index < items.count - 1 {
                            Rectangle()
                                .fill(Theme.hairline)
                                .frame(height: 1)
                        }
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 2)
                .cardSurface(cornerRadius: 22)
            }
        }
    }

    /// Empty-state block with the bell in a mint circle (More artboard,
    /// "Notifications · empty").
    private var emptyState: some View {
        VStack(spacing: 14) {
            Circle()
                .fill(Theme.mintTint)
                .frame(width: 64, height: 64)
                .overlay {
                    Image(systemName: "bell")
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundStyle(Theme.primaryInk)
                }
                .accessibilityHidden(true)
            EmptyStateBlock(
                title: String(localized: "Nothing yet"),
                subtitle: String(localized: """
                When someone follows you, saves one of your recipes or shares one \
                with you, it shows up here.
                """),
                topPadding: 0,
                chrome: .plain
            )
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 70)
    }
}

/// One notification row. The unread dot is the only visible difference
/// between read and unread states — the row content stays identical so the
/// rhythm of the list isn't disrupted by reads.
private struct NotificationRow: View {
    let notification: AppNotification
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(alignment: .center, spacing: 12) {
                Circle()
                    .fill(notification.isRead ? Color.clear : Theme.accent)
                    .frame(width: 8, height: 8)
                    .padding(.leading, -4)
                    .accessibilityHidden(true)

                avatar

                VStack(alignment: .leading, spacing: 2) {
                    // A long username or phrase truncates at three lines so
                    // one row never dominates the card.
                    Text(phrase)
                        .scaledFont(14.5, relativeTo: .subheadline)
                        .foregroundStyle(Theme.text)
                        .lineLimit(3)
                        .truncationMode(.tail)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(String(localized: "\(notification.insertedAt.timeAgo()) ago"))
                        .scaledFont(12.5, relativeTo: .caption)
                        .foregroundStyle(Theme.muted)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                if let thumbURL = notification.post?.thumbnailUrl?.asBackendURL {
                    PhotoSlot(url: thumbURL, cornerRadius: 11)
                        .frame(width: 48, height: 48)
                }
            }
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
    }

    /// The actor's photo when they have one, else their initial.
    @ViewBuilder
    private var avatar: some View {
        if let url = notification.actor?.profilePhotoUrl?.asBackendURL {
            AvatarSlot(url: url, size: 44)
        } else {
            Avi(initial: actorInitial, size: 44, palette: aviPalette, border: true)
        }
    }

    /// "@username" in bold, then the action phrase.
    private var phrase: AttributedString {
        let actor = notification.actor?.username ?? String(localized: "Someone")
        let handle = "@\(actor) "
        let body = phraseBody(for: notification.type)

        var s = AttributedString(handle + body)
        if let range = s.range(of: handle) {
            s[range].inlinePresentationIntent = .stronglyEmphasized
        }
        return s
    }

    private func phraseBody(for type: String) -> String {
        switch type {
        case "like": String(localized: "liked your recipe.")
        case "comment": String(localized: "commented on your post.")
        case "follow": String(localized: "started following you.")
        case "save": String(localized: "saved your recipe.")
        case "share": String(localized: "shared a recipe with you.")
        default: String(localized: "interacted with you.")
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
        let actor = notification.actor?.username ?? String(localized: "Someone")
        let body = phraseBody(for: notification.type)
        let timeAgo = String(localized: "\(notification.insertedAt.timeAgo()) ago")
        let unread = notification.isRead ? "" : String(localized: ", unread")
        return "@\(actor) \(body) \(timeAgo)\(unread)"
    }
}

/// Loading: one card of avatar-and-two-line rows. The pulse honours Reduce
/// Motion through `skeletonPulse()`.
private struct NotificationsSkeleton: View {
    var body: some View {
        VStack(spacing: 0) {
            ForEach(0 ..< 5, id: \.self) { _ in
                HStack(spacing: 12) {
                    SkeletonCircle(size: 44)
                    VStack(alignment: .leading, spacing: 8) {
                        SkeletonShape(height: 11, cornerRadius: 6)
                            .padding(.trailing, 40)
                        SkeletonShape(width: 70, height: 10, cornerRadius: 5)
                    }
                    Spacer(minLength: 0)
                }
                .padding(.vertical, 12)
            }
        }
        .padding(.horizontal, 14)
        .cardSurface(cornerRadius: 22)
        .skeletonGroup(label: String(localized: "Loading notifications"))
    }
}

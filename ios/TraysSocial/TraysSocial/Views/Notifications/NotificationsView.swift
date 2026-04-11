import SwiftUI

struct NotificationsView: View {
    @State private var viewModel = NotificationsViewModel()

    var body: some View {
        ScrollView {
            if viewModel.isLoading {
                ProgressView().tint(Theme.accent).padding(.top, 60)
            } else if viewModel.notifications.isEmpty {
                VStack(spacing: 8) {
                    Text("No notifications yet")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                    Text("Likes, comments, and follows will show up here")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                .padding(.top, 80)
            } else {
                LazyVStack(alignment: .leading, spacing: 0) {
                    if !viewModel.todayNotifications.isEmpty {
                        sectionHeader("Today")
                        ForEach(viewModel.todayNotifications) { notification in
                            NotificationRow(notification: notification, onTap: {
                                viewModel.markRead([notification.id])
                            })
                        }
                    }

                    if !viewModel.thisWeekNotifications.isEmpty {
                        sectionHeader("This Week")
                        ForEach(viewModel.thisWeekNotifications) { notification in
                            NotificationRow(notification: notification, onTap: {
                                viewModel.markRead([notification.id])
                            })
                        }
                    }

                    if !viewModel.earlierNotifications.isEmpty {
                        sectionHeader("Earlier")
                        ForEach(viewModel.earlierNotifications) { notification in
                            NotificationRow(notification: notification, onTap: {
                                viewModel.markRead([notification.id])
                            })
                        }
                    }
                }
            }
        }
        .background(Theme.background)
        .navigationTitle("Notifications")
        .navigationBarTitleDisplayMode(.inline)
        .task { await viewModel.load() }
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.caption.weight(.bold))
            .foregroundStyle(.gray)
            .tracking(1)
            .padding(.horizontal, 16)
            .padding(.top, 20)
            .padding(.bottom, 8)
    }
}

// MARK: - Notification Row

private struct NotificationRow: View {
    let notification: AppNotification
    var onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Actor avatar
                Circle()
                    .fill(Color(.systemGray4))
                    .frame(width: 40, height: 40)
                    .overlay {
                        if let url = notification.actor?.profilePhotoUrl, let imageURL = url.asBackendURL {
                            AsyncImage(url: imageURL) { image in
                                image.resizable().scaledToFill()
                            } placeholder: { Color.clear }
                            .frame(width: 40, height: 40)
                            .clipShape(Circle())
                        } else {
                            Image(systemName: iconForType)
                                .foregroundStyle(.gray)
                        }
                    }

                // Text
                VStack(alignment: .leading, spacing: 2) {
                    Text(notificationText)
                        .font(.subheadline)
                        .foregroundColor(notification.isRead ? .secondary : .white)
                        .lineLimit(2)

                    Text(notification.insertedAt.timeAgo())
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }

                Spacer()

                // Post thumbnail
                if let post = notification.post, let thumb = post.thumbnailUrl {
                    AsyncImage(url: thumb.asBackendURL) { image in
                        image.resizable().scaledToFill()
                    } placeholder: {
                        Rectangle().fill(Color(.systemGray5))
                    }
                    .frame(width: 44, height: 44)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(notification.isRead ? Color.clear : Theme.accent.opacity(0.04))
        }
        .buttonStyle(.plain)
    }

    private var iconForType: String {
        switch notification.type {
        case "like": "heart.fill"
        case "comment": "bubble.right.fill"
        case "follow": "person.fill.badge.plus"
        default: "bell.fill"
        }
    }

    private var notificationText: AttributedString {
        let username = notification.actor?.username ?? "Someone"
        var text: AttributedString

        switch notification.type {
        case "like":
            text = AttributedString("\(username) liked your recipe")
        case "comment":
            text = AttributedString("\(username) commented on your recipe")
        case "follow":
            text = AttributedString("\(username) started following you")
        default:
            text = AttributedString("New notification")
        }

        // Bold the username
        if let range = text.range(of: username) {
            text[range].font = .subheadline.weight(.semibold)
        }

        return text
    }

}

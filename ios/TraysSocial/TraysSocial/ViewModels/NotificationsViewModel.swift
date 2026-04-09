import SwiftUI

@Observable
final class NotificationsViewModel {
    var notifications: [AppNotification] = []
    var isLoading = false

    var todayNotifications: [AppNotification] {
        notifications.filter { Calendar.current.isDateInToday($0.insertedAt) }
    }

    var thisWeekNotifications: [AppNotification] {
        let calendar = Calendar.current
        let weekAgo = calendar.date(byAdding: .day, value: -7, to: Date())!
        return notifications.filter {
            !calendar.isDateInToday($0.insertedAt) && $0.insertedAt > weekAgo
        }
    }

    var earlierNotifications: [AppNotification] {
        let weekAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date())!
        return notifications.filter { $0.insertedAt <= weekAgo }
    }

    var unreadCount: Int {
        notifications.filter { !$0.isRead }.count
    }

    func load() async {
        isLoading = true
        do {
            let response: PaginatedResponse<[AppNotification]> = try await APIClient.shared.get(path: "/notifications")
            notifications = response.data
        } catch { }
        isLoading = false
    }

    func markRead(_ ids: [Int]) {
        // Optimistic update
        for i in notifications.indices {
            if ids.contains(notifications[i].id) {
                let n = notifications[i]
                notifications[i] = AppNotification(
                    id: n.id, type: n.type, readAt: Date(), insertedAt: n.insertedAt,
                    actor: n.actor, post: n.post
                )
            }
        }
        Task {
            try? await APIClient.shared.post(path: "/notifications/read", body: ["ids": ids])
        }
    }
}

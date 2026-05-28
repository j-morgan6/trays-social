import OSLog
import SwiftUI

@MainActor
@Observable
final class NotificationsViewModel {
    var notifications: [AppNotification] = []
    var isLoading = false

    private static let log = Logger(subsystem: "com.trays.social", category: "notifications")

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
        notifications.count(where: { !$0.isRead })
    }

    func load() async {
        isLoading = true
        do {
            let response: PaginatedResponse<[AppNotification]> = try await APIClient.shared.get(path: "/notifications")
            notifications = response.data
        } catch {
            // D95: read-path failure — log; the existing empty / skeleton
            // UI handles the no-content case.
            Self.log.error("load failed: \(String(describing: error), privacy: .public)")
        }
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

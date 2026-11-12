import OSLog
import SwiftUI

@MainActor
@Observable
final class NotificationsViewModel {
    var notifications: [AppNotification] = []
    var isLoading = false
    /// W253: the last load failed. Drives the load-failure block when there is
    /// nothing to show; cleared when a load starts. Logged only, never toasted.
    var loadFailed = false
    /// W253: a load has finished at least once, so an empty list means
    /// "nothing yet" rather than "not fetched yet".
    private(set) var hasLoaded = false

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
        loadFailed = false
        do {
            let response: PaginatedResponse<[AppNotification]> = try await APIClient.shared.get(path: "/notifications")
            notifications = response.data
        } catch {
            recordLoadFailure(error)
        }
        finishLoad()
    }

    /// D95: read-path failure — log; the screen shows its load-failure block.
    /// Never toast. A cancelled read is not a failure. Internal so the tests
    /// can drive it without the network.
    func recordLoadFailure(_ error: Error) {
        if !(error is CancellationError) {
            loadFailed = true
        }
        Self.log.error("load failed: \(String(describing: error), privacy: .public)")
    }

    /// Ends a load, failed or not: from here an empty list is "nothing yet".
    func finishLoad() {
        isLoading = false
        hasLoaded = true
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

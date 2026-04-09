import Foundation

struct AppNotification: Codable, Identifiable {
    let id: Int
    let type: String
    let readAt: Date?
    let insertedAt: Date
    let actor: NotificationActor?
    let post: NotificationPost?

    var isRead: Bool { readAt != nil }
}

struct NotificationActor: Codable {
    let id: Int
    let username: String
    let profilePhotoUrl: String?
}

struct NotificationPost: Codable {
    let id: Int
    let thumbnailUrl: String?
}

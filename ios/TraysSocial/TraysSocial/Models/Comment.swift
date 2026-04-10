import Foundation

struct Comment: Codable, Identifiable, Sendable {
    let id: Int
    let body: String
    let insertedAt: Date
    let user: PostUser
}

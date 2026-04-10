import Foundation

struct DataResponse<T: Decodable & Sendable>: Decodable, Sendable {
    let data: T
}

struct PaginatedResponse<T: Decodable & Sendable>: Decodable, Sendable {
    let data: T
    let cursor: String?
}

struct MessageResponse: Decodable, Sendable {
    let data: MessageData

    struct MessageData: Decodable, Sendable {
        let message: String
    }
}

struct UploadResponse: Decodable, Sendable {
    let url: String
}

struct EmptyResponse: Decodable, Sendable {}

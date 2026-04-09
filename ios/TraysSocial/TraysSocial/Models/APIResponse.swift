import Foundation

struct DataResponse<T: Decodable>: Decodable {
    let data: T
}

struct PaginatedResponse<T: Decodable>: Decodable {
    let data: T
    let cursor: String?
}

struct MessageResponse: Decodable {
    let data: MessageData

    struct MessageData: Decodable {
        let message: String
    }
}

struct UploadResponse: Decodable {
    let url: String
}

struct EmptyResponse: Decodable {}

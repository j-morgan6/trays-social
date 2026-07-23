import Foundation

struct DataResponse<T: Decodable & Sendable>: Decodable, Sendable {
    let data: T
}

struct PaginatedResponse<T: Decodable & Sendable>: Decodable, Sendable {
    let data: T
    let cursor: String?
}

/// W158: feed-shaped response that may carry a root-level `ad_config`.
/// `cursor` stays optional so the same wrapper decodes /posts/trending
/// (no pagination) as well as /feed. Both fields are absent-tolerant,
/// so legacy responses (ads disabled) decode unchanged.
struct AdAwarePaginatedResponse<T: Decodable & Sendable>: Decodable, Sendable {
    let data: T
    let cursor: String?
    let adConfig: AdConfig?
}

struct MessageResponse: Decodable, Sendable {
    let data: MessageData

    struct MessageData: Decodable, Sendable {
        let message: String
    }
}

struct UploadResponseWrapper: Decodable, Sendable {
    let data: UploadData

    struct UploadData: Decodable, Sendable {
        let url: String
    }
}

struct EmptyResponse: Decodable, Sendable {}

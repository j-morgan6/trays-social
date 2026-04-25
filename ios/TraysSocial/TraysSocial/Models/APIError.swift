import Foundation

enum APIError: LocalizedError {
    case invalidURL
    case invalidResponse
    case unauthorized
    case forbidden
    case notFound
    case unprocessableEntity
    case validationError([FieldError])
    case rateLimited
    case serverError(Int)

    var errorDescription: String? {
        switch self {
        case .invalidURL: "Invalid URL"
        case .invalidResponse: "Invalid server response"
        case .unauthorized: "Session expired. Please log in again."
        case .forbidden: "You don't have permission to do that."
        case .notFound: "Not found."
        case .unprocessableEntity: "Invalid data."
        case let .validationError(errors):
            errors.map { "\($0.field ?? ""): \($0.message)" }.joined(separator: "\n")
        case .rateLimited: "Too many requests. Please try again later."
        case let .serverError(code): "Server error (\(code)). Please try again."
        }
    }
}

struct FieldError: Decodable, Sendable {
    let field: String?
    let message: String
}

struct ErrorResponse: Decodable, Sendable {
    let errors: [FieldError]
}

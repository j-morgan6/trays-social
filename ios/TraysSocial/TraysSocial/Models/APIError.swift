import Foundation

enum APIError: LocalizedError {
    case invalidURL
    case invalidResponse
    case unauthorized
    case forbidden
    case suspended(message: String, suspendedUntil: Date?)
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
        case let .suspended(message, suspendedUntil):
            formatSuspendedMessage(message, until: suspendedUntil)
        case .notFound: "Not found."
        case .unprocessableEntity: "Invalid data."
        case let .validationError(errors):
            errors.map { "\($0.field ?? ""): \($0.message)" }.joined(separator: "\n")
        case .rateLimited: "Too many requests. Please try again later."
        case let .serverError(code): "Server error (\(code)). Please try again."
        }
    }

    private func formatSuspendedMessage(_ message: String, until: Date?) -> String {
        guard let until else { return message }
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        return "\(message) Suspended until \(formatter.string(from: until))."
    }
}

struct FieldError: Decodable, Sendable {
    let field: String?
    let message: String
    // Present on suspension errors (code == "suspended"). Other 422/4xx
    // payloads omit it. Kept optional so the existing validation-error
    // decode path doesn't break.
    let code: String?
    let suspendedUntil: Date?

    init(field: String?, message: String, code: String? = nil, suspendedUntil: Date? = nil) {
        self.field = field
        self.message = message
        self.code = code
        self.suspendedUntil = suspendedUntil
    }
}

struct ErrorResponse: Decodable, Sendable {
    let errors: [FieldError]
}

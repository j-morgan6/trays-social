import Foundation

actor APIClient {
    static let shared = APIClient()

    private let baseURL: String
    private let session: URLSession
    private let decoder: JSONDecoder

    private init() {
        self.baseURL = Configuration.apiBaseURL + "/api/v1"
        self.session = URLSession.shared

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .iso8601
        self.decoder = decoder
    }

    // MARK: - Generic Request Methods

    func get<T: Decodable>(path: String, queryItems: [URLQueryItem]? = nil) async throws -> T {
        let request = try buildRequest(method: "GET", path: path, queryItems: queryItems)
        return try await execute(request)
    }

    func post<T: Decodable>(path: String, body: Encodable? = nil) async throws -> T {
        var request = try buildRequest(method: "POST", path: path)
        if let body {
            request.httpBody = try JSONEncoder.apiEncoder.encode(body)
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        return try await execute(request)
    }

    @discardableResult
    func post(path: String, body: Encodable? = nil) async throws -> EmptyResponse {
        var request = try buildRequest(method: "POST", path: path)
        if let body {
            request.httpBody = try JSONEncoder.apiEncoder.encode(body)
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        return try await execute(request)
    }

    func put<T: Decodable>(path: String, body: Encodable? = nil) async throws -> T {
        var request = try buildRequest(method: "PUT", path: path)
        if let body {
            request.httpBody = try JSONEncoder.apiEncoder.encode(body)
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        return try await execute(request)
    }

    @discardableResult
    func delete(path: String) async throws -> EmptyResponse {
        let request = try buildRequest(method: "DELETE", path: path)
        return try await execute(request)
    }

    func delete<T: Decodable>(path: String) async throws -> T {
        let request = try buildRequest(method: "DELETE", path: path)
        return try await execute(request)
    }

    // MARK: - Multipart Upload

    func upload(path: String, imageData: Data, filename: String) async throws -> String {
        let boundary = UUID().uuidString
        var request = try buildRequest(method: "POST", path: path)
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        var body = Data()
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"photo\"; filename=\"\(filename)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: image/jpeg\r\n\r\n".data(using: .utf8)!)
        body.append(imageData)
        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)

        request.httpBody = body

        let response: UploadResponseWrapper = try await execute(request)
        return response.data.url
    }

    // MARK: - Private

    private func buildRequest(method: String, path: String, queryItems: [URLQueryItem]? = nil) throws -> URLRequest {
        var components = URLComponents(string: baseURL + path)!
        if let queryItems, !queryItems.isEmpty {
            components.queryItems = queryItems
        }

        guard let url = components.url else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = method

        if let token = KeychainService.getToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        return request
    }

    private func execute<T: Decodable>(_ request: URLRequest) async throws -> T {
        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        switch httpResponse.statusCode {
        case 200...201:
            return try decoder.decode(T.self, from: data)
        case 401:
            throw APIError.unauthorized
        case 403:
            throw APIError.forbidden
        case 404:
            throw APIError.notFound
        case 422:
            if let errorResponse = try? decoder.decode(ErrorResponse.self, from: data) {
                throw APIError.validationError(errorResponse.errors)
            }
            throw APIError.unprocessableEntity
        case 429:
            throw APIError.rateLimited
        default:
            throw APIError.serverError(httpResponse.statusCode)
        }
    }
}

// MARK: - JSON Encoder Extension

extension JSONEncoder {
    static let apiEncoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        return encoder
    }()
}

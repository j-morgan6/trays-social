import Foundation

enum AuthService {
    struct RegisterRequest: Encodable {
        let email: String
        let username: String
        let password: String
    }

    struct LoginRequest: Encodable {
        let email: String
        let password: String
    }

    struct AppleAuthRequest: Encodable {
        let identityToken: String
        let email: String?
        let username: String?
    }

    struct UpdateUsernameRequest: Encodable {
        let username: String
    }

    struct UpdateProfileRequest: Encodable {
        let username: String
        let bio: String
        let profilePhotoUrl: String?
    }

    static func register(email: String, username: String, password: String) async throws -> AuthResponse {
        let body = RegisterRequest(email: email, username: username, password: password)
        let response: DataResponse<AuthResponse> = try await APIClient.shared.post(path: "/auth/register", body: body)
        return response.data
    }

    static func login(email: String, password: String) async throws -> AuthResponse {
        let body = LoginRequest(email: email, password: password)
        let response: DataResponse<AuthResponse> = try await APIClient.shared.post(path: "/auth/login", body: body)
        return response.data
    }

    static func appleAuth(identityToken: String, email: String?, username: String?) async throws -> AuthResponse {
        let body = AppleAuthRequest(identityToken: identityToken, email: email, username: username)
        let response: DataResponse<AuthResponse> = try await APIClient.shared.post(path: "/auth/apple", body: body)
        return response.data
    }

    static func fetchMe() async throws -> User {
        let response: DataResponse<User> = try await APIClient.shared.get(path: "/auth/me")
        return response.data
    }

    static func updateUsername(_ username: String) async throws -> User {
        let body = UpdateUsernameRequest(username: username)
        let response: DataResponse<User> = try await APIClient.shared.put(path: "/auth/me", body: body)
        return response.data
    }

    static func updateProfile(username: String, bio: String, profilePhotoUrl: String?) async throws -> User {
        let body = UpdateProfileRequest(
            username: username,
            bio: bio,
            profilePhotoUrl: profilePhotoUrl
        )
        let response: DataResponse<User> = try await APIClient.shared.put(path: "/auth/me", body: body)
        return response.data
    }
}

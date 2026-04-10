import SwiftUI
import AuthenticationServices

@MainActor
@Observable
final class AuthViewModel {
    var email = ""
    var username = ""
    var password = ""
    var isLoading = false
    var errorMessage: String?

    // Apple Sign In state
    var needsUsername = false
    var pendingToken: String?
    var pendingUser: User?

    var isEmailValid: Bool {
        email.contains("@") && !email.contains(" ")
    }

    var isUsernameValid: Bool {
        let pattern = /^[a-zA-Z0-9_]{3,30}$/
        return username.wholeMatch(of: pattern) != nil
    }

    var isPasswordValid: Bool {
        password.count >= 12
    }

    var canRegister: Bool {
        isEmailValid && isUsernameValid && isPasswordValid && !isLoading
    }

    var canLogin: Bool {
        isEmailValid && !password.isEmpty && !isLoading
    }

    func register(appState: AppState) async {
        isLoading = true
        errorMessage = nil

        do {
            let response = try await AuthService.register(email: email, username: username, password: password)
            appState.login(token: response.token, user: response.user)
        } catch let error as APIError {
            errorMessage = error.errorDescription
        } catch {
            errorMessage = "Something went wrong. Please try again."
        }

        isLoading = false
    }

    func login(appState: AppState) async {
        isLoading = true
        errorMessage = nil

        do {
            let response = try await AuthService.login(email: email, password: password)
            appState.login(token: response.token, user: response.user)
        } catch let error as APIError {
            if case .unauthorized = error {
                errorMessage = "Invalid email or password."
            } else {
                errorMessage = error.errorDescription
            }
        } catch {
            errorMessage = "Something went wrong. Please try again."
        }

        isLoading = false
    }

    func handleAppleSignIn(result: Result<ASAuthorization, Error>, appState: AppState) async {
        isLoading = true
        errorMessage = nil

        switch result {
        case .success(let authorization):
            guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
                  let tokenData = credential.identityToken,
                  let identityToken = String(data: tokenData, encoding: .utf8) else {
                errorMessage = "Failed to get Apple credentials."
                isLoading = false
                return
            }

            let email = credential.email
            let fullName = credential.fullName
            let username = fullName?.givenName?.lowercased()

            do {
                let response = try await AuthService.appleAuth(
                    identityToken: identityToken,
                    email: email,
                    username: username
                )

                if response.needsUsername == true {
                    pendingToken = response.token
                    pendingUser = response.user
                    needsUsername = true
                    KeychainService.save(token: response.token)
                } else {
                    appState.login(token: response.token, user: response.user)
                }
            } catch let error as APIError {
                errorMessage = error.errorDescription
            } catch {
                errorMessage = "Apple Sign In failed. Please try again."
            }

        case .failure:
            // User cancelled — not an error
            break
        }

        isLoading = false
    }

    func setUsername(appState: AppState) async {
        guard isUsernameValid, let token = pendingToken, pendingUser != nil else { return }

        isLoading = true
        errorMessage = nil

        do {
            let updatedUser = try await AuthService.updateUsername(username)
            appState.login(token: token, user: updatedUser)
            needsUsername = false
        } catch let error as APIError {
            errorMessage = error.errorDescription
        } catch {
            errorMessage = "Failed to set username."
        }

        isLoading = false
    }

    func clearError() {
        errorMessage = nil
    }

    func reset() {
        email = ""
        username = ""
        password = ""
        errorMessage = nil
        isLoading = false
        needsUsername = false
        pendingToken = nil
        pendingUser = nil
    }
}

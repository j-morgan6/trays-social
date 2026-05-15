import AuthenticationServices
import CryptoKit
import LocalAuthentication
import SwiftUI

@MainActor
@Observable
final class AuthViewModel {
    var email = ""
    var username = ""
    var password = ""
    var isLoading = false
    var errorMessage: String?
    var rememberMe = false
    var hasSavedCredential = false

    // Apple Sign In state
    var needsUsername = false
    var pendingToken: String?
    var pendingUser: User?
    // W104: the per-sign-in raw nonce. Generated when the
    // SignInWithAppleButton begins its request and consumed by
    // handleAppleSignIn after Apple returns. The sha256 of this string is
    // what we set as ASAuthorizationAppleIDRequest.nonce, so the JWT Apple
    // mints will carry that same hash as its nonce claim and the server can
    // bind the token to this exact sign-in attempt.
    private var currentRawNonce: String?

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

    func checkBiometricAvailability() {
        hasSavedCredential = KeychainService.hasBiometricCredential()
    }

    /// Prepares Apple's sign-in request by generating a fresh per-attempt
    /// nonce and setting `request.nonce` to its SHA-256 hex digest. Stash the
    /// raw nonce on the view model so `handleAppleSignIn` can forward it to
    /// the backend (the server hashes it again and verifies it matches the
    /// JWT's nonce claim).
    func prepareAppleSignInRequest(_ request: ASAuthorizationAppleIDRequest) {
        request.requestedScopes = [.email, .fullName]
        let rawNonce = Self.makeRawNonce()
        currentRawNonce = rawNonce
        request.nonce = Self.sha256Hex(rawNonce)
    }

    private static func makeRawNonce(length: Int = 32) -> String {
        // Apple's sample uses an alphanumeric character set for the raw
        // nonce so the value is safe to log/inspect. The SHA-256 of the raw
        // nonce is what gets bound to the JWT; the raw value never leaves
        // device → Apple → backend.
        let charset: [Character] =
            Array("0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz-._")
        var result = ""
        var remaining = length

        while remaining > 0 {
            var randoms = [UInt8](repeating: 0, count: 16)
            let status = SecRandomCopyBytes(kSecRandomDefault, randoms.count, &randoms)
            precondition(status == errSecSuccess, "SecRandomCopyBytes failed: \(status)")

            for random in randoms where remaining > 0 {
                if random < charset.count {
                    result.append(charset[Int(random)])
                    remaining -= 1
                }
            }
        }

        return result
    }

    private static func sha256Hex(_ input: String) -> String {
        let digest = SHA256.hash(data: Data(input.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
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
            if rememberMe {
                // W105: exchange the just-issued API bearer for a refresh
                // token and store THAT in biometric-gated Keychain. The
                // plaintext password never gets written to Keychain anymore.
                // A network hiccup on the refresh request is non-fatal —
                // the user is logged in; biometric just won't be available
                // until they opt in again next time.
                if let refresh = try? await AuthService.createRefreshToken() {
                    KeychainService.saveBiometricRefreshToken(refresh)
                    hasSavedCredential = true
                }
            }
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

    func loginWithBiometrics(appState: AppState) async {
        isLoading = true
        errorMessage = nil

        guard let refreshToken = KeychainService.getBiometricRefreshToken() else {
            errorMessage = "Could not retrieve saved credentials."
            hasSavedCredential = false
            isLoading = false
            return
        }

        do {
            let response = try await AuthService.biometricExchange(refreshToken: refreshToken)
            appState.login(token: response.token, user: response.user)
        } catch let error as APIError {
            if case .unauthorized = error {
                errorMessage = "Saved credentials are no longer valid. Please log in manually."
                KeychainService.deleteBiometricCredential()
                hasSavedCredential = false
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
        case let .success(authorization):
            guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
                  let tokenData = credential.identityToken,
                  let identityToken = String(data: tokenData, encoding: .utf8)
            else {
                errorMessage = "Failed to get Apple credentials."
                isLoading = false
                return
            }

            // W104: the raw nonce stashed by prepareAppleSignInRequest is
            // what the server hashes again to verify the JWT's nonce claim.
            // If it's nil here, somebody hit the success path without
            // first calling prepareAppleSignInRequest — treat that as a
            // hard error rather than sending an empty string and earning a
            // confusing 422 from the backend.
            guard let rawNonce = currentRawNonce else {
                errorMessage = "Apple Sign In failed (missing nonce). Please try again."
                isLoading = false
                return
            }
            // Single-use — clear so a subsequent attempt forces a fresh
            // request preparation.
            currentRawNonce = nil

            let email = credential.email
            let fullName = credential.fullName
            let username = fullName?.givenName?.lowercased()

            do {
                let response = try await AuthService.appleAuth(
                    identityToken: identityToken,
                    rawNonce: rawNonce,
                    email: email,
                    username: username
                )

                if response.needsUsername == true {
                    pendingToken = response.token
                    pendingUser = response.user
                    KeychainService.save(token: response.token)

                    // Defer the sheet-presentation flag by ~350ms so SwiftUI
                    // fully dismisses Apple's ASAuthorizationController sheet
                    // before our .sheet(isPresented: $needsUsername) attempts
                    // to present UsernamePickerView. Without the delay, the
                    // two sheet animations race in the same runloop tick and
                    // SwiftUI swallows the second presentation, leaving the
                    // user back on Welcome with no visible feedback. (D30.)
                    try? await Task.sleep(for: .milliseconds(350))
                    needsUsername = true
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

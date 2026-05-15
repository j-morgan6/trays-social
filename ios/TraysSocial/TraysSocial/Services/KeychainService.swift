import Foundation
import LocalAuthentication
import Security

enum KeychainService {
    private static let service = "com.trays.social.api-token"
    private static let account = "api-token"

    static func save(token: String) {
        guard let data = token.data(using: .utf8) else { return }

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]

        // Delete existing item first
        SecItemDelete(query as CFDictionary)

        var addQuery = query
        addQuery[kSecValueData as String] = data
        // D42: ThisDeviceOnly so the bearer is excluded from encrypted
        // iTunes/Finder backups and Quick Start device migration. A token
        // issued on device A must not be carried forward to device B by a
        // restore — that would be an admission of an attacker who walked
        // away with the source device's backup. `kSecAttrSynchronizable:
        // false` is set explicitly as defense-in-depth, matching what the
        // biometric credential storage below already does implicitly via
        // its access-control flags.
        addQuery[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        addQuery[kSecAttrSynchronizable as String] = false

        SecItemAdd(addQuery as CFDictionary, nil)
    }

    static func getToken() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess,
              let data = result as? Data,
              let token = String(data: data, encoding: .utf8)
        else {
            return nil
        }

        return token
    }

    static func deleteToken() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]

        SecItemDelete(query as CFDictionary)
    }

    // MARK: - Biometric Credentials (W105: refresh-token based)

    //
    // The legacy implementation stored the user's plaintext password under a
    // biometric-gated Keychain ACL. The ACL was correctly scoped, but the
    // long-lived secret was the reusable password itself — a future biometric
    // bypass or Keychain regression would yield a credential reusable across
    // services. We now store a server-issued refresh token instead.
    //
    // The refresh token is hashed at rest server-side (see W105) and
    // exchanged at /api/v1/auth/biometric-exchange for a fresh API bearer.
    // Password change invalidates all refresh tokens (D38 update path).

    private static let credentialService = "com.trays.social.biometric-credential"
    private static let refreshTokenAccount = "biometric-refresh-token"

    // Legacy accounts retained as constants so the upgrade path can purge them.
    private static let legacyEmailAccount = "biometric-email"
    private static let legacyPasswordAccount = "biometric-password"

    static func saveBiometricRefreshToken(_ refreshToken: String) {
        deleteBiometricCredential()

        guard let access = SecAccessControlCreateWithFlags(
            nil,
            kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
            .biometryCurrentSet,
            nil
        ) else { return }

        guard let data = refreshToken.data(using: .utf8) else { return }
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: credentialService,
            kSecAttrAccount as String: refreshTokenAccount,
            kSecValueData as String: data,
            kSecAttrAccessControl as String: access,
        ]
        SecItemAdd(query as CFDictionary, nil)
    }

    static func getBiometricRefreshToken() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: credentialService,
            kSecAttrAccount as String: refreshTokenAccount,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data,
              let str = String(data: data, encoding: .utf8)
        else {
            return nil
        }
        return str
    }

    static func hasBiometricCredential() -> Bool {
        let context = LAContext()
        context.interactionNotAllowed = true

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: credentialService,
            kSecAttrAccount as String: refreshTokenAccount,
            kSecUseAuthenticationContext as String: context,
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        return status == errSecSuccess || status == errSecInteractionNotAllowed
    }

    static func deleteBiometricCredential() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: credentialService,
        ]
        SecItemDelete(query as CFDictionary)
    }

    /// W105 migration: existing biometric users had their email + password
    /// stored under the legacy accounts. Wipe those once on app start so the
    /// password never sits in Keychain again; users will be prompted to log
    /// in once and re-opt into biometric, at which point the refresh-token
    /// flow takes over. Safe to call repeatedly — no-op once the legacy
    /// items are gone.
    static func purgeLegacyBiometricCredential() {
        for legacy in [legacyEmailAccount, legacyPasswordAccount] {
            let query: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: credentialService,
                kSecAttrAccount as String: legacy,
            ]
            SecItemDelete(query as CFDictionary)
        }
    }
}

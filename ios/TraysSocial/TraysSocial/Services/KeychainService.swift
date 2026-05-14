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

    // MARK: - Biometric Credentials

    private static let credentialService = "com.trays.social.biometric-credential"
    private static let credentialEmailAccount = "biometric-email"
    private static let credentialPasswordAccount = "biometric-password"

    static func saveBiometricCredential(email: String, password: String) {
        deleteBiometricCredential()

        guard let access = SecAccessControlCreateWithFlags(
            nil,
            kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
            .biometryCurrentSet,
            nil
        ) else { return }

        for (account, value) in [(credentialEmailAccount, email), (credentialPasswordAccount, password)] {
            guard let data = value.data(using: .utf8) else { continue }
            let query: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: credentialService,
                kSecAttrAccount as String: account,
                kSecValueData as String: data,
                kSecAttrAccessControl as String: access,
            ]
            SecItemAdd(query as CFDictionary, nil)
        }
    }

    static func getBiometricCredential() -> (email: String, password: String)? {
        func retrieve(account: String) -> String? {
            let query: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: credentialService,
                kSecAttrAccount as String: account,
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

        guard let email = retrieve(account: credentialEmailAccount),
              let password = retrieve(account: credentialPasswordAccount)
        else {
            return nil
        }
        return (email, password)
    }

    static func hasBiometricCredential() -> Bool {
        let context = LAContext()
        context.interactionNotAllowed = true

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: credentialService,
            kSecAttrAccount as String: credentialEmailAccount,
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
}

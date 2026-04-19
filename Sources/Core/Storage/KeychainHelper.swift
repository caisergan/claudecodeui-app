import Foundation
import Security

// MARK: - Keychain Keys

enum KeychainKey: String {
    case authToken = "com.claudecodeui.authToken"
    case refreshToken = "com.claudecodeui.refreshToken"
    case userId = "com.claudecodeui.userId"
    case agentAPIKey = "com.claudecodeui.agentAPIKey"
}

// MARK: - KeychainHelper

final class KeychainHelper {
    static let shared = KeychainHelper()
    private init() {}

    // MARK: Save

    @discardableResult
    func save(_ value: String, key: KeychainKey) -> Bool {
        guard let data = value.data(using: .utf8) else { return false }

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key.rawValue,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]

        SecItemDelete(query as CFDictionary)
        return SecItemAdd(query as CFDictionary, nil) == errSecSuccess
    }

    // MARK: Read

    func read(key: KeychainKey) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key.rawValue,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data,
              let string = String(data: data, encoding: .utf8) else {
            return nil
        }
        return string
    }

    // MARK: Delete

    @discardableResult
    func delete(key: KeychainKey) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key.rawValue
        ]
        return SecItemDelete(query as CFDictionary) == errSecSuccess
    }

    // MARK: Clear All

    func clearAll() {
        for key in [KeychainKey.authToken, .refreshToken, .userId] {
            delete(key: key)
        }
    }
}

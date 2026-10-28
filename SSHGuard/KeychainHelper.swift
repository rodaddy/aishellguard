import Foundation
import Security

/// Manages HMAC signing key in macOS Keychain
struct KeychainHelper {
    private static let service = "com.aishellguard.app"
    private static let account = "hmac-signing-key"

    /// Get or create HMAC signing key (32 bytes for SHA256)
    static func getOrCreateSigningKey() -> Data? {
        if let existing = getSigningKey() {
            return existing
        }

        // Generate new random key
        var keyData = Data(count: 32)
        let result = keyData.withUnsafeMutableBytes { ptr in
            SecRandomCopyBytes(kSecRandomDefault, 32, ptr.baseAddress!)
        }

        guard result == errSecSuccess else {
            print("Failed to generate random key")
            return nil
        }

        // Store in Keychain
        guard saveSigningKey(keyData) else {
            return nil
        }

        return keyData
    }

    /// Retrieve existing key from Keychain
    static func getSigningKey() -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess, let data = result as? Data else {
            return nil
        }

        return data
    }

    /// Save key to Keychain
    private static func saveSigningKey(_ key: Data) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: key,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
        ]

        let status = SecItemAdd(query as CFDictionary, nil)
        return status == errSecSuccess
    }
}

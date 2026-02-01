import Foundation
import CryptoKit

/// HMAC-SHA256 signing for state file integrity
struct HMACSigner {
    /// Compute HMAC-SHA256 of data using signing key from Keychain
    static func sign(data: Data) -> String? {
        guard let key = KeychainHelper.getOrCreateSigningKey() else {
            print("Failed to get signing key")
            return nil
        }

        let symmetricKey = SymmetricKey(data: key)
        let signature = HMAC<SHA256>.authenticationCode(for: data, using: symmetricKey)

        return Data(signature).base64EncodedString()
    }

    /// Verify HMAC signature
    static func verify(data: Data, signature: String) -> Bool {
        guard let key = KeychainHelper.getOrCreateSigningKey() else {
            return false
        }

        guard let signatureData = Data(base64Encoded: signature) else {
            return false
        }

        let symmetricKey = SymmetricKey(data: key)

        return HMAC<SHA256>.isValidAuthenticationCode(
            signatureData,
            authenticating: data,
            using: symmetricKey
        )
    }

    /// Create signature for hosts array (the critical data)
    static func signHosts(_ hosts: [Host], encoder: JSONEncoder) -> String? {
        guard let hostsData = try? encoder.encode(hosts) else {
            return nil
        }
        return sign(data: hostsData)
    }

    /// Verify hosts array matches signature
    static func verifyHosts(_ hosts: [Host], signature: String, encoder: JSONEncoder) -> Bool {
        guard let hostsData = try? encoder.encode(hosts) else {
            return false
        }
        return verify(data: hostsData, signature: signature)
    }
}

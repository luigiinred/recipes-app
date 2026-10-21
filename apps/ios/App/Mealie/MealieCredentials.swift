import Foundation
import Security

/// The Mealie API token lives in the Keychain, keyed by server address; the address itself is an ordinary setting.
enum MealieCredentials {
    private static let service = "\(Bundle.main.bundleIdentifier ?? "Recipes").mealie"

    static func token(for server: String) -> String? {
        var query = base(server)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess, let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func setToken(_ token: String?, for server: String) {
        SecItemDelete(base(server) as CFDictionary)
        guard let token, let data = token.data(using: .utf8) else { return }
        var item = base(server)
        item[kSecValueData as String] = data
        item[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        SecItemAdd(item as CFDictionary, nil)
    }

    private static func base(_ server: String) -> [String: Any] {
        [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service, kSecAttrAccount as String: server]
    }
}

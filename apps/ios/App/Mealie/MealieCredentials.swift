import Foundation
import Security

/// The Mealie server, user and API token live in one iCloud Keychain item, so pairing one device pairs every device signed in to the same iCloud account.
enum MealieCredentials {
    struct Connection: Codable, Equatable {
        var server: String
        var username: String?
        var token: String
    }

    struct NotSaved: LocalizedError {
        var errorDescription: String? { "Couldn't save the Mealie connection in the Keychain." }
    }

    static let service = "\(Bundle.main.bundleIdentifier ?? "Recipes").mealie"
    // Its own service, so clearing the connection's service leaves Discover alone.
    private static let discoverService = "\(service).discover"
    private static let account = "connection"

    static func load(service: String = service) -> Connection? {
        read(base(account, service: service)).flatMap { try? JSONDecoder().decode(Connection.self, from: $0) }
    }

    @discardableResult
    static func save(_ connection: Connection, service: String = service) -> Bool {
        guard let data = try? JSONEncoder().encode(connection) else { return false }
        return write(data, to: base(account, service: service))
    }

    /// The servers browsed in Discover, kept like the connection so they appear on every device.
    static func discoverSources() -> [DiscoverSource] {
        read(base("sources", service: discoverService)).flatMap { try? JSONDecoder().decode([DiscoverSource].self, from: $0) } ?? []
    }

    static func saveDiscoverSources(_ sources: [DiscoverSource]) {
        guard let data = try? JSONEncoder().encode(sources) else { return }
        write(data, to: base("sources", service: discoverService))
    }

    private static func read(_ query: [String: Any]) -> Data? {
        var query = query
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess else { return nil }
        return result as? Data
    }

    private static func write(_ data: Data, to query: [String: Any]) -> Bool {
        let update = SecItemUpdate(query as CFDictionary, [kSecValueData as String: data] as CFDictionary)
        guard update == errSecItemNotFound else { return update == errSecSuccess }
        var item = query
        item[kSecValueData as String] = data
        item[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        if usesICloudKeychain { item[kSecAttrSynchronizable as String] = true }
        return SecItemAdd(item as CFDictionary, nil) == errSecSuccess
    }

    /// Removes the connection everywhere it syncs to, along with any token from before pairing was shared.
    static func clear(service: String = service) {
        SecItemDelete(base(account, service: service) as CFDictionary)
        if service == Self.service { SecItemDelete(base(nil) as CFDictionary) }
    }

    // A Mac build signed without a team has no application identifier, so the iCloud Keychain refuses every write
    // and reads come back empty. Such a build keeps its items in the login keychain instead.
    private static let usesICloudKeychain: Bool = {
        #if os(macOS)
        guard let task = SecTaskCreateFromSelf(nil) else { return false }
        return SecTaskCopyValueForEntitlement(task, "com.apple.application-identifier" as CFString, nil) != nil
        #else
        return true
        #endif
    }()

    /// Moves a pairing made before it was shared (token in a local Keychain item, address in the settings) into the shared item.
    @discardableResult
    static func migrateLegacy(server: String?, username: String?) -> Connection? {
        guard let server, let token = legacyToken(for: server) else { return nil }
        let connection = Connection(server: server, username: username, token: token)
        save(connection)
        var legacy = base(server)
        legacy[kSecAttrSynchronizable as String] = false
        SecItemDelete(legacy as CFDictionary)
        return connection
    }

    private static func legacyToken(for server: String) -> String? {
        var query = base(server)
        query[kSecAttrSynchronizable as String] = false
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess, let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    private static func base(_ account: String?, service: String = service) -> [String: Any] {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
        ]
        if let account { query[kSecAttrAccount as String] = account }
        guard usesICloudKeychain else { return query }
        query[kSecAttrSynchronizable as String] = kSecAttrSynchronizableAny
        #if os(macOS)
        query[kSecUseDataProtectionKeychain as String] = true
        #endif
        return query
    }
}

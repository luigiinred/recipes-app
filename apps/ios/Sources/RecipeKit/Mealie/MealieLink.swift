import Foundation

/// The `recipes://mealie?server=<address>&token=<token>` link that pairs the app with a Mealie server, or
/// `recipes://discover?…` that adds one to browse in Discover, or `recipes://mealie-invite?…` whose token is an
/// invitation to make a new user on the server.
public struct MealieLink: Equatable, Sendable {
    public enum Kind: String, Sendable {
        case sync = "mealie"
        case discover
        case invite = "mealie-invite"
    }

    public var server: URL
    public var token: String
    public var kind: Kind
    /// A public group to browse, for a Discover link that needs no token.
    public var group: String?

    public init(server: URL, token: String, kind: Kind = .sync, group: String? = nil) {
        self.server = server
        self.token = token
        self.kind = kind
        self.group = group
    }

    public var url: URL {
        var components = URLComponents()
        components.scheme = "recipes"
        components.host = kind.rawValue
        components.queryItems = [URLQueryItem(name: "server", value: server.absoluteString)]
            + (token.isEmpty ? [] : [URLQueryItem(name: "token", value: token)])
            + (group.map { [URLQueryItem(name: "group", value: $0)] } ?? [])
        return components.url!
    }

    public init?(url: URL) {
        guard url.scheme == "recipes", let kind = url.host.flatMap(Kind.init),
              let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems,
              let address = items.first(where: { $0.name == "server" })?.value,
              let server = MealieClient.normalizedServer(address) else { return nil }
        let value = { (name: String) in
            items.first(where: { $0.name == name })?.value?.trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty
        }
        let group = kind == .discover ? value("group") : nil
        let token = value("token")
        guard token != nil || group != nil else { return nil }
        self.init(server: server, token: token ?? "", kind: kind, group: group)
    }
}

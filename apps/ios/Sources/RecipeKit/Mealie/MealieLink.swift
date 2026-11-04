import Foundation

/// The `recipes://mealie?server=<address>&token=<token>` link that pairs the app with a Mealie server, or
/// `recipes://discover?…` that adds one to browse in Discover.
public struct MealieLink: Equatable, Sendable {
    public enum Kind: String, Sendable {
        case sync = "mealie"
        case discover
    }

    public var server: URL
    public var token: String
    public var kind: Kind

    public init(server: URL, token: String, kind: Kind = .sync) {
        self.server = server
        self.token = token
        self.kind = kind
    }

    public var url: URL {
        var components = URLComponents()
        components.scheme = "recipes"
        components.host = kind.rawValue
        components.queryItems = [
            URLQueryItem(name: "server", value: server.absoluteString),
            URLQueryItem(name: "token", value: token),
        ]
        return components.url!
    }

    public init?(url: URL) {
        guard url.scheme == "recipes", let kind = url.host.flatMap(Kind.init),
              let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems,
              let address = items.first(where: { $0.name == "server" })?.value,
              let server = MealieClient.normalizedServer(address),
              let token = items.first(where: { $0.name == "token" })?.value?.trimmingCharacters(in: .whitespacesAndNewlines),
              !token.isEmpty else { return nil }
        self.init(server: server, token: token, kind: kind)
    }
}

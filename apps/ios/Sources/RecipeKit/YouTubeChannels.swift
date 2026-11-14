import Foundation

public struct YouTubeChannel: Identifiable, Hashable, Sendable {
    public var id: String
    public var title: String
    /// "@handle · 1.2M subscribers", or whatever YouTube shows under the name.
    public var detail: String
    public var thumbnailURL: URL?

    public init(id: String, title: String, detail: String = "", thumbnailURL: URL? = nil) {
        self.id = id
        self.title = title
        self.detail = detail
        self.thumbnailURL = thumbnailURL
    }

    /// The channel's public feed of its newest videos.
    public var feedURL: URL { URL(string: "https://www.youtube.com/feeds/videos.xml?channel_id=\(id)")! }
}

/// Finds YouTube channels by name from YouTube's own search page, so they can be followed as feeds without an API key.
public enum YouTubeChannels {
    public static func search(_ query: String) async throws -> [YouTubeChannel] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }
        var parts = URLComponents(string: "https://www.youtube.com/results")!
        // `sp` limits the results to channels.
        parts.queryItems = [URLQueryItem(name: "search_query", value: trimmed), URLQueryItem(name: "sp", value: "EgIQAg==")]
        var request = URLRequest(url: parts.url!, timeoutInterval: 20)
        request.setValue("Mozilla/5.0 (Macintosh) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Safari/605.1.15", forHTTPHeaderField: "User-Agent")
        request.setValue("en-US,en", forHTTPHeaderField: "Accept-Language")
        let (data, _) = try await URLSession.shared.data(for: request)
        return channels(inSearchPage: String(decoding: data, as: UTF8.self))
    }

    /// The channel that posted a video, read from its watch page.
    public static func channel(forVideo id: String) async -> YouTubeChannel? {
        guard let url = URL(string: "https://www.youtube.com/watch?v=\(id)") else { return nil }
        var request = URLRequest(url: url, timeoutInterval: 20)
        request.setValue("Mozilla/5.0 (Macintosh) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Safari/605.1.15", forHTTPHeaderField: "User-Agent")
        request.setValue("en-US,en", forHTTPHeaderField: "Accept-Language")
        guard let response = try? await URLSession.shared.data(for: request) else { return nil }
        return channel(inWatchPage: String(decoding: response.0, as: UTF8.self))
    }

    static func channel(inWatchPage html: String) -> YouTubeChannel? {
        func first(_ pattern: String) -> String? {
            guard let regex = try? NSRegularExpression(pattern: pattern),
                  let match = regex.firstMatch(in: html, range: NSRange(html.startIndex..., in: html)),
                  let range = Range(match.range(at: 1), in: html) else { return nil }
            return String(html[range])
        }
        guard let id = first(#""channelId":"(UC[A-Za-z0-9_-]{22})""#),
              let name = first(#""ownerChannelName":"((?:[^"\\]|\\.)*)""#) ?? first(#""author":"((?:[^"\\]|\\.)*)""#) else { return nil }
        let title = (try? JSONSerialization.jsonObject(with: Data("\"\(name)\"".utf8), options: .fragmentsAllowed) as? String) ?? name
        return YouTubeChannel(id: id, title: title)
    }

    /// The channels in a search results page's embedded `ytInitialData`, in the order shown.
    static func channels(inSearchPage html: String) -> [YouTubeChannel] {
        guard let json = initialData(in: html) else { return [] }
        var found: [YouTubeChannel] = []
        var seen = Set<String>()
        visit(json) { renderer in
            guard let id = renderer["channelId"] as? String, seen.insert(id).inserted, let title = text(renderer["title"]) else { return }
            let details = [text(renderer["subscriberCountText"]), text(renderer["videoCountText"])].compactMap { $0 }.filter { !$0.isEmpty }
            let thumbnails = (renderer["thumbnail"] as? [String: Any])?["thumbnails"] as? [[String: Any]] ?? []
            let thumbnail = (thumbnails.last?["url"] as? String).flatMap { URL(string: $0.hasPrefix("//") ? "https:" + $0 : $0) }
            found.append(YouTubeChannel(id: id, title: title, detail: details.joined(separator: " · "), thumbnailURL: thumbnail))
        }
        return found
    }

    static func initialData(in html: String) -> Any? {
        guard let marker = html.range(of: "var ytInitialData = ") ?? html.range(of: "ytInitialData = ") else { return nil }
        let rest = html[marker.upperBound...]
        guard let end = rest.range(of: ";</script>") else { return nil }
        return try? JSONSerialization.jsonObject(with: Data(rest[..<end.lowerBound].utf8))
    }

    static func visit(_ node: Any, key: String = "channelRenderer", _ found: ([String: Any]) -> Void) {
        if let object = node as? [String: Any] {
            if let renderer = object[key] as? [String: Any] { found(renderer) }
            for (name, value) in object where name != key { visit(value, key: key, found) }
        } else if let array = node as? [Any] {
            for value in array { visit(value, key: key, found) }
        }
    }

    static func text(_ node: Any?) -> String? {
        guard let object = node as? [String: Any] else { return nil }
        if let simple = object["simpleText"] as? String { return simple }
        let runs = (object["runs"] as? [[String: Any]])?.compactMap { $0["text"] as? String }
        return runs.map { $0.joined() }
    }
}

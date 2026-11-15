import Foundation

public struct RecipeSearchResult: Identifiable, Hashable, Sendable {
    public enum Kind: String, Sendable { case web, site, video }

    public var title: String
    public var link: URL
    /// The site or channel it came from.
    public var source: String
    public var imageURL: URL?
    public var kind: Kind
    /// A video's running time, such as "12:04".
    public var duration: String?
    /// A video's views and age, such as "1.2M views · 3 years ago".
    public var detail: String?

    public var id: String { link.absoluteString }

    public init(title: String, link: URL, source: String, imageURL: URL? = nil, kind: Kind, duration: String? = nil, detail: String? = nil) {
        self.title = title
        self.link = link
        self.source = source
        self.imageURL = imageURL
        self.kind = kind
        self.duration = duration
        self.detail = detail
    }
}

/// Searches places that answer without an API key: the web through DuckDuckGo's plain results page, the WordPress sites a user follows, and YouTube.
public enum RecipeSearch {
    /// A recipe-focused Google search to open in a browser.
    public static func webSearchURL(_ query: String) -> URL? {
        var parts = URLComponents(string: "https://www.google.com/search")!
        parts.queryItems = [URLQueryItem(name: "q", value: query.trimmingCharacters(in: .whitespacesAndNewlines) + " recipe")]
        return parts.url
    }

    /// Whether a page belongs to the search engine itself, so tapping around its results stays in the browser.
    public static func isSearchEnginePage(_ url: URL) -> Bool {
        guard let host = url.host?.lowercased() else { return true }
        let engine = host == "google.com" || host.hasSuffix(".google.com") || host.contains(".google.") || host.hasPrefix("google.")
        return engine || host.hasSuffix("gstatic.com") || host.hasSuffix("googleusercontent.com")
    }

    /// Where a search engine's redirect link really goes: Google's `/url?q=` or `/url?url=`.
    public static func destination(of url: URL) -> URL {
        guard isSearchEnginePage(url), url.path == "/url",
              let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems,
              let target = (items.first { $0.name == "q" || $0.name == "url" })?.value.flatMap(URL.init(string:)),
              target.scheme?.hasPrefix("http") == true else { return url }
        return target
    }

    /// Web results from DuckDuckGo's HTML page, the one search page built to be read without a browser.
    public static func web(_ query: String, limit: Int = 10) async -> [RecipeSearchResult] {
        var parts = URLComponents(string: "https://html.duckduckgo.com/html/")!
        parts.queryItems = [URLQueryItem(name: "q", value: query.trimmingCharacters(in: .whitespacesAndNewlines) + " recipe")]
        guard let url = parts.url, let data = await download(url, timeout: 12) else { return [] }
        return Array(webResults(inPage: String(decoding: data, as: UTF8.self)).prefix(limit))
    }

    static func webResults(inPage html: String) -> [RecipeSearchResult] {
        let anchor = try! NSRegularExpression(pattern: #"<a\b([^>]*\bclass="result__a"[^>]*)>(.*?)</a>"#, options: .dotMatchesLineSeparators)
        let href = try! NSRegularExpression(pattern: #"\bhref="([^"]+)""#)
        var seen = Set<String>()
        return anchor.matches(in: html, range: NSRange(html.startIndex..., in: html)).compactMap { match in
            guard let attributesRange = Range(match.range(at: 1), in: html), let titleRange = Range(match.range(at: 2), in: html) else { return nil }
            let attributes = String(html[attributesRange])
            guard let hrefMatch = href.firstMatch(in: attributes, range: NSRange(attributes.startIndex..., in: attributes)),
                  let hrefRange = Range(hrefMatch.range(at: 1), in: attributes) else { return nil }
            var address = plainText(String(attributes[hrefRange]))
            if address.hasPrefix("//") { address = "https:" + address }
            guard var link = URL(string: address) else { return nil }
            if link.host?.hasSuffix("duckduckgo.com") == true {
                guard link.path.hasPrefix("/l"), let target = URLComponents(url: link, resolvingAgainstBaseURL: false)?.queryItems?
                    .first(where: { $0.name == "uddg" })?.value.flatMap(URL.init(string:)) else { return nil }
                link = target
            }
            guard link.scheme?.hasPrefix("http") == true, seen.insert(link.absoluteString).inserted else { return nil }
            let source = link.host?.replacingOccurrences(of: "www.", with: "") ?? ""
            return RecipeSearchResult(title: plainText(String(html[titleRange])), link: link, source: source, kind: .web)
        }
    }

    /// The home page behind a followed feed, for searching the site itself. Nil for YouTube and Reddit, which are searched on their own.
    public static func site(ofFeed address: String) -> URL? {
        guard let url = URL(string: address), let host = url.host?.lowercased(),
              !host.hasSuffix("youtube.com"), !host.hasSuffix("reddit.com") else { return nil }
        var parts = URLComponents()
        parts.scheme = url.scheme ?? "https"
        parts.host = url.host
        return parts.url
    }

    /// Posts matching the query through a WordPress site's REST API, newest first. Sites that aren't WordPress give nothing.
    public static func wordPress(site: URL, query: String, limit: Int = 4) async -> [RecipeSearchResult] {
        guard var parts = URLComponents(url: site.appendingPathComponent("wp-json/wp/v2/posts"), resolvingAgainstBaseURL: false) else { return [] }
        parts.queryItems = [
            URLQueryItem(name: "search", value: query), URLQueryItem(name: "per_page", value: String(limit)),
            URLQueryItem(name: "_embed", value: "wp:featuredmedia"), URLQueryItem(name: "_fields", value: "title,link,_links,_embedded"),
        ]
        guard let url = parts.url, let data = await download(url, timeout: 10) else { return [] }
        return wordPressPosts(data, site: site)
    }

    static func wordPressPosts(_ data: Data, site: URL) -> [RecipeSearchResult] {
        guard let posts = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else { return [] }
        let source = site.host?.replacingOccurrences(of: "www.", with: "") ?? site.absoluteString
        return posts.compactMap { post in
            guard let title = (post["title"] as? [String: Any])?["rendered"] as? String,
                  let link = (post["link"] as? String).flatMap(URL.init(string:)) else { return nil }
            let media = ((post["_embedded"] as? [String: Any])?["wp:featuredmedia"] as? [[String: Any]])?.first
            let image = (media?["source_url"] as? String).flatMap(URL.init(string:))
            return RecipeSearchResult(title: plainText(title), link: link, source: source, imageURL: image, kind: .site)
        }
    }

    public static func youTube(_ query: String, limit: Int = 8) async -> [RecipeSearchResult] {
        var parts = URLComponents(string: "https://www.youtube.com/results")!
        // `sp` limits the results to videos.
        parts.queryItems = [URLQueryItem(name: "search_query", value: query + " recipe"), URLQueryItem(name: "sp", value: "EgIQAQ==")]
        guard let url = parts.url, let data = await download(url, timeout: 15) else { return [] }
        return Array(youTubeVideos(inSearchPage: String(decoding: data, as: UTF8.self)).prefix(limit))
    }

    static func youTubeVideos(inSearchPage html: String) -> [RecipeSearchResult] {
        guard let json = YouTubeChannels.initialData(in: html) else { return [] }
        var found: [RecipeSearchResult] = []
        var seen = Set<String>()
        YouTubeChannels.visit(json, key: "videoRenderer") { video in
            guard let id = video["videoId"] as? String, seen.insert(id).inserted,
                  let title = YouTubeChannels.text(video["title"]),
                  let link = URL(string: "https://www.youtube.com/watch?v=\(id)") else { return }
            let channel = YouTubeChannels.text(video["ownerText"]) ?? "YouTube"
            let detail = [video["shortViewCountText"] ?? video["viewCountText"], video["publishedTimeText"]].compactMap(YouTubeChannels.text)
            found.append(RecipeSearchResult(title: title, link: link, source: channel,
                                            imageURL: URL(string: "https://i.ytimg.com/vi/\(id)/hqdefault.jpg"), kind: .video,
                                            duration: YouTubeChannels.text(video["lengthText"]), detail: detail.isEmpty ? nil : detail.joined(separator: " · ")))
        }
        return found
    }

    /// Drops tags and decodes the entities WordPress titles use: "Mac &#038; Cheese" is "Mac & Cheese".
    static func plainText(_ html: String) -> String {
        var text = html.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
        let named = ["&amp;": "&", "&quot;": "\"", "&apos;": "'", "&lt;": "<", "&gt;": ">", "&nbsp;": " ", "&hellip;": "…", "&ndash;": "–", "&mdash;": "—"]
        for (entity, character) in named { text = text.replacingOccurrences(of: entity, with: character) }
        let numeric = try! NSRegularExpression(pattern: "&#(x?)([0-9A-Fa-f]+);")
        for match in numeric.matches(in: text, range: NSRange(text.startIndex..., in: text)).reversed() {
            guard let whole = Range(match.range, in: text), let hexRange = Range(match.range(at: 1), in: text),
                  let digitsRange = Range(match.range(at: 2), in: text),
                  let value = UInt32(text[digitsRange], radix: text[hexRange].isEmpty ? 10 : 16),
                  let scalar = Unicode.Scalar(value) else { continue }
            text.replaceSubrange(whole, with: String(Character(scalar)))
        }
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func download(_ url: URL, timeout: TimeInterval) async -> Data? {
        var request = URLRequest(url: url, timeoutInterval: timeout)
        request.setValue("Mozilla/5.0 (Macintosh) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Safari/605.1.15", forHTTPHeaderField: "User-Agent")
        request.setValue("en-US,en", forHTTPHeaderField: "Accept-Language")
        guard let response = try? await URLSession.shared.data(for: request),
              (response.1 as? HTTPURLResponse).map({ (200..<300).contains($0.statusCode) }) ?? true else { return nil }
        return response.0
    }
}

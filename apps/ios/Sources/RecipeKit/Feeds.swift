import Foundation

public struct Feed: Codable, Identifiable, Hashable, Sendable {
    public var id: UUID
    public var url: String
    public var title: String
    public var createdAt: Date

    public init(id: UUID = UUID(), url: String, title: String, createdAt: Date = Date()) {
        self.id = id
        self.url = url
        self.title = title
        self.createdAt = createdAt
    }
}

public struct FeedEntry: Identifiable, Hashable, Codable, Sendable {
    public var title: String
    public var link: URL
    public var published: Date?
    public var summary: String
    public var imageURL: URL?

    public var id: String { link.absoluteString }

    public init(title: String, link: URL, published: Date? = nil, summary: String = "", imageURL: URL? = nil) {
        self.title = title
        self.link = link
        self.published = published
        self.summary = summary
        self.imageURL = imageURL
    }
}

public enum FeedParser {
    public static func parse(_ data: Data, baseURL: URL? = nil) throws -> (title: String, entries: [FeedEntry]) {
        let delegate = FeedXMLDelegate(baseURL: baseURL)
        let parser = XMLParser(data: data)
        parser.delegate = delegate
        guard parser.parse(), delegate.sawFeed else {
            throw RecipeError.invalid("That address isn't an RSS or Atom feed.")
        }
        return (delegate.feedTitle, delegate.entries)
    }
}

private final class FeedXMLDelegate: NSObject, XMLParserDelegate {
    struct Draft {
        var title = "", link = "", summary = "", date = "", image = ""
        var imageWidth = 0
    }

    let baseURL: URL?
    var feedTitle = ""
    var entries: [FeedEntry] = []
    var sawFeed = false

    private var inItem = false
    private var text = ""
    private var draft = Draft()

    init(baseURL: URL?) {
        self.baseURL = baseURL
    }

    func parser(_ parser: XMLParser, didStartElement name: String, namespaceURI: String?, qualifiedName: String?, attributes: [String: String] = [:]) {
        text = ""
        if name == "rss" || name == "feed" || name == "rdf:RDF" { sawFeed = true }
        if name == "item" || name == "entry" {
            inItem = true
            draft = Draft()
        }
        guard inItem else { return }
        switch name {
        case "link":
            if let href = attributes["href"], attributes["rel"] == nil || attributes["rel"] == "alternate" { draft.link = href }
        case "enclosure":
            if let url = attributes["url"], attributes["type"]?.hasPrefix("image") == true, draft.image.isEmpty { draft.image = url }
        case "media:thumbnail", "media:content":
            let medium = attributes["medium"], type = attributes["type"]
            let isImage = name == "media:thumbnail" || medium == "image" || type?.hasPrefix("image") == true || (medium == nil && type == nil)
            let width = attributes["width"].flatMap(Int.init) ?? 0
            if let url = attributes["url"], isImage, draft.image.isEmpty || width > draft.imageWidth {
                draft.image = url
                draft.imageWidth = width
            }
        default: break
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) { text += string }

    func parser(_ parser: XMLParser, foundCDATA CDATABlock: Data) {
        text += String(decoding: CDATABlock, as: UTF8.self)
    }

    func parser(_ parser: XMLParser, didEndElement name: String, namespaceURI: String?, qualifiedName: String?) {
        let value = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if inItem {
            switch name {
            case "title": draft.title = value
            case "link": if draft.link.isEmpty { draft.link = value }
            case "description", "summary": if draft.summary.isEmpty { draft.summary = value }
            case "content:encoded", "content": if draft.summary.isEmpty || name == "content:encoded" { draft.summary = value }
            case "pubDate", "published", "updated", "dc:date": if draft.date.isEmpty { draft.date = value }
            case "item", "entry": finishItem()
            default: break
            }
        } else if name == "title", feedTitle.isEmpty {
            feedTitle = RecipeImporter.clean(value)
        }
        text = ""
    }

    private func finishItem() {
        inItem = false
        guard let link = URL(string: draft.link, relativeTo: baseURL)?.absoluteURL, !draft.title.isEmpty else { return }
        var image = URL(string: Self.unescape(draft.image), relativeTo: baseURL)?.absoluteURL
        if image == nil, let tag = draft.summary.range(of: #"<img\b[^>]*>"#, options: .regularExpression).map({ String(draft.summary[$0]) }) {
            image = (Self.largestSource(inSrcset: tag) ?? Self.attribute("src", in: tag))
                .flatMap { URL(string: Self.unescape($0), relativeTo: baseURL)?.absoluteURL }
        }
        let summary = RecipeImporter.clean(draft.summary)
        entries.append(FeedEntry(
            title: RecipeImporter.clean(draft.title),
            link: link,
            published: Self.date(from: draft.date),
            summary: String(summary.prefix(240)),
            imageURL: image.map(FeedImage.full)
        ))
    }

    private static func attribute(_ name: String, in tag: String) -> String? {
        guard let range = tag.range(of: #"\b"# + name + #"\s*=\s*["']([^"']+)["']"#, options: [.regularExpression, .caseInsensitive]),
              let value = tag[range].range(of: #"(?<=["'])[^"']+"#, options: .regularExpression) else { return nil }
        return String(tag[range][value])
    }

    private static func largestSource(inSrcset tag: String) -> String? {
        guard let srcset = attribute("srcset", in: tag) else { return nil }
        return srcset.split(separator: ",")
            .compactMap { candidate -> (url: String, width: Int)? in
                let parts = candidate.split(separator: " ")
                guard let url = parts.first else { return nil }
                return (String(url), parts.dropFirst().first.flatMap { Int($0.dropLast()) } ?? 0)
            }
            .max { $0.width < $1.width }?.url
    }

    private static func unescape(_ string: String) -> String {
        string.replacingOccurrences(of: "&amp;", with: "&").replacingOccurrences(of: "&#038;", with: "&")
    }

    private static func date(from string: String) -> Date? {
        if string.isEmpty { return nil }
        let iso = ISO8601DateFormatter()
        if let date = iso.date(from: string) { return date }
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = iso.date(from: string) { return date }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        for format in ["EEE, dd MMM yyyy HH:mm:ss Z", "EEE, dd MMM yyyy HH:mm:ss zzz", "dd MMM yyyy HH:mm:ss Z"] {
            formatter.dateFormat = format
            if let date = formatter.date(from: string) { return date }
        }
        return nil
    }
}

public enum FeedImage {
    /// Drops the on-the-fly resize WordPress image CDNs add, so a post shows its full photo.
    public static func full(_ url: URL) -> URL {
        guard var parts = URLComponents(url: url, resolvingAgainstBaseURL: false), let items = parts.queryItems,
              url.host?.hasSuffix(".wp.com") == true || url.path.contains("/tachyon/") || url.path.contains("/wp-content/") else { return url }
        let resizing: Set<String> = ["resize", "fit", "w", "h", "crop"]
        let kept = items.filter { !resizing.contains($0.name) }
        guard kept.count != items.count else { return url }
        parts.queryItems = kept.isEmpty ? nil : kept
        return parts.url ?? url
    }
}

public enum FeedService {
    /// The given page of a feed. WordPress feeds page with `paged`; others ignore it and repeat the first page.
    public static func pageURL(_ url: URL, page: Int) -> URL {
        guard page > 1, var parts = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return url }
        parts.queryItems = (parts.queryItems ?? []).filter { $0.name != "paged" } + [URLQueryItem(name: "paged", value: String(page))]
        return parts.url ?? url
    }

    public static func fetch(_ url: URL) async throws -> (title: String, entries: [FeedEntry]) {
        let (data, _) = try await download(url)
        return try FeedParser.parse(data, baseURL: url)
    }

    /// The feed behind a shared link that names a source rather than one post: a YouTube channel or playlist, a site's front page, or a feed itself.
    public static func followable(_ url: URL) async -> (url: URL, title: String)? {
        let host = url.host?.lowercased() ?? ""
        let path = url.path
        if host == "youtube.com" || host.hasSuffix(".youtube.com") {
            if path == "/playlist", let list = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems?.first(where: { $0.name == "list" })?.value,
               let feed = URL(string: "https://www.youtube.com/feeds/videos.xml?playlist_id=\(list)") {
                return (try? await fetch(feed)).map { (feed, $0.title) }
            }
            guard ["/@", "/channel/", "/c/", "/user/"].contains(where: path.hasPrefix) else { return nil }
            return try? await discover(from: url)
        }
        let lowered = path.lowercased()
        let isSourcePage = path.isEmpty || path == "/" || ["/feed", "/feed/", "/rss", "/rss/", ".xml", ".rss", ".atom"].contains(where: lowered.hasSuffix)
        return isSourcePage ? try? await discover(from: url) : nil
    }

    /// Accepts a feed URL or a site URL and finds the feed behind it.
    public static func discover(from url: URL) async throws -> (url: URL, title: String) {
        let (data, response) = try await download(url)
        let finalURL = response.url ?? url
        if let feed = try? FeedParser.parse(data, baseURL: finalURL) { return (finalURL, feed.title) }

        let html = String(decoding: data, as: UTF8.self)
        let linkTag = try! NSRegularExpression(pattern: #"<link\b[^>]*>"#, options: .caseInsensitive)
        let tags = linkTag.matches(in: html, range: NSRange(html.startIndex..., in: html)).compactMap { match in
            Range(match.range, in: html).map { String(html[$0]) }
        }
        for tag in tags where tag.range(of: #"type\s*=\s*["']application/(rss|atom)\+xml["']"#, options: [.regularExpression, .caseInsensitive]) != nil {
            guard let hrefRange = tag.range(of: #"href\s*=\s*["']([^"']+)["']"#, options: [.regularExpression, .caseInsensitive]),
                  let valueRange = tag[hrefRange].range(of: #"(?<=["'])[^"']+"#, options: .regularExpression),
                  let feedURL = URL(string: String(tag[hrefRange][valueRange]), relativeTo: finalURL)?.absoluteURL else { continue }
            let (feedData, _) = try await download(feedURL)
            let feed = try FeedParser.parse(feedData, baseURL: feedURL)
            return (feedURL, feed.title)
        }
        throw RecipeError.invalid("No feed found at that address.")
    }

    private static func download(_ url: URL) async throws -> (Data, URLResponse) {
        var request = URLRequest(url: url, timeoutInterval: 20)
        request.setValue("Mozilla/5.0 (Macintosh) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Safari/605.1.15", forHTTPHeaderField: "User-Agent")
        let result = try await URLSession.shared.data(for: request)
        if let http = result.1 as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            throw RecipeError.invalid("The site returned HTTP \(http.statusCode).")
        }
        return result
    }
}

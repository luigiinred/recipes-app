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

public struct FeedEntry: Identifiable, Hashable, Sendable {
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
            if let url = attributes["url"], draft.image.isEmpty, name == "media:thumbnail" || attributes["medium"] == "image" || attributes["type"]?.hasPrefix("image") == true {
                draft.image = url
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
        var image = URL(string: draft.image, relativeTo: baseURL)?.absoluteURL
        if image == nil, let range = draft.summary.range(of: #"<img[^>]+src=["']([^"']+)["']"#, options: .regularExpression),
           let src = draft.summary[range].range(of: #"(?<=src=["'])[^"']+"#, options: .regularExpression) {
            image = URL(string: String(draft.summary[range][src]), relativeTo: baseURL)?.absoluteURL
        }
        let summary = RecipeImporter.clean(draft.summary)
        entries.append(FeedEntry(
            title: RecipeImporter.clean(draft.title),
            link: link,
            published: Self.date(from: draft.date),
            summary: String(summary.prefix(240)),
            imageURL: image
        ))
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

public enum FeedService {
    public static func fetch(_ url: URL) async throws -> (title: String, entries: [FeedEntry]) {
        let (data, _) = try await download(url)
        return try FeedParser.parse(data, baseURL: url)
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

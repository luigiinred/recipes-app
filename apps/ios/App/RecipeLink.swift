import Foundation
import RecipeKit

enum AppDestination { case plan, groceries, feeds }

/// The `recipes://recipe/<id>` link the share extension uses to open a saved recipe, `recipes://cook/<id>` for cook mode, and `recipes://feed-post` for a post the Feeds widget shows.
enum RecipeLink {
    static func url(for id: UUID) -> URL { URL(string: "recipes://recipe/\(id.uuidString.lowercased())")! }

    static func cookURL(for id: UUID) -> URL { URL(string: "recipes://cook/\(id.uuidString.lowercased())")! }

    static func feedPostURL(for entry: FeedEntry) -> URL {
        var components = URLComponents()
        components.scheme = "recipes"
        components.host = "feed-post"
        components.queryItems = [URLQueryItem(name: "link", value: entry.link.absoluteString), URLQueryItem(name: "title", value: entry.title)]
        return components.url!
    }

    static func feedEntry(from url: URL) -> FeedEntry? {
        guard url.scheme == "recipes", url.host == "feed-post",
              let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems,
              let link = items.first(where: { $0.name == "link" })?.value.flatMap(URL.init(string:)) else { return nil }
        return FeedEntry(title: items.first { $0.name == "title" }?.value ?? "", link: link)
    }

    static func destination(from url: URL) -> AppDestination? {
        guard url.scheme == "recipes" else { return nil }
        switch url.host {
        case "plan": return .plan
        case "groceries": return .groceries
        case "feeds": return .feeds
        default: return nil
        }
    }

    static func cookRecipeID(from url: URL) -> UUID? {
        guard url.scheme == "recipes", url.host == "cook" else { return nil }
        return UUID(uuidString: url.lastPathComponent)
    }

    static func recipeID(from url: URL) -> UUID? {
        guard url.scheme == "recipes", url.host == "recipe" else { return nil }
        return UUID(uuidString: url.lastPathComponent)
    }
}

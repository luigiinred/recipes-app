import Foundation

/// What a search result's page says about itself: its photo and, when it holds a recipe, how long it takes.
public struct PagePreview: Hashable, Sendable {
    public var imageURL: URL?
    public var minutes: Int?
    public var isRecipe: Bool

    public init(imageURL: URL? = nil, minutes: Int? = nil, isRecipe: Bool = false) {
        self.imageURL = imageURL
        self.minutes = minutes
        self.isRecipe = isRecipe
    }

    public init(html: String, url: URL) {
        let recipe = try? RecipeImporter.recipe(fromHTML: html, sourceURL: url)
        let image = recipe?.imageURL ?? RecipeImporter.openGraphImage(in: html, base: url)
        self.init(imageURL: image.flatMap { URL(string: $0, relativeTo: url)?.absoluteURL },
                  minutes: recipe?.totalMinutes, isRecipe: recipe != nil)
    }

    public static func load(_ url: URL) async -> PagePreview? {
        var request = URLRequest(url: url, timeoutInterval: 10)
        request.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 18_7 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko)", forHTTPHeaderField: "User-Agent")
        guard let (data, response) = try? await URLSession.shared.data(for: request),
              (response as? HTTPURLResponse)?.statusCode ?? 200 < 400,
              let html = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .isoLatin1) else { return nil }
        return PagePreview(html: html, url: url)
    }
}

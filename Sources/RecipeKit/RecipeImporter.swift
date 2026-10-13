import Foundation

public struct ImportResult: Sendable {
    public var recipe: Recipe
    public var imageData: Data?
    public var isComplete: Bool
    /// Raw text (description or captions) to show when the recipe needs review.
    public var sourceText: String?
    public var sourceTitle: String
    public var message: String?

    public init(recipe: Recipe, imageData: Data? = nil, isComplete: Bool = true, sourceText: String? = nil, sourceTitle: String = "Scanned text", message: String? = nil) {
        self.recipe = recipe
        self.imageData = imageData
        self.isComplete = isComplete
        self.sourceText = sourceText
        self.sourceTitle = sourceTitle
        self.message = message
    }
}

public enum RecipeImporter {
    public static func importResult(from url: URL) async throws -> ImportResult {
        if YouTubeImporter.videoID(from: url) != nil { return try await YouTubeImporter.importResult(from: url) }
        let recipe = try await webRecipe(from: url)
        return ImportResult(recipe: recipe, imageData: await RecipeImageProcessing.download(recipe.imageURL, relativeTo: url))
    }

    public static func recipe(from url: URL) async throws -> Recipe {
        try await importResult(from: url).recipe
    }

    static func webRecipe(from url: URL) async throws -> Recipe {
        var request = URLRequest(url: url, timeoutInterval: 20)
        request.setValue(
            "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Safari/605.1.15",
            forHTTPHeaderField: "User-Agent"
        )
        let (data, response) = try await URLSession.shared.data(for: request)
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            throw RecipeError.invalid("The page returned HTTP \(http.statusCode).")
        }
        let html = String(data: data, encoding: .utf8) ?? String(decoding: data, as: UTF8.self)
        return try recipe(fromHTML: html, sourceURL: url)
    }

    public static func recipe(fromHTML html: String, sourceURL: URL?) throws -> Recipe {
        for block in jsonLDBlocks(in: html) {
            guard let data = block.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: data),
                  let object = findRecipe(in: json) else { continue }
            if var recipe = makeRecipe(from: object, sourceURL: sourceURL) {
                if recipe.imageURL == nil { recipe.imageURL = openGraphImage(in: html, base: sourceURL) }
                return recipe
            }
        }
        throw RecipeError.invalid("No recipe found on that page.")
    }

    static func openGraphImage(in html: String, base: URL?) -> String? {
        let metaTag = try! NSRegularExpression(pattern: #"<meta\b[^>]*>"#, options: .caseInsensitive)
        for match in metaTag.matches(in: html, range: NSRange(html.startIndex..., in: html)) {
            guard let range = Range(match.range, in: html) else { continue }
            let tag = String(html[range])
            guard tag.range(of: #"(property|name)\s*=\s*["']og:image(:secure_url)?["']"#, options: [.regularExpression, .caseInsensitive]) != nil,
                  let contentRange = tag.range(of: #"content\s*=\s*["']([^"']+)["']"#, options: [.regularExpression, .caseInsensitive]),
                  let valueRange = tag[contentRange].range(of: #"(?<=["'])[^"']+"#, options: .regularExpression) else { continue }
            return clean(String(tag[contentRange][valueRange]))
        }
        return nil
    }

    private static func imageString(_ value: Any?) -> String? {
        if let string = value as? String { return string }
        if let array = value as? [Any] { return array.lazy.compactMap { imageString($0) }.first }
        if let object = value as? [String: Any] { return imageString(object["url"] ?? object["contentUrl"]) }
        return nil
    }

    static func jsonLDBlocks(in html: String) -> [String] {
        let pattern = #"<script[^>]*type\s*=\s*["']application/ld\+json["'][^>]*>(.*?)</script>"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators, .caseInsensitive]) else {
            return []
        }
        let range = NSRange(html.startIndex..., in: html)
        return regex.matches(in: html, range: range).compactMap { match in
            Range(match.range(at: 1), in: html).map { String(html[$0]) }
        }
    }

    private static func findRecipe(in json: Any) -> [String: Any]? {
        if let array = json as? [Any] {
            return array.lazy.compactMap { findRecipe(in: $0) }.first
        }
        guard let object = json as? [String: Any] else { return nil }
        if isRecipe(object["@type"]) { return object }
        if let graph = object["@graph"] { return findRecipe(in: graph) }
        return nil
    }

    private static func isRecipe(_ type: Any?) -> Bool {
        if let string = type as? String { return string == "Recipe" }
        if let array = type as? [Any] { return array.contains { ($0 as? String) == "Recipe" } }
        return false
    }

    private static func makeRecipe(from object: [String: Any], sourceURL: URL?) -> Recipe? {
        guard let title = text(object["name"]), !title.isEmpty else { return nil }
        let ingredients = strings(object["recipeIngredient"] ?? object["ingredients"])
        var tags: [String] = []
        for tag in strings(object["recipeCategory"]) where !tag.isEmpty && !tags.contains(where: { $0.caseInsensitiveCompare(tag) == .orderedSame }) {
            tags.append(tag)
        }
        return Recipe(
            title: title,
            summary: text(object["description"]) ?? "",
            servings: firstInt(in: strings(object["recipeYield"]).first),
            prepMinutes: minutes(from: object["prepTime"]),
            cookMinutes: minutes(from: object["cookTime"]),
            ingredients: ingredients,
            steps: instructions(object["recipeInstructions"]),
            tags: Array(tags.prefix(3)),
            sourceURL: sourceURL?.absoluteString,
            imageURL: imageString(object["image"])
        )
    }

    private static func instructions(_ value: Any?) -> [String] {
        if let string = value as? String {
            return string.split(whereSeparator: \.isNewline).map { clean(String($0)) }.filter { !$0.isEmpty }
        }
        if let array = value as? [Any] { return array.flatMap { instructions($0) } }
        if let object = value as? [String: Any] {
            if let nested = object["itemListElement"] { return instructions(nested) }
            if let step = text(object["text"]) ?? text(object["name"]) { return [step] }
        }
        return []
    }

    private static func strings(_ value: Any?) -> [String] {
        if let string = value as? String { return [clean(string)].filter { !$0.isEmpty } }
        if let number = value as? NSNumber { return [number.stringValue] }
        if let array = value as? [Any] { return array.flatMap { strings($0) } }
        return []
    }

    private static func text(_ value: Any?) -> String? {
        strings(value).first
    }

    private static func firstInt(in string: String?) -> Int? {
        guard let string, let range = string.range(of: #"\d+"#, options: .regularExpression) else { return nil }
        return Int(string[range])
    }

    static func minutes(from value: Any?) -> Int? {
        guard let duration = value as? String,
              let regex = try? NSRegularExpression(pattern: #"^P(?:(\d+)D)?(?:T(?:(\d+)H)?(?:(\d+)M)?)?$"#) else { return nil }
        let range = NSRange(duration.startIndex..., in: duration)
        guard let match = regex.firstMatch(in: duration, range: range) else { return nil }
        func part(_ index: Int) -> Int {
            Range(match.range(at: index), in: duration).flatMap { Int(duration[$0]) } ?? 0
        }
        let total = part(1) * 1440 + part(2) * 60 + part(3)
        return total > 0 ? total : nil
    }

    static func clean(_ string: String) -> String {
        var result = string.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
        let named = ["&amp;": "&", "&quot;": "\"", "&#39;": "'", "&apos;": "'", "&lt;": "<", "&gt;": ">", "&nbsp;": " "]
        for (entity, replacement) in named { result = result.replacingOccurrences(of: entity, with: replacement) }
        while let range = result.range(of: #"&#(x?)([0-9a-fA-F]+);"#, options: .regularExpression) {
            let body = result[range].dropFirst(2).dropLast()
            let value = body.hasPrefix("x") ? UInt32(body.dropFirst(), radix: 16) : UInt32(body)
            let replacement = value.flatMap(Unicode.Scalar.init).map { String(Character($0)) } ?? ""
            result.replaceSubrange(range, with: replacement)
        }
        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

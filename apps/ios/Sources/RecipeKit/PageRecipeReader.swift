import Foundation

extension RecipeImporter {
    /// Reads a recipe off a page that has no recipe data, with the on-device language model.
    public static func importResultWithAppleIntelligence(from url: URL, progress: ImportProgress? = nil) async throws -> ImportResult {
        progress?(.plan(["Fetching the page", "Reading it with Apple Intelligence", "Downloading the photo"]))
        let status = AppleIntelligence.status
        guard status.isAvailable else { throw RecipeError.invalid(status.explanation) }
        TranscriptRecipeExtractor.prewarm()
        progress?(.began(0))
        let html = try await fetchHTML(from: url)
        progress?(.finished(0))

        progress?(.began(1))
        let title = pageTitle(fromHTML: html) ?? url.host ?? "Recipe"
        let text = visibleText(fromHTML: html)
        let extracted: TranscriptRecipeExtractor.Extracted
        switch await TranscriptRecipeExtractor.run(title: title, transcript: text, material: .webPage) {
        case .extracted(let value): extracted = value
        case .unavailable(let status): throw RecipeError.invalid(status.explanation)
        case .failed(let reason): throw RecipeError.invalid("Apple Intelligence couldn't read a recipe from this page. \(reason)")
        }
        guard extracted.ingredients.count >= 2, !extracted.steps.isEmpty else {
            throw RecipeError.invalid("Apple Intelligence couldn't find a recipe on this page.")
        }
        var recipe = Recipe(
            title: RecipeStandards.importedTitle(title), summary: String(extracted.summary.prefix(300)),
            servings: extracted.servings, ingredients: extracted.ingredients, steps: extracted.steps
        )
        recipe.sourceURL = url.absoluteString
        recipe.imageURL = openGraphImage(in: html, base: url)
        recipe.tags = RecipeTags.suggest(for: recipe)
        progress?(.finished(1))

        progress?(.began(2))
        let image = await RecipeImageProcessing.download(recipe.imageURL, relativeTo: url)
        progress?(.finished(2))
        return ImportResult(
            recipe: recipe.standardized(), imageData: image, isComplete: false, sourceText: text, sourceTitle: "Page text",
            message: "Apple Intelligence wrote this from the page's text. Check the ingredients and steps against the page."
        )
    }

    static func pageTitle(fromHTML html: String) -> String? {
        guard let range = html.range(of: #"<title[^>]*>[\s\S]*?</title>"#, options: [.regularExpression, .caseInsensitive]) else { return nil }
        let title = clean(String(html[range]))
        return title.isEmpty ? nil : title
    }

    /// The words on a page, a line per paragraph or list item, without scripts, styles and markup.
    static func visibleText(fromHTML html: String) -> String {
        var text = html
        for block in ["script", "style", "noscript", "svg", "head", "nav", "footer"] {
            text = text.replacingOccurrences(of: "<\(block)\\b[\\s\\S]*?</\(block)>", with: " ", options: [.regularExpression, .caseInsensitive])
        }
        text = text.replacingOccurrences(of: "<!--[\\s\\S]*?-->", with: " ", options: .regularExpression)
        text = text.replacingOccurrences(of: "</?(p|div|li|ul|ol|br|h[1-6]|tr|section|article)\\b[^>]*>", with: "\n", options: [.regularExpression, .caseInsensitive])
        return clean(text)
            .split(whereSeparator: \.isNewline)
            .map { $0.split(whereSeparator: \.isWhitespace).joined(separator: " ") }
            .filter { !$0.isEmpty }
            .joined(separator: "\n")
    }
}

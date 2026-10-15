import Foundation

public enum RecipePrint {
    public static func html(for recipe: Recipe) -> String {
        func esc(_ text: String) -> String {
            text.replacingOccurrences(of: "&", with: "&amp;").replacingOccurrences(of: "<", with: "&lt;").replacingOccurrences(of: ">", with: "&gt;")
        }
        var facts: [String] = []
        if let servings = recipe.servings { facts.append("Serves \(servings)") }
        if let prep = recipe.prepMinutes { facts.append("Prep \(prep) min") }
        if let cook = recipe.cookMinutes { facts.append("Cook \(cook) min") }

        var body = "<h1>\(esc(recipe.title))</h1>"
        if !recipe.summary.isEmpty { body += "<p class=\"summary\">\(esc(recipe.summary))</p>" }
        if !facts.isEmpty { body += "<p class=\"facts\">\(esc(facts.joined(separator: "  ·  ")))</p>" }
        if !recipe.ingredients.isEmpty {
            body += "<h2>Ingredients</h2>"
            for group in recipe.ingredientGroups {
                if let title = group.title { body += "<h3>\(esc(title))</h3>" }
                body += "<ul>" + group.items.map { "<li>\(esc($0.text))</li>" }.joined() + "</ul>"
            }
        }
        if !recipe.steps.isEmpty {
            body += "<h2>Method</h2><ol>" + recipe.steps.map { "<li>\(esc($0))</li>" }.joined() + "</ol>"
        }
        if !recipe.notes.isEmpty { body += "<h2>Notes</h2><p>\(esc(recipe.notes))</p>" }
        if let source = recipe.sourceURL, !source.isEmpty { body += "<p class=\"source\">\(esc(source))</p>" }

        return """
        <html><head><meta charset="utf-8"><style>
        body { font-family: Georgia, serif; font-size: 12pt; line-height: 1.45; }
        h1 { font-size: 24pt; margin-bottom: 4pt; }
        h3 { font-size: 11pt; margin: 10pt 0 4pt; }
        h2 { font-size: 11pt; text-transform: uppercase; letter-spacing: 1pt; margin-top: 18pt; }
        .summary { font-style: italic; } .facts, .source { color: #666; font-size: 10pt; }
        li { margin-bottom: 5pt; }
        </style></head><body>\(body)</body></html>
        """
    }
}

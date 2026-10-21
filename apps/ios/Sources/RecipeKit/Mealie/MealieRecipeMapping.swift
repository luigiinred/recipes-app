import Foundation

extension Dictionary where Key == String, Value == Any {
    func string(_ key: String) -> String? { self[key] as? String }
    func double(_ key: String) -> Double? { (self[key] as? NSNumber)?.doubleValue }
    func objects(_ key: String) -> [MealieObject] { self[key] as? [MealieObject] ?? [] }
}

/// Translates between a `Recipe` and Mealie's recipe JSON. Pushing patches the recipe Mealie already has, so fields the
/// app has no place for (nutrition, tools, structured ingredients) are left as they were.
enum MealieRecipeMapping {
    static let extrasKey = "recipesApp"
    static let notesTitle = "Notes"

    /// What Mealie can't hold natively, stored in the recipe's `extras` so every device sees it.
    struct LocalExtras: Codable, Equatable {
        var id: UUID
        var stepTimestamps: [Int?]
        var wantToCook: Bool
        var queuedAt: Date?
        var imageURL: String?
    }

    // MARK: - Mealie to app

    static func recipe(from remote: MealieObject, rating: MealieRating?, existing: Recipe?, id: UUID) -> Recipe {
        var recipe = existing ?? Recipe(id: id, title: "")
        recipe.title = remote.string("name")?.trimmed.nonEmpty ?? existing?.title ?? "Untitled"
        recipe.summary = remote.string("description")?.trimmed ?? ""
        recipe.servings = servings(in: remote)
        recipe.prepMinutes = minutes(in: remote, seconds: "prepTimeSeconds", text: "prepTime")
        recipe.cookMinutes = minutes(in: remote, seconds: "performTimeSeconds", text: "performTime") ?? minutes(in: remote, seconds: nil, text: "cookTime")

        var ingredients: [String] = []
        var sections: [IngredientSection] = []
        for item in remote.objects("recipeIngredient") {
            let text = ingredientText(item)
            guard !text.isEmpty else { continue }
            if let title = item.string("title")?.trimmed.nonEmpty { sections.append(IngredientSection(title: title, start: ingredients.count)) }
            ingredients.append(text)
        }
        recipe.ingredients = ingredients
        recipe.ingredientSections = sections

        let steps = remote.objects("recipeInstructions").compactMap { $0.string("text")?.trimmed.nonEmpty }
        let previousSteps = existing?.steps ?? []
        recipe.stepImages = carry(from: previousSteps, values: existing?.stepImages ?? [], to: steps)
        recipe.stepTimestamps = carry(from: previousSteps, values: existing?.stepTimestamps ?? [], to: steps)
        recipe.steps = steps

        recipe.tags = labelNames(in: remote)
        recipe.sourceURL = remote.string("orgURL")?.trimmed.nonEmpty
        recipe.notes = renderNotes(remote.objects("notes"))
        recipe.rating = rating?.rating.flatMap { $0 > 0 ? min(5, max(1, Int($0.rounded()))) : nil }
        recipe.isFavorite = rating?.isFavorite ?? false

        if let extras = extras(in: remote) {
            recipe.wantToCook = extras.wantToCook
            recipe.queuedAt = extras.queuedAt
            recipe.imageURL = extras.imageURL
            if extras.stepTimestamps.count == steps.count { recipe.stepTimestamps = extras.stepTimestamps }
        }
        recipe.createdAt = existing?.createdAt ?? remote.string("createdAt").flatMap(MealieDate.parse) ?? Date()
        recipe.updatedAt = remote.string("updatedAt").flatMap(MealieDate.parse) ?? Date()
        return recipe
    }

    static func extras(in remote: MealieObject) -> LocalExtras? {
        guard let text = (remote["extras"] as? MealieObject)?.string(extrasKey), let data = text.data(using: .utf8) else { return nil }
        return try? extrasDecoder.decode(LocalExtras.self, from: data)
    }

    static func appID(in remote: MealieObject) -> UUID? { extras(in: remote)?.id }

    static func ingredientText(_ ingredient: MealieObject) -> String {
        for key in ["display", "note", "originalText"] {
            if let text = ingredient.string(key)?.trimmed.nonEmpty { return text }
        }
        return ""
    }

    static func labelNames(in remote: MealieObject) -> [String] {
        var seen = Set<String>()
        var names: [String] = []
        for item in remote.objects("tags") + remote.objects("recipeCategory") {
            guard let name = item.string("name").map(CategoryTree.normalized), !name.isEmpty, seen.insert(name.lowercased()).inserted else { continue }
            names.append(name)
        }
        return names
    }

    static func servings(in remote: MealieObject) -> Int? {
        for key in ["recipeServings", "recipeYieldQuantity"] {
            if let value = remote.double(key), value > 0 { return Int(value.rounded()) }
        }
        return nil
    }

    static func minutes(in remote: MealieObject, seconds: String?, text: String) -> Int? {
        if let seconds, let value = remote.double(seconds), value > 0 { return Int((value / 60).rounded(.up)) }
        return remote.string(text).flatMap(parseMinutes)
    }

    /// "PT1H30M", "1 hr 30 min", "45 minutes" or a bare number of minutes.
    static func parseMinutes(_ text: String) -> Int? {
        let lowered = text.lowercased().trimmed
        if let bare = Double(lowered) { return bare > 0 ? Int(bare.rounded()) : nil }
        let pattern = #"(\d+(?:\.\d+)?)\s*(days?|d|hours?|hrs?|h|minutes?|mins?|m|seconds?|secs?|s)"#
        guard let expression = try? NSRegularExpression(pattern: pattern) else { return nil }
        var total = 0.0
        var found = false
        for match in expression.matches(in: lowered, range: NSRange(lowered.startIndex..., in: lowered)) {
            guard let number = Range(match.range(at: 1), in: lowered).flatMap({ Double(lowered[$0]) }),
                  let unit = Range(match.range(at: 2), in: lowered).map({ lowered[$0] }) else { continue }
            found = true
            switch unit.first {
            case "d": total += number * 1440
            case "h": total += number * 60
            case "s": total += number / 60
            default: total += number
            }
        }
        return found && total > 0 ? Int(total.rounded()) : nil
    }

    static func renderNotes(_ notes: [MealieObject]) -> String {
        notes.compactMap { note -> String? in
            let text = note.string("text")?.trimmed ?? ""
            let title = note.string("title")?.trimmed ?? ""
            if title.isEmpty || title == notesTitle { return text.nonEmpty }
            return text.isEmpty ? title : "\(title)\n\(text)"
        }.joined(separator: "\n\n")
    }

    /// Moves values that belong to a step onto the same step's text after the list changed; steps that are new get none.
    static func carry<Value>(from old: [String], values: [Value?], to new: [String]) -> [Value?] {
        guard !values.isEmpty else { return [] }
        var used = Set<Int>()
        return new.map { text in
            guard let index = old.indices.first(where: { !used.contains($0) && old[$0] == text }) else { return nil }
            used.insert(index)
            return values.indices.contains(index) ? values[index] : nil
        }
    }

    // MARK: - App to Mealie

    /// Which of the recipe's tags go in Mealie's categories (the ones the remote recipe already files there) and which in tags.
    static func labels(for recipe: Recipe, remote: MealieObject) -> (tags: [String], categories: [String]) {
        let categoryNames = Set(remote.objects("recipeCategory").compactMap { $0.string("name").map(CategoryTree.normalized)?.lowercased() })
        var tags: [String] = [], categories: [String] = []
        var seen = Set<String>()
        for tag in recipe.tags.map(CategoryTree.normalized) where !tag.isEmpty && seen.insert(tag.lowercased()).inserted {
            if categoryNames.contains(tag.lowercased()) { categories.append(tag) } else { tags.append(tag) }
        }
        return (tags, categories)
    }

    /// The recipe's body for `PUT`, starting from what Mealie has. `tags` and `categories` are Mealie's own objects for the names in `labels(for:)`.
    static func body(for recipe: Recipe, patching remote: MealieObject, tags: [MealieObject], categories: [MealieObject]) -> MealieObject {
        var body = remote
        body["name"] = recipe.title
        body["description"] = recipe.summary
        body["orgURL"] = recipe.sourceURL ?? NSNull()
        body["tags"] = tags
        body["recipeCategory"] = categories

        if recipe.servings != servings(in: remote) {
            let value = Double(recipe.servings ?? 0)
            body["recipeServings"] = value
            body["recipeYieldQuantity"] = value
        }
        if recipe.prepMinutes != minutes(in: remote, seconds: "prepTimeSeconds", text: "prepTime") {
            setDuration(&body, text: "prepTime", seconds: "prepTimeSeconds", minutes: recipe.prepMinutes)
        }
        if recipe.cookMinutes != minutes(in: remote, seconds: "performTimeSeconds", text: "performTime") ?? minutes(in: remote, seconds: nil, text: "cookTime") {
            setDuration(&body, text: "performTime", seconds: "performTimeSeconds", minutes: recipe.cookMinutes)
            body["cookTime"] = NSNull()
        }

        body["recipeIngredient"] = ingredients(for: recipe, existing: remote.objects("recipeIngredient"))
        body["recipeInstructions"] = steps(for: recipe, existing: remote.objects("recipeInstructions"))

        if renderNotes(remote.objects("notes")) != recipe.notes {
            body["notes"] = recipe.notes.isEmpty ? [] : [["title": notesTitle, "text": recipe.notes]]
        }

        var extras = remote["extras"] as? MealieObject ?? [:]
        let local = LocalExtras(id: recipe.id, stepTimestamps: recipe.stepTimestamps, wantToCook: recipe.wantToCook, queuedAt: recipe.queuedAt, imageURL: recipe.imageURL)
        extras[extrasKey] = (try? extrasEncoder.encode(local)).map { String(decoding: $0, as: UTF8.self) }
        body["extras"] = extras
        return body
    }

    static func ingredients(for recipe: Recipe, existing: [MealieObject]) -> [MealieObject] {
        var available = existing.map { (text: ingredientText($0), object: $0) }
        let titles = Dictionary(recipe.ingredientSections.map { ($0.start, $0.title) }, uniquingKeysWith: { $1 })
        return recipe.ingredients.enumerated().map { index, text in
            var object: MealieObject
            if let match = available.firstIndex(where: { $0.text == text }) {
                object = available.remove(at: match).object
            } else {
                object = ["note": text, "display": text, "originalText": text, "quantity": 0, "unit": NSNull(), "food": NSNull(), "referencedRecipe": NSNull(), "substitutions": []]
            }
            object["title"] = titles[index] ?? NSNull()
            return object
        }
    }

    static func steps(for recipe: Recipe, existing: [MealieObject]) -> [MealieObject] {
        var available = existing
        return recipe.steps.map { text in
            if let match = available.firstIndex(where: { $0.string("text")?.trimmed == text }) { return available.remove(at: match) }
            return ["title": "", "text": text]
        }
    }

    private static func setDuration(_ body: inout MealieObject, text: String, seconds: String, minutes: Int?) {
        guard let minutes else {
            body[text] = NSNull()
            body[seconds] = NSNull()
            return
        }
        body[text] = minutes == 1 ? "1 minute" : "\(minutes) minutes"
        body[seconds] = minutes * 60
    }

    /// The fields that cross to Mealie, so two recipes can be compared without their timestamps or local-only photo ids.
    static func fingerprint(_ recipe: Recipe) -> String {
        let sections = recipe.ingredientSections.map { "\($0.start)=\($0.title)" }
        let tags = recipe.tags.map { CategoryTree.normalized($0).lowercased() }.sorted()
        let fields: [String] = [
            recipe.title, recipe.summary, recipe.servings.map(String.init) ?? "", recipe.prepMinutes.map(String.init) ?? "",
            recipe.cookMinutes.map(String.init) ?? "", recipe.ingredients.joined(separator: "\n"), sections.joined(separator: "\n"),
            recipe.steps.joined(separator: "\n"), tags.joined(separator: "\n"), recipe.sourceURL ?? "", recipe.notes,
            recipe.rating.map(String.init) ?? "", String(recipe.isFavorite),
        ]
        return fields.joined(separator: "\u{1F}")
    }

    private static let extrasEncoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()

    private static let extrasDecoder = RecipeCoding.makeDecoder()
}

extension String {
    var trimmed: String { trimmingCharacters(in: .whitespacesAndNewlines) }
    var nonEmpty: String? { isEmpty ? nil : self }
}

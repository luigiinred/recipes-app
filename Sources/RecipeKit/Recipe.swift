import Foundation

public struct Recipe: Codable, Identifiable, Hashable, Sendable {
    public var id: UUID
    public var title: String
    public var summary: String
    public var servings: Int?
    public var prepMinutes: Int?
    public var cookMinutes: Int?
    public var ingredients: [String]
    public var steps: [String]
    public var tags: [String]
    public var sourceURL: String?
    public var notes: String
    public var createdAt: Date
    public var updatedAt: Date

    public init(
        id: UUID = UUID(),
        title: String,
        summary: String = "",
        servings: Int? = nil,
        prepMinutes: Int? = nil,
        cookMinutes: Int? = nil,
        ingredients: [String] = [],
        steps: [String] = [],
        tags: [String] = [],
        sourceURL: String? = nil,
        notes: String = "",
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.summary = summary
        self.servings = servings
        self.prepMinutes = prepMinutes
        self.cookMinutes = cookMinutes
        self.ingredients = ingredients
        self.steps = steps
        self.tags = tags
        self.sourceURL = sourceURL
        self.notes = notes
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let now = Date()
        id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        title = try c.decode(String.self, forKey: .title)
        summary = try c.decodeIfPresent(String.self, forKey: .summary) ?? ""
        servings = try c.decodeIfPresent(Int.self, forKey: .servings)
        prepMinutes = try c.decodeIfPresent(Int.self, forKey: .prepMinutes)
        cookMinutes = try c.decodeIfPresent(Int.self, forKey: .cookMinutes)
        ingredients = try c.decodeIfPresent([String].self, forKey: .ingredients) ?? []
        steps = try c.decodeIfPresent([String].self, forKey: .steps) ?? []
        tags = try c.decodeIfPresent([String].self, forKey: .tags) ?? []
        sourceURL = try c.decodeIfPresent(String.self, forKey: .sourceURL)
        notes = try c.decodeIfPresent(String.self, forKey: .notes) ?? ""
        createdAt = try c.decodeIfPresent(Date.self, forKey: .createdAt) ?? now
        updatedAt = try c.decodeIfPresent(Date.self, forKey: .updatedAt) ?? now
    }

    public var totalMinutes: Int? {
        guard prepMinutes != nil || cookMinutes != nil else { return nil }
        return (prepMinutes ?? 0) + (cookMinutes ?? 0)
    }

    public var markdown: String {
        var lines = ["# \(title)"]
        if !summary.isEmpty { lines += ["", summary] }
        var facts: [String] = []
        if let servings { facts.append("Servings: \(servings)") }
        if let prepMinutes { facts.append("Prep: \(prepMinutes) min") }
        if let cookMinutes { facts.append("Cook: \(cookMinutes) min") }
        if !facts.isEmpty { lines += ["", facts.joined(separator: " · ")] }
        if !tags.isEmpty { lines += ["", "Tags: " + tags.joined(separator: ", ")] }
        if !ingredients.isEmpty {
            lines += ["", "## Ingredients", ""] + ingredients.map { "- \($0)" }
        }
        if !steps.isEmpty {
            lines += ["", "## Steps", ""] + steps.enumerated().map { "\($0.offset + 1). \($0.element)" }
        }
        if !notes.isEmpty { lines += ["", "## Notes", "", notes] }
        if let sourceURL, !sourceURL.isEmpty { lines += ["", "Source: \(sourceURL)"] }
        return lines.joined(separator: "\n")
    }

    public func matches(_ query: String) -> Bool {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if q.isEmpty { return true }
        let haystack = ([title, summary, notes] + ingredients + tags).joined(separator: "\n")
        return q.split(separator: " ").allSatisfy { haystack.localizedCaseInsensitiveContains($0) }
    }
}

public enum RecipeCoding {
    public static func makeEncoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }

    public static func makeDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let string = try decoder.singleValueContainer().decode(String.self)
            let plain = ISO8601DateFormatter()
            let fractional = ISO8601DateFormatter()
            fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = plain.date(from: string) ?? fractional.date(from: string) { return date }
            throw DecodingError.dataCorrupted(
                .init(codingPath: decoder.codingPath, debugDescription: "Invalid ISO 8601 date: \(string)")
            )
        }
        return decoder
    }
}

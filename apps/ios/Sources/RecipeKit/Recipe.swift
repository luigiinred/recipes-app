import Foundation

/// A heading in the ingredient list: it applies from the ingredient at `start` up to the next section.
public struct IngredientSection: Codable, Hashable, Sendable {
    public var title: String
    public var start: Int

    public init(title: String, start: Int) {
        self.title = title
        self.start = start
    }
}

/// One entry in a recipe's timeline: a time you cooked it, with an optional note about how it went.
public struct TimelineEvent: Codable, Identifiable, Hashable, Sendable {
    public var id: UUID
    public var date: Date
    public var note: String

    public init(id: UUID = UUID(), date: Date = Date(), note: String = "") {
        self.id = id
        self.date = date
        self.note = note
    }
}

public struct Recipe: Codable, Identifiable, Hashable, Sendable {
    public var id: UUID
    public var title: String
    public var summary: String
    public var servings: Int?
    public var prepMinutes: Int?
    public var cookMinutes: Int?
    public var ingredients: [String]
    /// Optional headings such as "For the sauce"; `ingredients` stays one flat list.
    public var ingredientSections: [IngredientSection]
    public var steps: [String]
    /// Seconds into the source video where each step starts; parallel to `steps`.
    public var stepTimestamps: [Int?]
    /// Photo for each step, parallel to `steps`; the files live in the library's step image store.
    public var stepImages: [UUID?]
    public var tags: [String]
    public var sourceURL: String?
    public var imageURL: String?
    public var notes: String
    public var isFavorite: Bool
    /// One to five stars, or nil when unrated.
    public var rating: Int?
    /// In the planner's Up Next queue; cleared when the recipe is planned or cooked.
    public var wantToCook: Bool
    /// When the recipe joined the queue, so the queue stays in the order things were added.
    public var queuedAt: Date?
    /// The times the recipe was cooked, in the order they were logged.
    public var timeline: [TimelineEvent]
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
        ingredientSections: [IngredientSection] = [],
        steps: [String] = [],
        stepTimestamps: [Int?] = [],
        stepImages: [UUID?] = [],
        tags: [String] = [],
        sourceURL: String? = nil,
        imageURL: String? = nil,
        notes: String = "",
        isFavorite: Bool = false,
        rating: Int? = nil,
        wantToCook: Bool = false,
        queuedAt: Date? = nil,
        timeline: [TimelineEvent] = [],
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
        self.ingredientSections = ingredientSections
        self.steps = steps
        self.stepTimestamps = stepTimestamps
        self.stepImages = stepImages
        self.tags = tags
        self.sourceURL = sourceURL
        self.imageURL = imageURL
        self.notes = notes
        self.isFavorite = isFavorite
        self.rating = rating
        self.wantToCook = wantToCook
        self.queuedAt = queuedAt
        self.timeline = timeline
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
        ingredientSections = try c.decodeIfPresent([IngredientSection].self, forKey: .ingredientSections) ?? []
        steps = try c.decodeIfPresent([String].self, forKey: .steps) ?? []
        stepTimestamps = try c.decodeIfPresent([Int?].self, forKey: .stepTimestamps) ?? []
        stepImages = try c.decodeIfPresent([UUID?].self, forKey: .stepImages) ?? []
        tags = try c.decodeIfPresent([String].self, forKey: .tags) ?? []
        sourceURL = try c.decodeIfPresent(String.self, forKey: .sourceURL)
        imageURL = try c.decodeIfPresent(String.self, forKey: .imageURL)
        notes = try c.decodeIfPresent(String.self, forKey: .notes) ?? ""
        isFavorite = try c.decodeIfPresent(Bool.self, forKey: .isFavorite) ?? false
        rating = try c.decodeIfPresent(Int.self, forKey: .rating)
        wantToCook = try c.decodeIfPresent(Bool.self, forKey: .wantToCook) ?? false
        queuedAt = try c.decodeIfPresent(Date.self, forKey: .queuedAt)
        timeline = try c.decodeIfPresent([TimelineEvent].self, forKey: .timeline) ?? []
        createdAt = try c.decodeIfPresent(Date.self, forKey: .createdAt) ?? now
        updatedAt = try c.decodeIfPresent(Date.self, forKey: .updatedAt) ?? now
    }

    /// The most recent time the recipe was cooked.
    public var lastMade: Date? { timeline.map(\.date).max() }

    public func timestamp(forStep index: Int) -> Int? {
        stepTimestamps.indices.contains(index) ? stepTimestamps[index] : nil
    }

    /// The ingredients in display order, each group with its heading (nil before the first heading).
    public var ingredientGroups: [(title: String?, items: [(index: Int, text: String)])] {
        let starts = ingredientSections.sorted { $0.start < $1.start }
        var groups: [(title: String?, items: [(index: Int, text: String)])] = []
        var boundaries = starts.map(\.start)
        if boundaries.first != 0 { boundaries.insert(0, at: 0) }
        for (position, begin) in boundaries.enumerated() {
            let end = position + 1 < boundaries.count ? boundaries[position + 1] : ingredients.count
            guard begin < end, begin >= 0, end <= ingredients.count else { continue }
            let title = starts.last { $0.start == begin }?.title
            groups.append((title, (begin..<end).map { ($0, ingredients[$0]) }))
        }
        return groups
    }

    public func stepImage(forStep index: Int) -> UUID? {
        stepImages.indices.contains(index) ? stepImages[index] : nil
    }

    public var youTubeVideoID: String? {
        sourceURL.flatMap(URL.init(string:)).flatMap(YouTubeImporter.videoID(from:))
    }

    public var totalMinutes: Int? {
        guard prepMinutes != nil || cookMinutes != nil else { return nil }
        return (prepMinutes ?? 0) + (cookMinutes ?? 0)
    }

    /// Something to cook that has no recipe yet, like "Spaghetti" or "Leftovers": a title and maybe notes.
    public var isIdea: Bool { ingredients.isEmpty && steps.isEmpty }

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
            lines += ["", "## Ingredients"]
            for group in ingredientGroups {
                lines += [""]
                if let title = group.title { lines += ["### \(title)", ""] }
                lines += group.items.map { "- \($0.text)" }
            }
        }
        if !steps.isEmpty {
            lines += ["", "## Steps", ""] + steps.enumerated().map { index, step in
                guard let seconds = timestamp(forStep: index), let id = youTubeVideoID else { return "\(index + 1). \(step)" }
                return "\(index + 1). \(step) [▶ \(Self.clock(seconds))](https://youtu.be/\(id)?t=\(seconds))"
            }
        }
        if !notes.isEmpty { lines += ["", "## Notes", "", notes] }
        if let sourceURL, !sourceURL.isEmpty { lines += ["", "Source: \(sourceURL)"] }
        return lines.joined(separator: "\n")
    }

    public static func clock(_ seconds: Int) -> String {
        let h = seconds / 3600, m = (seconds % 3600) / 60, s = seconds % 60
        return h > 0 ? String(format: "%d:%02d:%02d", h, m, s) : String(format: "%d:%02d", m, s)
    }

    public static func seconds(fromClock text: String) -> Int? {
        let parts = text.split(separator: ":").map { Int($0.trimmingCharacters(in: .whitespaces)) }
        guard !parts.isEmpty, parts.count <= 3, !parts.contains(where: { $0 == nil }) else { return nil }
        return parts.compactMap { $0 }.reduce(0) { $0 * 60 + $1 }
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

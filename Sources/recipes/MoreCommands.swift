import ArgumentParser
import Foundation
import RecipeKit

struct Mark: ParsableCommand {
    static let configuration = CommandConfiguration(abstract: "Mark a recipe as favorite, rate it, or add it to the Up Next queue.")
    @OptionGroup var library: LibraryOptions
    @Argument(help: "Recipe id, id prefix, or title.") var recipe: String
    @Option(name: .long, help: "true or false.") var favorite: Bool?
    @Option(name: .long, help: "true or false: in the Up Next queue.") var wantToCook: Bool?
    @Option(name: .long, help: "Stars from 1 to 5, or 0 to clear.") var rating: Int?

    func run() throws {
        var found = try library.store.find(recipe)
        if let favorite { found.isFavorite = favorite }
        if let wantToCook {
            if wantToCook, !found.wantToCook { found.queuedAt = Date() }
            found.wantToCook = wantToCook
        }
        if let rating {
            guard (0...5).contains(rating) else { throw ValidationError("The rating must be 0 to 5.") }
            found.rating = rating == 0 ? nil : rating
        }
        let saved = try library.store.save(found)
        print("\(saved.title): favorite=\(saved.isFavorite) rating=\(saved.rating.map(String.init) ?? "none") up-next=\(saved.wantToCook)")
    }
}

struct Export: ParsableCommand {
    static let configuration = CommandConfiguration(abstract: "Export every recipe, photo, meal, grocery item, and feed as one JSON document.")
    @OptionGroup var library: LibraryOptions
    @Option(name: .shortAndLong, help: "Write to this file instead of standard output.") var output: String?

    func run() throws {
        let data = try library.library.export().jsonData()
        guard let output else {
            print(String(decoding: data, as: UTF8.self))
            return
        }
        let url = URL(fileURLWithPath: (output as NSString).expandingTildeInPath)
        try data.write(to: url, options: .atomic)
        print("Exported to \(url.path)")
    }
}

struct Sections: AsyncParsableCommand {
    static let configuration = CommandConfiguration(abstract: "Group a recipe's ingredients into sections (Dough, Sauce...) with the on-device model.")
    @OptionGroup var library: LibraryOptions
    @Argument(help: "Recipe id, id prefix, or title.") var recipe: String
    @Flag(name: .long, help: "Save the grouping to the recipe.") var save = false

    func run() async throws {
        var found = try library.store.find(recipe)
        switch await IngredientGrouper.group(title: found.title, ingredients: found.ingredients, steps: found.steps) {
        case .grouped(let ingredients, let sections):
            found.ingredients = ingredients
            found.ingredientSections = sections
            print(found.markdown.components(separatedBy: "## Steps").first ?? "")
            if save { _ = try library.store.save(found); print("Saved.") }
        case .unchanged: print("These ingredients belong together; no sections added.")
        case .unavailable(let status): throw ValidationError(status.explanation)
        case .failed(let reason): throw ValidationError(reason)
        }
    }
}

struct AICheck: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "ai-check",
        abstract: "Report whether Apple Intelligence is ready and try the recipe-writing model on sample captions."
    )

    func run() async throws {
        let status = AppleIntelligence.status
        print("Apple Intelligence: \(status.isAvailable ? "available" : "not available") - \(status.explanation)")
        guard status.isAvailable else { return }
        let short = "Today we're making a simple tomato pasta. Boil two hundred grams of spaghetti in salted water. Meanwhile warm two tablespoons of olive oil, add two cloves of minced garlic and a can of crushed tomatoes and simmer for ten minutes. Toss the pasta with the sauce and finish with a handful of basil."
        let long = String(repeating: short + " ", count: 120)
        for (name, text) in [("short captions", short), ("very long captions", long)] {
            let started = Date()
            switch await TranscriptRecipeExtractor.run(title: "Tomato Pasta", transcript: text) {
            case .extracted(let recipe):
                print("\(name): ok in \(String(format: "%.1f", Date().timeIntervalSince(started)))s - \(recipe.ingredients.count) ingredients, \(recipe.steps.count) steps")
                if name == "short captions" { recipe.ingredients.forEach { print("  \($0)") } }
            case .unavailable(let status):
                print("\(name): unavailable - \(status.explanation)")
            case .failed(let reason):
                print("\(name): failed - \(reason)")
            }
        }
    }
}

struct Scan: ParsableCommand {
    static let configuration = CommandConfiguration(abstract: "Read a recipe from a photo or PDF using text recognition.")
    @OptionGroup var library: LibraryOptions
    @Argument(help: "Image or PDF file.") var file: String
    @Flag(name: .long, help: "Save the recipe to the library.") var save = false
    @Flag(name: .long, help: "Output as JSON.") var json = false

    func run() throws {
        let url = URL(fileURLWithPath: (file as NSString).expandingTildeInPath)
        var (recipe, _) = try RecipeScanner.recipe(fromImageAt: url)
        if save { recipe = try library.store.save(recipe) }
        if json { try printJSON(recipe) } else { print(recipe.markdown) }
    }
}

struct FeedsCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "feeds",
        abstract: "Subscribe to recipe blogs and read their latest posts.",
        subcommands: [FeedList.self, FeedAdd.self, FeedRemove.self, FeedEntries.self],
        defaultSubcommand: FeedList.self
    )
}

private func matchFeed(_ feeds: [Feed], _ query: String) throws -> Feed {
    let lowered = query.lowercased()
    let matches = feeds.filter { $0.id.uuidString.lowercased().hasPrefix(lowered) || $0.title.localizedCaseInsensitiveContains(query) }
    guard let first = matches.first else { throw RecipeError.notFound(query) }
    guard matches.count == 1 else {
        throw RecipeError.ambiguous(query, matches.map { "\($0.id.uuidString.prefix(8).lowercased())  \($0.title)" })
    }
    return first
}

struct FeedList: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "list", abstract: "List subscribed feeds.")
    @OptionGroup var library: LibraryOptions
    @Flag(name: .long) var json = false

    func run() throws {
        let feeds = try library.library.feeds.list().sorted { $0.createdAt < $1.createdAt }
        if json { try printJSON(feeds); return }
        if feeds.isEmpty { print("No feeds."); return }
        for feed in feeds { print("\(feed.id.uuidString.prefix(8).lowercased())  \(feed.title)  \(feed.url)") }
    }
}

struct FeedAdd: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "add", abstract: "Subscribe to a feed or a site that has one.")
    @OptionGroup var library: LibraryOptions
    @Argument(help: "Feed or site URL.") var url: String

    func run() async throws {
        guard let parsed = URL(string: url), parsed.scheme?.hasPrefix("http") == true else {
            throw ValidationError("Not a web URL: \(url)")
        }
        let found = try await FeedService.discover(from: parsed)
        try library.library.feeds.save(Feed(url: found.url.absoluteString, title: found.title))
        print("Subscribed to \(found.title)")
    }
}

struct FeedRemove: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "remove", abstract: "Unsubscribe by id or title.")
    @OptionGroup var library: LibraryOptions
    @Argument var feed: String

    func run() throws {
        let store = library.library.feeds
        let found = try matchFeed(try store.list(), feed)
        try store.delete(found)
        print("Unsubscribed from \(found.title)")
    }
}

struct FeedEntries: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "entries",
        abstract: "Show the latest posts of a feed. Import one with `recipes import <link>`."
    )
    @OptionGroup var library: LibraryOptions
    @Argument var feed: String
    @Option(name: .long) var limit = 20

    func run() async throws {
        let found = try matchFeed(try library.library.feeds.list(), feed)
        guard let url = URL(string: found.url) else { throw ValidationError("Bad feed URL.") }
        let result = try await FeedService.fetch(url)
        for entry in result.entries.prefix(limit) {
            let date = entry.published.map { $0.formatted(.iso8601.year().month().day()) } ?? "          "
            print("\(date)  \(entry.title)\n            \(entry.link.absoluteString)")
        }
    }
}

struct Transcript: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Print the spoken captions of a YouTube video, so you can write the recipe yourself.",
        discussion: "Use this when `recipes import` can't find a recipe in the description. Then run `recipes add --from -` with the recipe as JSON."
    )
    @Argument(help: "YouTube URL.") var url: String
    @Flag(name: .long, help: "Also print the title and description.") var withDescription = false

    func run() async throws {
        guard let parsed = URL(string: url), let id = YouTubeImporter.videoID(from: parsed) else {
            throw ValidationError("Not a YouTube video link: \(url)")
        }
        if withDescription {
            let video = try await YouTubeImporter.fetchVideo(id: id)
            print("# \(video.title)\n\(video.channel)\n\n## Description\n\(YouTubeImporter.cleanDescription(video.description))\n\n## Captions")
            print(video.transcript ?? "(no captions available)")
        } else {
            guard let text = await YouTubeImporter.fetchTranscript(id: id) else {
                throw ValidationError("This video has no captions available.")
            }
            print(text)
        }
    }
}

struct Timestamps: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Find where each step is spoken in a YouTube recipe's video and save the timestamps."
    )
    @OptionGroup var library: LibraryOptions
    @Argument(help: "Recipe id, id prefix, or title.") var recipe: String

    func run() async throws {
        var found = try library.store.find(recipe)
        guard found.youTubeVideoID != nil else { throw ValidationError("\(found.title) wasn't imported from a YouTube video.") }
        guard let times = await YouTubeImporter.timestamps(for: found) else {
            throw ValidationError("Couldn't get captions for that video.")
        }
        found.stepTimestamps = times
        _ = try library.store.save(found)
        for (index, step) in found.steps.enumerated() {
            let label = times[index].map { Recipe.clock($0) } ?? "  –  "
            print("\(label.padding(toLength: 7, withPad: " ", startingAt: 0)) \(index + 1). \(step.prefix(70))")
        }
    }
}

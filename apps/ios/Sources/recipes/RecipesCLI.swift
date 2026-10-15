import ArgumentParser
import Foundation
import RecipeKit

@main
struct RecipesCLI: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "recipes",
        abstract: "Read and create recipes in the Recipes app library.",
        discussion: """
        The library is the iCloud Drive folder the Recipes app syncs between Mac and iPhone. \
        Override it with --dir or RECIPES_DIR, and use `recipes sync` to mirror it with a self-hosted server. \
        Run `recipes schema` for the JSON format.
        """,
        subcommands: [List.self, Show.self, Search.self, Add.self, Import.self, Transcript.self, Timestamps.self, Image.self, PlanCommand.self, GroceriesCommand.self, FeedsCommand.self, Scan.self, Mark.self, Delete.self, Export.self, Sections.self, AICheck.self, SyncCommand.self, Path.self, Schema.self]
    )
}

struct LibraryOptions: ParsableArguments {
    @Option(name: .long, help: "Library folder to use instead of the iCloud library.")
    var dir: String?

    var resolved: RecipeLocation.Resolved {
        RecipeLocation.resolveForCLI(override: dir, environment: ProcessInfo.processInfo.environment)
    }

    var library: Library { resolved.library }
    var store: RecipeStore { library.recipes }
}

func printJSON<T: Encodable>(_ value: T) throws {
    let data = try RecipeCoding.makeEncoder().encode(value)
    print(String(decoding: data, as: UTF8.self))
}

func shortID(_ recipe: Recipe) -> String {
    String(recipe.id.uuidString.prefix(8)).lowercased()
}

func printTable(_ recipes: [Recipe]) {
    if recipes.isEmpty {
        print("No recipes.")
        return
    }
    for recipe in recipes {
        let tags = recipe.tags.isEmpty ? "" : "  [\(recipe.tags.joined(separator: ", "))]"
        print("\(shortID(recipe))  \(recipe.title)\(tags)")
    }
}

struct List: ParsableCommand {
    static let configuration = CommandConfiguration(abstract: "List all recipes.")
    @OptionGroup var library: LibraryOptions
    @Option(name: .long, help: "Only recipes with this tag.") var tag: String?
    @Option(name: .long, help: "One of: recent, up-next, favorites, top-rated, uncategorized.") var collection: String?
    @Flag(name: .long, help: "Output full recipes as JSON.") var json = false

    func run() throws {
        var recipes = try library.store.list()
        if let collection {
            switch collection {
            case "recent": recipes = RecipeCollection.recent.filter(recipes)
            case "want-to-cook", "up-next": recipes = RecipeCollection.wantToCook.filter(recipes)
            case "top-rated": recipes = RecipeCollection.topRated.filter(recipes)
            case "favorites": recipes = RecipeCollection.favorites.filter(recipes)
            case "uncategorized": recipes = RecipeCollection.uncategorized.filter(recipes)
            default: throw ValidationError("Unknown collection \"\(collection)\".")
            }
        }
        if let tag { recipes = recipes.filter { $0.tags.contains { $0.caseInsensitiveCompare(tag) == .orderedSame } } }
        if json { try printJSON(recipes) } else { printTable(recipes) }
    }
}

struct Show: ParsableCommand {
    static let configuration = CommandConfiguration(abstract: "Show one recipe by id, id prefix, or title.")
    @OptionGroup var library: LibraryOptions
    @Argument(help: "Recipe id, id prefix, or title.") var recipe: String
    @Flag(name: .long, help: "Output the recipe as JSON.") var json = false

    func run() throws {
        let found = try library.store.find(recipe)
        if json { try printJSON(found) } else { print(found.markdown) }
    }
}

struct Search: ParsableCommand {
    static let configuration = CommandConfiguration(abstract: "Search titles, ingredients, tags, and notes.")
    @OptionGroup var library: LibraryOptions
    @Argument(help: "Words that must all appear.") var query: [String]
    @Flag(name: .long, help: "Output full recipes as JSON.") var json = false

    func run() throws {
        let q = query.joined(separator: " ")
        let recipes = try library.store.list().filter { $0.matches(q) }
        if json { try printJSON(recipes) } else { printTable(recipes) }
    }
}

struct Add: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Add a recipe from flags or JSON.",
        discussion: "With --from, a recipe whose id already exists is replaced, so this also edits recipes."
    )
    @OptionGroup var library: LibraryOptions
    @Option(name: .long, help: "Read recipe JSON (one object or an array) from a file, or - for stdin.")
    var from: String?
    @Option(name: .long) var title: String?
    @Option(name: .long) var summary: String?
    @Option(name: .long) var servings: Int?
    @Option(name: .long) var prep: Int?
    @Option(name: .long) var cook: Int?
    @Option(name: .long, help: "Repeat for each ingredient.") var ingredient: [String] = []
    @Option(name: .long, help: "Repeat for each step, in order.") var step: [String] = []
    @Option(name: .long, help: "Repeat for each tag.") var tag: [String] = []
    @Option(name: .long) var source: String?
    @Option(name: .long) var notes: String?
    @Option(name: .long, help: "Photo: image file path.") var image: String?
    @Flag(name: .long, help: "Output the saved recipes as JSON.") var json = false

    func run() throws {
        let store = library.store
        var recipes: [Recipe]
        if let from {
            let data = from == "-"
                ? FileHandle.standardInput.readDataToEndOfFile()
                : try Data(contentsOf: URL(fileURLWithPath: (from as NSString).expandingTildeInPath))
            let decoder = RecipeCoding.makeDecoder()
            if let many = try? decoder.decode([Recipe].self, from: data) {
                recipes = many
            } else {
                recipes = [try decoder.decode(Recipe.self, from: data)]
            }
        } else {
            guard let title else { throw ValidationError("Provide --title or --from.") }
            recipes = [Recipe(
                title: title, summary: summary ?? "", servings: servings, prepMinutes: prep, cookMinutes: cook,
                ingredients: ingredient, steps: step, tags: tag, sourceURL: source, notes: notes ?? ""
            )]
        }
        let saved = try recipes.map { try store.save($0) }
        if let image {
            guard saved.count == 1 else { throw ValidationError("--image works with a single recipe.") }
            let raw = try Data(contentsOf: URL(fileURLWithPath: (image as NSString).expandingTildeInPath))
            guard let jpeg = RecipeImageProcessing.jpegData(from: raw) else { throw ValidationError("That isn't a readable image.") }
            try library.library.images.save(jpeg, for: saved[0].id)
        }
        if json {
            try printJSON(saved)
        } else {
            for recipe in saved { print("Saved \(shortID(recipe))  \(recipe.title)") }
        }
        warnIfLocal()
    }

    private func warnIfLocal() {
        let location = library.resolved
        guard !location.isICloud, library.dir == nil, ProcessInfo.processInfo.environment["RECIPES_DIR"] == nil else { return }
        FileHandle.standardError.write(Data(
            "note: iCloud library not found; saved to \(location.root.path). Open the Recipes app once to enable sync.\n".utf8
        ))
    }
}

struct Import: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Import a recipe from a web page or a YouTube video.",
        discussion: "Web pages need schema.org recipe data. YouTube videos need the recipe in the description, or captions the on-device model can read."
    )
    @OptionGroup var library: LibraryOptions
    @Argument(help: "Recipe page or YouTube URL.") var url: String
    @Flag(name: .long, help: "Output the saved recipe as JSON.") var json = false

    func run() async throws {
        guard let parsed = URL(string: url), parsed.scheme?.hasPrefix("http") == true else {
            throw ValidationError("Not a web URL: \(url)")
        }
        let result = try await RecipeImporter.importResult(from: parsed)
        let saved = try library.library.add(result)
        if json { try printJSON(saved) } else { print("Saved \(shortID(saved))  \(saved.title)") }
        if let message = result.message {
            FileHandle.standardError.write(Data("warning: \(message)\n".utf8))
        }
    }
}

struct Image: ParsableCommand {
    static let configuration = CommandConfiguration(abstract: "Set a recipe's photo from an image file or URL.")
    @OptionGroup var library: LibraryOptions
    @Argument(help: "Recipe id, id prefix, or title.") var recipe: String
    @Argument(help: "Image file path or http(s) URL.") var source: String

    func run() async throws {
        let found = try library.store.find(recipe)
        let raw: Data
        if source.hasPrefix("http") {
            guard let data = await RecipeImageProcessing.download(source) else { throw ValidationError("Couldn't download that image.") }
            raw = data
        } else {
            raw = try Data(contentsOf: URL(fileURLWithPath: (source as NSString).expandingTildeInPath))
        }
        guard let jpeg = RecipeImageProcessing.jpegData(from: raw) else { throw ValidationError("That isn't a readable image.") }
        try library.library.images.save(jpeg, for: found.id)
        print("Set photo for \(found.title)")
    }
}

struct Delete: ParsableCommand {
    static let configuration = CommandConfiguration(abstract: "Delete a recipe by id, id prefix, or title.")
    @OptionGroup var library: LibraryOptions
    @Argument(help: "Recipe id, id prefix, or title.") var recipe: String

    func run() throws {
        let found = try library.store.find(recipe)
        try library.library.deleteRecipe(found)
        print("Deleted \(shortID(found))  \(found.title)")
    }
}

struct Path: ParsableCommand {
    static let configuration = CommandConfiguration(abstract: "Print the library folder (recipes, calendar, and groceries live inside it).")
    @OptionGroup var library: LibraryOptions

    func run() {
        print(library.resolved.root.path)
    }
}

struct Schema: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Print an example recipe in the JSON format `add --from` accepts, and the format rules.",
        discussion: RecipeStandards.rules
    )

    func run() throws {
        let example = Recipe(
            title: "Example Pancakes",
            summary: "Fluffy weekend pancakes.",
            servings: 4,
            prepMinutes: 10,
            cookMinutes: 15,
            ingredients: ["1 1/2 cups flour", "1 cup milk", "1 egg"],
            steps: ["Whisk everything together.", "Cook on a hot griddle until golden."],
            tags: ["Vegetarian", "Breakfast"],
            sourceURL: "https://example.com/pancakes",
            notes: "Only title is required; every other field is optional."
        )
        try printJSON(example)
        print("\n" + RecipeStandards.rules)
    }
}

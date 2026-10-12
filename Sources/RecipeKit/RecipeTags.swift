import Foundation

/// Tags are a short list of generic words: what the dish is mostly made of, whether it's vegetarian, and when you'd eat it.
public enum RecipeTags {
    public struct Group: Identifiable, Sendable {
        public let title: String
        public let tags: [String]
        public var id: String { title }
    }

    public static let groups: [Group] = [
        Group(title: "Main ingredient", tags: ["Beef", "Pork", "Chicken", "Turkey", "Lamb", "Fish", "Seafood", "Eggs", "Pasta", "Rice", "Beans", "Tofu"]),
        Group(title: "Diet", tags: ["Vegetarian", "Vegan"]),
        Group(title: "Course", tags: ["Breakfast", "Lunch", "Dinner", "Appetizer", "Side", "Soup", "Salad", "Dessert", "Snack", "Drink"]),
    ]

    public static let vocabulary: [String] = groups.flatMap(\.tags)

    /// Most tags a recipe gets from an import.
    public static let importLimit = 4

    private static let courses = Set(groups[2].tags)
    private static let meats = Set(["Beef", "Pork", "Chicken", "Turkey", "Lamb", "Fish", "Seafood"])

    /// Words that point at a tag, matched whole-word against a title or an ingredient.
    private static let keywords: [String: [String]] = [
        "Beef": ["beef", "steak", "brisket", "sirloin", "ribeye", "short rib", "short ribs", "meatball", "meatballs", "burger"],
        "Pork": ["pork", "bacon", "ham", "sausage", "sausages", "prosciutto", "pancetta", "chorizo", "carnitas"],
        "Chicken": ["chicken", "drumstick", "drumsticks"],
        "Turkey": ["turkey"],
        "Lamb": ["lamb", "mutton"],
        "Fish": ["fish", "salmon", "cod", "tuna", "trout", "tilapia", "halibut", "haddock", "mackerel", "sardine", "sardines", "anchovy", "anchovies", "snapper", "bass"],
        "Seafood": ["shrimp", "prawn", "prawns", "crab", "lobster", "scallop", "scallops", "mussel", "mussels", "clam", "clams", "squid", "calamari", "oyster", "oysters"],
        "Eggs": ["egg", "eggs", "omelet", "omelette", "frittata", "shakshuka", "quiche"],
        "Pasta": ["pasta", "spaghetti", "penne", "linguine", "fettuccine", "macaroni", "lasagna", "lasagne", "rigatoni", "noodle", "noodles", "ramen", "gnocchi", "orzo"],
        "Rice": ["rice", "risotto", "paella", "biryani", "pilaf"],
        "Beans": ["beans", "bean", "lentil", "lentils", "chickpea", "chickpeas", "dal", "dahl", "hummus"],
        "Tofu": ["tofu", "tempeh", "seitan"],
    ]

    /// Words in a title that point at a course.
    private static let courseKeywords: [String: [String]] = [
        "Breakfast": ["breakfast", "brunch", "pancake", "pancakes", "waffle", "waffles", "granola", "oatmeal", "porridge", "french toast", "muffin", "muffins"],
        "Dessert": ["dessert", "desserts", "cake", "cookie", "cookies", "brownie", "brownies", "pie", "pudding", "ice cream", "cheesecake", "tart", "fudge", "mousse"],
        "Soup": ["soup", "stew", "chowder", "bisque", "chili"],
        "Salad": ["salad", "slaw"],
        "Appetizer": ["appetizer", "appetizers", "starter", "starters", "dip", "hors d'oeuvre"],
        "Side": ["side", "side dish"],
        "Snack": ["snack", "snacks"],
        "Drink": ["drink", "drinks", "cocktail", "smoothie", "beverage", "lemonade"],
        "Lunch": ["lunch", "sandwich", "wrap"],
        "Dinner": ["dinner", "main", "main course", "main dish", "entree", "supper"],
    ]

    /// Ingredients that rule out vegan, but not vegetarian.
    private static let animalProducts = [
        "egg", "eggs", "milk", "butter", "cheese", "cream", "yogurt", "yoghurt", "honey", "ghee", "parmesan", "mozzarella",
        "ricotta", "feta", "mayonnaise", "buttermilk", "gelatin", "whey",
    ]
    /// Words that make "milk", "butter" and the like plant-based: "coconut milk", "peanut butter".
    private static let plantQualifiers = ["coconut", "almond", "oat", "soy", "cashew", "peanut", "cocoa", "plant", "vegan", "nut", "bean", "beans"]
    /// Ingredient lines that mean the dish isn't vegetarian even when no meat is named.
    private static let meatStocks = ["broth", "stock", "bouillon", "lard", "gelatin", "anchovy", "anchovies", "fish sauce", "worcestershire"]

    /// The vocabulary tag for a word or phrase someone wrote, such as "dessert" or "Main Course"; nil when it isn't one.
    public static func canonical(_ text: String) -> String? {
        let key = text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !key.isEmpty else { return nil }
        if let exact = vocabulary.first(where: { $0.lowercased() == key }) { return exact }
        if key.hasSuffix("s"), let exact = vocabulary.first(where: { $0.lowercased() == String(key.dropLast()) }) { return exact }
        for (tag, words) in courseKeywords where words.contains(key) { return tag }
        for (tag, words) in keywords where words.contains(key) { return tag }
        if key == "veggie" || key == "vegetables" { return "Vegetarian" }
        return nil
    }

    /// Generic tags for a recipe: its main ingredient, diet, and course. `sourceTerms` are a web page's own
    /// categories and keywords; they only count when they name one of the generic tags.
    public static func suggest(title: String, ingredients: [String], sourceTerms: [String] = []) -> [String] {
        let titleWords = words(in: title)
        let items = ingredients.map { Ingredient(parsing: $0).item.lowercased() }
        let leading = items.prefix(4)

        var main: [String] = []
        for tag in groups[0].tags {
            guard let words = keywords[tag] else { continue }
            let inTitle = words.contains { contains(titleWords, $0) }
            let inLeading = tag != "Eggs" && leading.contains { item in words.contains { contains(self.words(in: item), $0) } && !isStock(item) }
            if inTitle || inLeading { main.append(tag) }
        }
        // A named protein beats a starch: "Chicken noodle soup" is a chicken dish.
        if main.contains(where: { meats.contains($0) }) {
            main.removeAll { ["Pasta", "Rice", "Eggs", "Beans"].contains($0) }
        }

        var tags = Array(main.prefix(2))

        let everything = items.map { words(in: $0) }
        let hasMeat = keywordTags(meats).contains { words in everything.contains { item in words.contains { contains(item, $0) } } }
            || items.contains { item in meatStocks.contains { item.contains($0) } }
        if !hasMeat, ingredients.count >= 2 {
            let hasAnimal = items.contains { item in
                let itemWords = words(in: item)
                return !plantQualifiers.contains { contains(itemWords, $0) } && animalProducts.contains { contains(itemWords, $0) }
            }
            tags.append(hasAnimal ? "Vegetarian" : "Vegan")
            if !hasAnimal { tags.append("Vegetarian") }
        }

        var course: String?
        for term in sourceTerms {
            if let tag = canonical(term), courses.contains(tag) { course = tag; break }
        }
        if course == nil {
            for tag in courseKeywords.keys.sorted() where courseKeywords[tag]!.contains(where: { contains(titleWords, $0) }) {
                course = tag
                break
            }
        }
        for term in sourceTerms {
            if let tag = canonical(term), !courses.contains(tag), !tags.contains(tag), groups[0].tags.contains(tag) { tags.append(tag) }
        }
        if let course { tags.append(course) }

        var seen = Set<String>()
        return tags.filter { seen.insert($0).inserted }.prefix(importLimit).map { $0 }
    }

    public static func suggest(for recipe: Recipe, sourceTerms: [String] = []) -> [String] {
        suggest(title: recipe.title, ingredients: recipe.ingredients, sourceTerms: sourceTerms)
    }

    /// Writes generic tags in their standard capitalization and drops repeats. Nested categories like "Dinner/Pasta"
    /// and tags that aren't in the vocabulary are kept as written.
    public static func standardized(_ tags: [String]) -> [String] {
        var seen = Set<String>()
        var result: [String] = []
        for raw in tags {
            let normalized = CategoryTree.normalized(raw)
            guard !normalized.isEmpty else { continue }
            let tag = normalized.contains(CategoryTree.separator) ? normalized : (vocabulary.first { $0.caseInsensitiveCompare(normalized) == .orderedSame } ?? normalized)
            if seen.insert(tag.lowercased()).inserted { result.append(tag) }
        }
        return result
    }

    private static func keywordTags(_ tags: Set<String>) -> [[String]] {
        tags.compactMap { keywords[$0] }
    }

    private static func isStock(_ item: String) -> Bool {
        meatStocks.contains { item.contains($0) }
    }

    private static func words(in text: String) -> [String] {
        text.lowercased().split { !$0.isLetter && $0 != "'" }.map(String.init)
    }

    /// Whether the word list contains the keyword, which may be a phrase.
    private static func contains(_ words: [String], _ keyword: String) -> Bool {
        let parts = keyword.split(separator: " ").map(String.init)
        guard let first = parts.first else { return false }
        if parts.count == 1 { return words.contains(first) }
        return words.indices.contains { index in
            index + parts.count <= words.count && Array(words[index..<(index + parts.count)]) == parts
        }
    }
}

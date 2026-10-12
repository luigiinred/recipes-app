import CoreGraphics
import Foundation
import ImageIO
import RecipeKit
import SwiftUI
import UniformTypeIdentifiers

/// Fixed fixtures for SwiftUI previews and snapshot tests.
@MainActor
enum SampleData {
    static let now: Date = Calendar.current.date(from: DateComponents(year: 2026, month: 10, day: 14, hour: 12))!

    private static let created = Date(timeIntervalSince1970: 1_790_000_000)

    static let shakshuka = Recipe(
        id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
        title: "Shakshuka",
        summary: "Eggs poached in a spiced tomato and pepper sauce. Serve with crusty bread.",
        servings: 2, prepMinutes: 10, cookMinutes: 25,
        ingredients: ["2 tbsp olive oil", "1 onion, diced", "1 red bell pepper, sliced", "3 cloves garlic, minced",
                      "1 tsp cumin", "1 tsp smoked paprika", "1 can (400g) crushed tomatoes", "4 eggs", "Fresh parsley, to serve"],
        steps: ["Warm the olive oil in a wide pan over medium heat. Cook the onion and pepper for 8 minutes until soft.",
                "Stir in the garlic, cumin and paprika and cook for 1 minute until fragrant.",
                "Pour in the tomatoes, season well, and simmer for 10 minutes until thickened.",
                "Make four wells in the sauce and crack in the eggs. Cover and cook for 6 minutes until the whites are set.",
                "Scatter with parsley and serve straight from the pan."],
        tags: ["Breakfast", "Eggs"], sourceURL: "https://example.com/shakshuka", isFavorite: true,
        createdAt: created.addingTimeInterval(500), updatedAt: created
    )

    static let chili = Recipe(
        id: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!,
        title: "Smoky Black Bean Chili",
        summary: "Spicy, hearty and healthy. A simple chili that doesn't need any meat.",
        servings: 6, prepMinutes: 15, cookMinutes: 60,
        ingredients: ["500g black beans, dried", "4 cans diced tomatoes", "1 can corn", "4 bell peppers", "1 onion",
                      "2 cloves garlic", "5 tbsp tomato paste", "3 tbsp canola oil", "Vegetable broth", "Salt"],
        steps: ["Soak the beans overnight in plenty of water.",
                "Drain the beans, cover with fresh water and simmer for 45 minutes.",
                "Fry the onion, garlic and peppers in the oil, then stir in the tomato paste.",
                "Add everything to the pot with the tomatoes, corn and broth and simmer for 15 minutes."],
        tags: ["Dinner/Mains"], isFavorite: true, wantToCook: true,
        createdAt: created.addingTimeInterval(400), updatedAt: created
    )

    static let curry = Recipe(
        id: UUID(uuidString: "00000000-0000-0000-0000-000000000003")!,
        title: "Chickpea Curry",
        summary: "Easy weeknight curry from the pantry.",
        servings: 4, prepMinutes: 10, cookMinutes: 25,
        ingredients: ["2 cans chickpeas", "1 can coconut milk", "2 tbsp curry paste", "1 onion", "200g spinach"],
        steps: ["Soften the onion.", "Stir in the curry paste, chickpeas and coconut milk and simmer for 20 minutes.", "Wilt in the spinach."],
        tags: ["Dinner/Mains"], wantToCook: true,
        createdAt: created.addingTimeInterval(300), updatedAt: created
    )

    static let pancakes = Recipe(
        id: UUID(uuidString: "00000000-0000-0000-0000-000000000004")!,
        title: "Lemon Ricotta Pancakes",
        summary: "Light, fluffy weekend pancakes.",
        servings: 4, prepMinutes: 10, cookMinutes: 15,
        ingredients: ["1 cup ricotta", "3 eggs", "1/2 cup flour", "1 lemon, zested", "Butter, for the pan"],
        steps: ["Whisk the ricotta, eggs and lemon zest.", "Fold in the flour.", "Cook on a buttered pan for 3 minutes per side."],
        tags: ["Breakfast"], isFavorite: true,
        createdAt: created.addingTimeInterval(200), updatedAt: created
    )

    static let brownies = Recipe(
        id: UUID(uuidString: "00000000-0000-0000-0000-000000000005")!,
        title: "Fudgy Brownies",
        summary: "Dense, chewy and very chocolatey.",
        servings: 12, prepMinutes: 15, cookMinutes: 30,
        ingredients: ["200g dark chocolate", "150g butter", "3 eggs", "200g sugar", "100g flour"],
        steps: ["Melt the chocolate and butter.", "Beat in the eggs and sugar, then fold in the flour.", "Bake at 180°C for 30 minutes."],
        tags: ["Sweets"], createdAt: created.addingTimeInterval(100), updatedAt: created
    )

    static let soup = Recipe(
        id: UUID(uuidString: "00000000-0000-0000-0000-000000000006")!,
        title: "Roasted Tomato Soup",
        summary: "Comforting and simple.",
        servings: 4, prepMinutes: 10, cookMinutes: 40,
        ingredients: ["1kg tomatoes", "1 onion", "4 cloves garlic", "500ml vegetable broth"],
        steps: ["Roast the vegetables for 30 minutes.", "Blend with the broth and warm through."],
        createdAt: created, updatedAt: created
    )

    static let videoRecipe = Recipe(
        id: UUID(uuidString: "00000000-0000-0000-0000-000000000007")!,
        title: "Easy Weeknight Pasta",
        summary: "From Chef Marco on YouTube.",
        servings: 2, prepMinutes: 5, cookMinutes: 15,
        ingredients: ["200g spaghetti", "2 tbsp butter", "1 clove garlic", "Parmesan, to serve"],
        steps: ["Boil the spaghetti in well-salted water.", "Melt the butter with the garlic.",
                "Toss everything with a splash of pasta water.", "Finish with plenty of Parmesan."],
        stepTimestamps: [32, 75, 118, nil],
        tags: ["Dinner/Pasta", "YouTube"], sourceURL: "https://www.youtube.com/watch?v=dQw4w9WgXcQ",
        createdAt: created.addingTimeInterval(600), updatedAt: created
    )

    static let recipes = [shakshuka, chili, curry, pancakes, brownies, soup, videoRecipe]

    static let mealPlan: [MealPlanEntry] = {
        func entry(_ offset: Int, _ recipe: Recipe, _ meal: Meal) -> MealPlanEntry {
            let day = Calendar.current.date(byAdding: .day, value: offset, to: now)!
            return MealPlanEntry(
                id: UUID(uuidString: String(format: "10000000-0000-0000-0000-%012d", abs(offset) * 10 + meal.order))!,
                recipeID: recipe.id, title: recipe.title, day: DayKey.string(from: day), meal: meal,
                createdAt: created, updatedAt: created
            )
        }
        return [entry(-2, soup, .dinner), entry(-1, curry, .lunch), entry(0, pancakes, .breakfast), entry(0, chili, .dinner),
                entry(1, shakshuka, .lunch), entry(1, curry, .dinner), entry(2, pancakes, .breakfast), entry(2, shakshuka, .dinner),
                entry(3, brownies, .snack), entry(4, soup, .dinner)]
    }()

    static let groceries: [GroceryItem] = {
        var items = chili.ingredients.enumerated().map { index, text -> GroceryItem in
            var item = GroceryItem(parsing: text, recipeID: chili.id)
            item.id = UUID(uuidString: String(format: "20000000-0000-0000-0000-%012d", index))!
            item.createdAt = created.addingTimeInterval(Double(index))
            item.updatedAt = item.createdAt
            item.isChecked = index >= 7
            return item
        }
        items[0].name = "black beans dried"
        return items
    }()

    static let feeds = [
        Feed(id: UUID(uuidString: "30000000-0000-0000-0000-000000000001")!, url: "https://example.com/simply.xml", title: "Simply Recipes", createdAt: created),
        Feed(id: UUID(uuidString: "30000000-0000-0000-0000-000000000002")!, url: "https://example.com/kitchn.xml", title: "The Weeknight Kitchen", createdAt: created.addingTimeInterval(1)),
    ]

    static let feedEntries: [FeedEntry] = [
        FeedEntry(title: "The 3-Can Chili I Make When I Have No Time To Cook", link: URL(string: "https://example.com/three-can-chili")!,
                  published: now.addingTimeInterval(-3600 * 20), summary: "A pantry chili that tastes like it simmered all day, ready in 25 minutes."),
        FeedEntry(title: "How to Make Perfect Crispy Roast Potatoes", link: URL(string: "https://example.com/roast-potatoes")!,
                  published: now.addingTimeInterval(-3600 * 44), summary: "Parboil, rough them up, and don't crowd the pan."),
        FeedEntry(title: "A Better Way to Cook Fish on a Weeknight", link: URL(string: "https://example.com/weeknight-fish")!,
                  published: now.addingTimeInterval(-3600 * 90), summary: "Five minutes of prep, one pan, nothing to clean."),
        FeedEntry(title: "Brown Butter Banana Bread", link: URL(string: "https://example.com/banana-bread")!,
                  published: now.addingTimeInterval(-3600 * 140), summary: "Nutty, tender and impossible to stop slicing."),
    ]

    static let scannedText = """
    Grandma's Apple Crumble
    Serves 6
    Prep time: 15 minutes
    Cook time: 40 minutes
    A cozy autumn dessert.
    INGREDIENTS
    6 apples, peeled and sliced
    100g flour
    80g cold butter
    80g oats
    60g brown sugar
    METHOD
    1. Heat the oven to 180°C and
    arrange the apples in a dish.
    2. Rub the butter into the flour, then stir in the oats and sugar.
    3. Scatter over the apples and bake for 40 minutes until golden.
    """

    static let images: [UUID: Data] = [
        shakshuka.id: SampleImages.jpeg(food: (0.80, 0.22, 0.12), plate: (0.96, 0.94, 0.90), seed: 1),
        chili.id: SampleImages.jpeg(food: (0.45, 0.14, 0.09), plate: (0.93, 0.92, 0.90), seed: 2),
        curry.id: SampleImages.jpeg(food: (0.92, 0.66, 0.16), plate: (0.95, 0.95, 0.93), seed: 3),
        pancakes.id: SampleImages.jpeg(food: (0.89, 0.67, 0.34), plate: (0.97, 0.97, 0.97), seed: 4),
        brownies.id: SampleImages.jpeg(food: (0.28, 0.16, 0.10), plate: (0.94, 0.93, 0.90), seed: 5),
        videoRecipe.id: SampleImages.jpeg(food: (0.93, 0.80, 0.52), plate: (0.96, 0.95, 0.92), seed: 6),
    ]

    static let youtubeDraft = Recipe(
        title: "The Only Pasta You'll Ever Need", summary: "From Chef Marco on YouTube.",
        tags: ["YouTube"], sourceURL: "https://www.youtube.com/watch?v=dQw4w9WgXcQ",
        notes: "Thanks for watching! This one is so simple, you will make it every week."
    )

    static let youtubeNotice = "This video's description doesn't include a full recipe. Check the ingredients and steps below against the video."

    static let transcript = "Today we're making the simplest pasta. Bring a big pot of salted water to the boil and cook two hundred grams of spaghetti. While that cooks, melt two tablespoons of butter with a clove of garlic, then toss everything together with a splash of pasta water and plenty of parmesan."

    /// Isolated settings, so previews and snapshots never read or change the real app's preferences.
    static let defaults: UserDefaults = {
        let suite = "RecipesSampleData"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        return defaults
    }()

    static func library() -> RecipeLibrary {
        RecipeLibrary(recipes: recipes, mealPlan: mealPlan, groceries: groceries, feeds: feeds, images: images,
                      remindersStatus: .synced(now))
    }

    static func feedLoader() -> FeedLoader {
        FeedLoader(
            seed: Dictionary(uniqueKeysWithValues: feeds.map { ($0.id, FeedLoader.State.loaded(feedEntries)) }),
            results: [feedEntries[0].id: ImportResult(recipe: chili, imageData: images[chili.id])]
        )
    }

    static func cookSession() -> CookSession {
        CookSession(queue: [shakshuka.id, chili.id], current: shakshuka.id, stepIndex: [shakshuka.id: 2])
    }

    static func timers() -> TimerCenter {
        TimerCenter(seed: [
            CookTimer(label: "Shakshuka · step 3", duration: 600, endsAt: now.addingTimeInterval(443)),
            CookTimer(label: "Pasta water", duration: 300, endsAt: now.addingTimeInterval(95)),
            CookTimer(label: "Brownies", duration: 1800, endsAt: now.addingTimeInterval(-3)),
        ])
    }
}

extension View {
    /// Supplies the app's environment objects, filled with sample data.
    @MainActor
    func withSampleEnvironment() -> some View {
        environmentObject(SampleData.library())
            .environmentObject(SampleData.feedLoader())
            .environmentObject(SampleData.cookSession())
            .environmentObject(SampleData.timers())
            .environmentObject(AppRouter())
            .environment(\.referenceDate, SampleData.now)
            .defaultAppStorage(SampleData.defaults)
            .tint(Theme.accent)
    }
}

enum SampleImages {
    /// A stylised plate on a linen background, standing in for a recipe photo.
    static func jpeg(food: (CGFloat, CGFloat, CGFloat), plate: (CGFloat, CGFloat, CGFloat), seed: Int) -> Data {
        let width = 1200, height = 750
        let space = CGColorSpaceCreateDeviceRGB()
        let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0, space: space,
                                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        let background = [CGColor(red: 0.84, green: 0.80, blue: 0.73, alpha: 1), CGColor(red: 0.70, green: 0.66, blue: 0.60, alpha: 1)] as CFArray
        context.drawLinearGradient(CGGradient(colorsSpace: space, colors: background, locations: [0, 1])!,
                                   start: CGPoint(x: 0, y: CGFloat(height)), end: CGPoint(x: CGFloat(width), y: 0), options: [])
        let center = CGPoint(x: 600 + CGFloat(seed % 3) * 20 - 20, y: 375)
        context.setShadow(offset: CGSize(width: 0, height: -18), blur: 40, color: CGColor(gray: 0, alpha: 0.35))
        context.setFillColor(CGColor(red: plate.0, green: plate.1, blue: plate.2, alpha: 1))
        context.fillEllipse(in: CGRect(x: center.x - 300, y: center.y - 300, width: 600, height: 600))
        context.setShadow(offset: .zero, blur: 0)
        context.setFillColor(CGColor(gray: 0.0, alpha: 0.06))
        context.fillEllipse(in: CGRect(x: center.x - 235, y: center.y - 235, width: 470, height: 470))
        context.setFillColor(CGColor(red: food.0, green: food.1, blue: food.2, alpha: 1))
        context.fillEllipse(in: CGRect(x: center.x - 215, y: center.y - 215, width: 430, height: 430))
        var state = UInt64(seed) &* 6364136223846793005 &+ 1442695040888963407
        func next() -> CGFloat {
            state = state &* 6364136223846793005 &+ 1442695040888963407
            return CGFloat(state >> 33) / CGFloat(1 << 31)
        }
        for index in 0..<26 {
            let angle = next() * .pi * 2, radius = next() * 190
            let size = 16 + next() * 34
            let tone = index % 3 == 0 ? (0.99, 0.93, 0.62) : (0.22 + next() * 0.15, 0.45 + next() * 0.2, 0.2)
            context.setFillColor(CGColor(red: tone.0, green: tone.1, blue: tone.2, alpha: 0.9))
            context.fillEllipse(in: CGRect(x: center.x + cos(angle) * radius - size / 2, y: center.y + sin(angle) * radius - size / 2, width: size, height: size * 0.8))
        }
        let output = NSMutableData()
        let destination = CGImageDestinationCreateWithData(output, UTType.jpeg.identifier as CFString, 1, nil)!
        CGImageDestinationAddImage(destination, context.makeImage()!, [kCGImageDestinationLossyCompressionQuality: 0.85] as CFDictionary)
        CGImageDestinationFinalize(destination)
        return output as Data
    }
}

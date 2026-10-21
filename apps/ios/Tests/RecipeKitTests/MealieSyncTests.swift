import CoreGraphics
import ImageIO
import XCTest
@testable import RecipeKit

final class MealieSyncTests: XCTestCase {
    private var root: URL!
    private var state: URL!
    private var mealie: FakeMealie!
    private let server = URL(string: "http://mealie.test")!

    override func setUpWithError() throws {
        root = FileManager.default.temporaryDirectory.appendingPathComponent("mealiesync-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        state = root.appendingPathComponent("state.json")
        mealie = FakeMealie()
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: root)
    }

    private var library: Library { Library(root: root.appendingPathComponent("library")) }

    private func makeSync(library: Library? = nil, state: URL? = nil, options: MealieSync.Options = .init()) -> MealieSync {
        MealieSync(library: library ?? self.library, server: server, api: mealie, stateURL: state ?? self.state, options: options)
    }

    @discardableResult
    private func save(_ recipe: Recipe, in library: Library? = nil) throws -> Recipe {
        try (library ?? self.library).recipes.save(recipe)
    }

    private func recipes(in library: Library? = nil) throws -> [Recipe] {
        try (library ?? self.library).recipes.list()
    }

    func testNewLocalRecipesAreCreatedInMealieWithoutThePlaceholderContent() async throws {
        try save(Recipe(title: "Pasta", ingredients: ["1 lb pasta"], steps: ["Boil."], tags: ["Dinner"]))
        let report = try await makeSync().sync()
        XCTAssertEqual(report.recipes.sent, 1)
        let remote = try XCTUnwrap(mealie.remote(named: "Pasta"))
        XCTAssertEqual((remote["recipeIngredient"] as? [MealieObject])?.compactMap { $0.string("note") }, ["1 lb pasta"])
        XCTAssertEqual((remote["recipeInstructions"] as? [MealieObject])?.compactMap { $0.string("text") }, ["Boil."])
        XCTAssertEqual((remote["tags"] as? [MealieObject])?.compactMap { $0.string("name") }, ["Dinner"])
    }

    func testASecondPassWithNothingNewDoesNothing() async throws {
        try save(Recipe(title: "Pasta", steps: ["Boil."]))
        mealie.add(name: "Stew", steps: ["Simmer."])
        let sync = makeSync()
        try await sync.sync()
        let report = try await sync.sync()
        XCTAssertFalse(report.changedAnything, "\(report)")
        XCTAssertEqual(try recipes().count, 2)
    }

    func testRecipesFromMealieKeepTheirIDsSoDevicesAgree() async throws {
        mealie.add(name: "Stew", ingredients: ["beef"], steps: ["Simmer."])
        try await makeSync().sync()
        let pulled = try XCTUnwrap(recipes().first)
        XCTAssertEqual(pulled.title, "Stew")
        XCTAssertEqual(pulled.ingredients, ["beef"])
        XCTAssertEqual(pulled.id.uuidString.lowercased(), mealie.remote(named: "Stew")?.string("id"))

        let other = Library(root: root.appendingPathComponent("second"))
        try await makeSync(library: other, state: root.appendingPathComponent("second-state.json")).sync()
        XCTAssertEqual(try recipes(in: other).first?.id, pulled.id)
    }

    func testLocalEditsGoToMealieAndMealieEditsComeBack() async throws {
        var recipe = try save(Recipe(title: "Pasta", steps: ["Boil."]))
        let sync = makeSync()
        try await sync.sync()

        recipe.title = "Better Pasta"
        recipe.steps = ["Boil.", "Drain."]
        recipe.updatedAt = Date(timeIntervalSinceNow: 5)
        try save(recipe)
        var report = try await sync.sync()
        XCTAssertEqual(report.recipes.sent, 1)
        XCTAssertEqual(mealie.recipeNames, ["Better Pasta"])

        mealie.edit("Better Pasta") { $0["description"] = "Quick." }
        report = try await sync.sync()
        XCTAssertEqual(report.recipes.received, 1)
        XCTAssertEqual(try recipes().first?.summary, "Quick.")
        let quiet = try await sync.sync()
        XCTAssertFalse(quiet.changedAnything, "\(quiet)")
    }

    func testTheLaterEditWinsWhenBothSidesChanged() async throws {
        var recipe = try save(Recipe(title: "Pasta", summary: "one"))
        let sync = makeSync()
        try await sync.sync()

        mealie.edit("Pasta") { $0["description"] = "from mealie" }
        recipe.summary = "from app"
        recipe.updatedAt = Date(timeIntervalSince1970: 1_000)
        try DocumentStore<Recipe>(directory: library.recipes.directory).save(recipe)
        let report = try await sync.sync()
        XCTAssertEqual(report.recipes.conflicts, 1)
        XCTAssertEqual(try recipes().first?.summary, "from mealie")
    }

    func testDeletionsTravelBothWays() async throws {
        let toss = try save(Recipe(title: "Toss me"))
        try save(Recipe(title: "Keep me"))
        mealie.add(name: "Remote only")
        let sync = makeSync()
        try await sync.sync()
        XCTAssertEqual(mealie.recipeNames, ["Keep me", "Remote only", "Toss me"])

        try library.deleteRecipe(toss)
        mealie.remove("Remote only")
        let report = try await sync.sync()
        XCTAssertEqual(report.recipes.deletedInMealie, 1)
        XCTAssertEqual(report.recipes.deletedHere, 1)
        XCTAssertEqual(mealie.recipeNames, ["Keep me"])
        XCTAssertEqual(try recipes().map(\.title), ["Keep me"])
    }

    func testAnEditBeatsADeletionOnTheOtherSide() async throws {
        var recipe = try save(Recipe(title: "Pasta"))
        let sync = makeSync()
        try await sync.sync()
        mealie.remove("Pasta")
        recipe.summary = "edited"
        recipe.updatedAt = Date(timeIntervalSinceNow: 5)
        try save(recipe)
        try await sync.sync()
        XCTAssertEqual(mealie.recipeNames, ["Pasta"])
    }

    func testRefusesToDeleteMostOfTheLibrary() async throws {
        for index in 0..<30 { try save(Recipe(title: "Recipe \(index)")) }
        let sync = makeSync()
        try await sync.sync()
        for recipe in try recipes() { try library.deleteRecipe(recipe) }
        do {
            try await sync.sync()
            XCTFail("Expected the safeguard to stop the pass")
        } catch MealieError.tooManyDeletions(let count) {
            XCTAssertEqual(count, 30)
        }
        XCTAssertEqual(mealie.recipeNames.count, 30)
        try await makeSync(options: .init(allowMassDeletion: true)).sync()
        XCTAssertEqual(mealie.recipeNames.count, 0)
    }

    func testLosingTheSyncStateAdoptsRecipesInsteadOfDuplicatingThem() async throws {
        try save(Recipe(title: "Pasta", ingredients: ["pasta"], steps: ["Boil."]))
        try await makeSync().sync()
        try FileManager.default.removeItem(at: state)
        let report = try await makeSync().sync()
        XCTAssertEqual(mealie.recipeNames, ["Pasta"])
        XCTAssertEqual(try recipes().count, 1)
        XCTAssertEqual(report.recipes.sent + report.recipes.received, 0)
    }

    func testADuplicatedMealieRecipeBecomesItsOwnRecipeHere() async throws {
        try save(Recipe(title: "Pasta"))
        let sync = makeSync()
        try await sync.sync()
        let original = try XCTUnwrap(mealie.remote(named: "Pasta"))
        mealie.add(name: "Pasta (copy)")
        mealie.edit("Pasta (copy)") { $0["extras"] = original["extras"] }
        try await sync.sync()
        let titles = try recipes().map(\.title).sorted()
        XCTAssertEqual(titles, ["Pasta", "Pasta (copy)"])
        XCTAssertEqual(Set(try recipes().map(\.id)).count, 2)
    }

    func testRatingsAndFavoritesRoundTripAndClear() async throws {
        var recipe = try save(Recipe(title: "Pasta", isFavorite: true, rating: 4))
        let sync = makeSync()
        try await sync.sync()
        XCTAssertEqual(mealie.rating(of: "Pasta"), MealieRating(rating: 4, isFavorite: true))

        recipe.rating = nil
        recipe.isFavorite = false
        recipe.updatedAt = Date(timeIntervalSinceNow: 5)
        try save(recipe)
        try await sync.sync()
        XCTAssertEqual(mealie.rating(of: "Pasta"), MealieRating(rating: nil, isFavorite: false))
        let quiet = try await sync.sync()
        XCTAssertFalse(quiet.changedAnything, "\(quiet)")
    }

    func testPhotosGoBothWaysAndDeletionsFollow() async throws {
        let recipe = try save(Recipe(title: "Pasta"))
        let jpeg = try XCTUnwrap(Self.jpeg())
        try library.images.save(jpeg, for: recipe.id)
        let sync = makeSync()
        var report = try await sync.sync()
        XCTAssertEqual(report.photos.sent, 1)
        let quiet = try await sync.sync()
        XCTAssertFalse(quiet.changedAnything, "\(quiet)")

        mealie.setPhoto("Pasta", try XCTUnwrap(Self.jpeg(width: 32)))
        report = try await sync.sync()
        XCTAssertEqual(report.photos.received, 1)
        XCTAssertNotEqual(library.images.data(for: recipe.id), jpeg)
        let quiet2 = try await sync.sync()
        XCTAssertFalse(quiet2.changedAnything, "\(quiet2)")

        try library.images.delete(for: recipe.id)
        report = try await sync.sync()
        XCTAssertEqual(report.photos.deletedInMealie, 1)
        XCTAssertNil(mealie.remote(named: "Pasta")?.string("image"))
    }

    func testOneRecipeMealieRefusesDoesNotStopTheRest() async throws {
        try save(Recipe(title: "Pasta"))
        mealie.failRecipeUpdates = true
        let report = try await makeSync().sync()
        XCTAssertEqual(report.problems.count, 1)
        mealie.failRecipeUpdates = false
        let retry = try await makeSync().sync()
        XCTAssertEqual(retry.recipes.sent, 1)
    }

    func testPlanSyncsWithRecipesAndIdeas() async throws {
        let recipe = try save(Recipe(title: "Pasta"))
        try library.mealPlan.save(MealPlanEntry(recipeID: recipe.id, title: "Pasta", day: "2026-10-25", meal: .lunch))
        try library.mealPlan.save(MealPlanEntry(title: "Leftovers", day: "2026-10-26", meal: .snack))
        mealie.addPlanEntry(date: "2026-10-27", type: "drink", title: "Wine")
        let sync = makeSync()
        let report = try await sync.sync()
        XCTAssertEqual(report.mealPlan.sent, 2)
        XCTAssertEqual(report.mealPlan.received, 1)
        XCTAssertEqual(mealie.planCount, 3)
        let entries = try library.mealPlan.list()
        XCTAssertEqual(entries.first { $0.title == "Wine" }?.meal, .snack)
        XCTAssertEqual(entries.first { $0.day == "2026-10-25" }?.recipeID, recipe.id)
        let quiet = try await sync.sync()
        XCTAssertFalse(quiet.changedAnything, "\(quiet)")

        try library.mealPlan.delete(try XCTUnwrap(entries.first { $0.title == "Leftovers" }))
        let removal = try await sync.sync()
        XCTAssertEqual(removal.mealPlan.deletedInMealie, 1)
        XCTAssertEqual(mealie.planCount, 2)
    }

    func testGroceriesSyncAndKeepStructureWhenOnlyCheckedChanges() async throws {
        try library.groceries.save(GroceryItem(name: "black beans", quantity: "500g"))
        mealie.addShoppingItem(note: "milk")
        let sync = makeSync()
        let report = try await sync.sync()
        XCTAssertEqual(report.groceries.sent, 1)
        XCTAssertEqual(report.groceries.received, 1)
        XCTAssertEqual(mealie.shoppingNotes, ["500g black beans", "milk"])

        var beans = try XCTUnwrap(library.groceries.list().first { $0.name == "black beans" })
        XCTAssertEqual(beans.quantity, "500g")
        beans.isChecked = true
        try library.groceries.save(beans)
        try await sync.sync()
        XCTAssertEqual(mealie.shoppingNotes, ["500g black beans", "milk"])
        let quiet = try await sync.sync()
        XCTAssertFalse(quiet.changedAnything, "\(quiet)")
    }

    func testPointingAtAnotherServerStartsFresh() async throws {
        try save(Recipe(title: "Pasta"))
        try await makeSync().sync()
        let elsewhere = MealieSync(library: library, server: URL(string: "http://other.test")!, api: FakeMealie(), stateURL: state)
        let report = try await elsewhere.sync()
        XCTAssertEqual(report.recipes.deletedHere, 0)
        XCTAssertEqual(report.recipes.sent, 1)
    }

    private static func jpeg(width: Int = 16) -> Data? {
        let context = CGContext(data: nil, width: width, height: width, bitsPerComponent: 8, bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)
        context?.setFillColor(red: 1, green: CGFloat(width) / 64, blue: 0, alpha: 1)
        context?.fill(CGRect(x: 0, y: 0, width: width, height: width))
        guard let image = context?.makeImage() else { return nil }
        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(data, "public.jpeg" as CFString, 1, nil) else { return nil }
        CGImageDestinationAddImage(destination, image, nil)
        return CGImageDestinationFinalize(destination) ? data as Data : nil
    }

    // MARK: - Timeline

    private let earlier = Date(timeIntervalSince1970: 1_700_000_000)

    func testCookedItEventsGoToMealiesTimelineAndSetLastMade() async throws {
        var recipe = Recipe(title: "Pasta", steps: ["Boil."])
        recipe.timeline = [TimelineEvent(date: earlier, note: "Needed salt")]
        try save(recipe)
        let report = try await makeSync().sync()
        XCTAssertEqual(report.timeline.sent, 1)
        XCTAssertEqual(mealie.timelineMessages(of: "Pasta"), ["Needed salt"])
        XCTAssertEqual(mealie.lastMade.values.first, earlier)
    }

    func testEventsLoggedInMealieComeBackAndMealieSystemEventsDoNot() async throws {
        try save(Recipe(title: "Pasta", steps: ["Boil."]))
        let sync = makeSync()
        try await sync.sync()
        mealie.addTimelineEvent(recipe: "Pasta", message: "Great with garlic", date: earlier)
        mealie.addTimelineEvent(recipe: "Pasta", message: "Recipe created", date: earlier, type: "system")
        let report = try await sync.sync()
        XCTAssertEqual(report.timeline.received, 1)
        XCTAssertEqual(try recipes().first?.timeline.map(\.note), ["Great with garlic"])
        XCTAssertEqual(try recipes().first?.timeline.first?.date, earlier)
    }

    func testTimelineSyncSettlesWithoutDuplicatesOrRepeatedRecipePushes() async throws {
        var recipe = Recipe(title: "Pasta", steps: ["Boil."])
        recipe.timeline = [TimelineEvent(date: earlier, note: "First")]
        try save(recipe)
        mealie.add(name: "Stew", steps: ["Simmer."])
        mealie.addTimelineEvent(recipe: "Stew", message: "Hearty", date: earlier)
        let sync = makeSync()
        try await sync.sync()
        try await sync.sync()
        let report = try await sync.sync()
        XCTAssertFalse(report.changedAnything, "\(report)")
        XCTAssertEqual(mealie.timelineMessages(of: "Pasta"), ["First"])
        XCTAssertEqual(try recipes().first { $0.title == "Stew" }?.timeline.count, 1)
    }

    func testAnEventAlreadyInBothPlacesIsNotDuplicated() async throws {
        var recipe = Recipe(title: "Pasta", steps: ["Boil."])
        recipe.timeline = [TimelineEvent(date: earlier, note: "Same night")]
        try save(recipe)
        mealie.add(name: "Pasta", steps: ["Boil."])
        mealie.addTimelineEvent(recipe: "Pasta", message: "Same night", date: earlier)
        try await makeSync().sync()
        XCTAssertEqual(mealie.timelineMessages(of: "Pasta"), ["Same night"])
        XCTAssertEqual(try recipes().first?.timeline.count, 1)
    }

    func testDeletingAnEventOnOneSideDeletesItOnTheOther() async throws {
        var recipe = Recipe(title: "Pasta", steps: ["Boil."])
        recipe.timeline = [TimelineEvent(date: earlier, note: "One"), TimelineEvent(date: earlier.addingTimeInterval(86_400), note: "Two")]
        let saved = try save(recipe)
        let sync = makeSync()
        try await sync.sync()

        var trimmed = try XCTUnwrap(try recipes().first)
        trimmed.timeline.removeAll { $0.note == "One" }
        try save(trimmed)
        var report = try await sync.sync()
        XCTAssertEqual(report.timeline.deletedInMealie, 1)
        XCTAssertEqual(mealie.timelineMessages(of: "Pasta"), ["Two"])

        mealie.removeTimelineEvents(of: "Pasta")
        report = try await sync.sync()
        XCTAssertEqual(report.timeline.deletedHere, 1)
        XCTAssertEqual(try recipes().first { $0.id == saved.id }?.timeline, [])
    }
}

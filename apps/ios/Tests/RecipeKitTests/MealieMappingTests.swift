import XCTest
@testable import RecipeKit

final class MealieMappingTests: XCTestCase {
    func testParsesDurationsMealieAndSchemaOrgWrite() {
        XCTAssertEqual(MealieRecipeMapping.parseMinutes("PT1H30M"), 90)
        XCTAssertEqual(MealieRecipeMapping.parseMinutes("1 hr 15 min"), 75)
        XCTAssertEqual(MealieRecipeMapping.parseMinutes("45 minutes"), 45)
        XCTAssertEqual(MealieRecipeMapping.parseMinutes("20"), 20)
        XCTAssertEqual(MealieRecipeMapping.parseMinutes("PT0S"), nil)
        XCTAssertNil(MealieRecipeMapping.parseMinutes("overnight"))
    }

    func testDatesFromBothMealieEndpointsAgree() {
        XCTAssertEqual(MealieDate.parse("2026-10-20T21:42:27.722641Z"), MealieDate.parse("2026-10-20T21:42:27.722641+00:00"))
        XCTAssertNotNil(MealieDate.parse("2026-10-20T21:42:27Z"))
    }

    func testNormalizesServerAddresses() {
        XCTAssertEqual(MealieClient.normalizedServer("mealie.example.com")?.absoluteString, "https://mealie.example.com")
        XCTAssertEqual(MealieClient.normalizedServer(" http://192.168.1.5:9925/ ")?.absoluteString, "http://192.168.1.5:9925")
        XCTAssertEqual(MealieClient.normalizedServer("https://example.com/mealie/api/")?.absoluteString, "https://example.com/mealie")
        XCTAssertNil(MealieClient.normalizedServer("ftp://example.com"))
        XCTAssertNil(MealieClient.normalizedServer("  "))
    }

    func testReadsARecipeAsTheAppSeesIt() {
        let remote: MealieObject = [
            "name": "Soup", "description": " Warm. ", "recipeServings": 4.0, "prepTimeSeconds": 600, "performTime": "1 hr",
            "orgURL": "https://example.com/soup",
            "recipeIngredient": [
                ["display": "2 cups stock", "title": "Base"], ["note": "salt"], ["display": "", "note": "", "originalText": ""],
                ["display": "1 onion", "title": "Veg"],
            ],
            "recipeInstructions": [["text": "Heat."], ["text": " "], ["text": "Serve."]],
            "tags": [["name": "Dinner / Soup"]], "recipeCategory": [["name": "dinner/soup"], ["name": "Mains"]],
            "notes": [["title": "Notes", "text": "Freezes well"], ["title": "Swap", "text": "Use water"]],
            "updatedAt": "2026-10-20T21:42:27.722641Z",
        ]
        let recipe = MealieRecipeMapping.recipe(from: remote, rating: MealieRating(rating: 4.0, isFavorite: true), existing: nil, id: UUID())
        XCTAssertEqual(recipe.title, "Soup")
        XCTAssertEqual(recipe.summary, "Warm.")
        XCTAssertEqual(recipe.servings, 4)
        XCTAssertEqual(recipe.prepMinutes, 10)
        XCTAssertEqual(recipe.cookMinutes, 60)
        XCTAssertEqual(recipe.ingredients, ["2 cups stock", "salt", "1 onion"])
        XCTAssertEqual(recipe.ingredientSections, [IngredientSection(title: "Base", start: 0), IngredientSection(title: "Veg", start: 2)])
        XCTAssertEqual(recipe.steps, ["Heat.", "Serve."])
        XCTAssertEqual(recipe.tags, ["Dinner/Soup", "Mains"])
        XCTAssertEqual(recipe.notes, "Freezes well\n\nSwap\nUse water")
        XCTAssertEqual(recipe.sourceURL, "https://example.com/soup")
        XCTAssertEqual(recipe.rating, 4)
        XCTAssertTrue(recipe.isFavorite)
    }

    func testAnUnratedRecipeHasNoRating() {
        let recipe = MealieRecipeMapping.recipe(from: ["name": "A"], rating: MealieRating(rating: 0, isFavorite: false), existing: nil, id: UUID())
        XCTAssertNil(recipe.rating)
    }

    func testPushKeepsStructuredIngredientsAndFieldsTheAppDoesNotKnow() {
        let butter: MealieObject = ["note": "melted", "display": "2 tbsp butter", "quantity": 2, "food": ["name": "butter"], "title": NSNull()]
        let remote: MealieObject = [
            "name": "Toast", "recipeIngredient": [["note": "bread", "display": "bread"], butter],
            "recipeInstructions": [["id": "step-1", "text": "Toast.", "ingredientReferences": [["referenceId": "x"]]]],
            "nutrition": ["calories": "90"], "extras": ["other": "keep"],
        ]
        var recipe = Recipe(title: "Toast", ingredients: ["bread", "2 tbsp butter", "jam"], steps: ["Toast.", "Spread."], tags: ["Breakfast"])
        recipe.ingredientSections = [IngredientSection(title: "Spread", start: 1)]
        let tag: MealieObject = ["name": "Breakfast", "id": "t1"]
        let body = MealieRecipeMapping.body(for: recipe, patching: remote, tags: [tag], categories: [])

        let ingredients = body["recipeIngredient"] as! [MealieObject]
        XCTAssertEqual(ingredients.count, 3)
        XCTAssertEqual((ingredients[1]["food"] as? MealieObject)?["name"] as? String, "butter")
        XCTAssertEqual(ingredients[1].string("title"), "Spread")
        XCTAssertEqual(ingredients[2].string("note"), "jam")
        let steps = body["recipeInstructions"] as! [MealieObject]
        XCTAssertEqual(steps[0].string("id"), "step-1")
        XCTAssertEqual(steps[1].string("text"), "Spread.")
        XCTAssertEqual((body["nutrition"] as? MealieObject)?["calories"] as? String, "90")
        let extras = body["extras"] as! MealieObject
        XCTAssertEqual(extras["other"] as? String, "keep")
        XCTAssertEqual(MealieRecipeMapping.appID(in: body), recipe.id)
    }

    func testPushLeavesTimesAloneWhenTheyAlreadyMatch() {
        let remote: MealieObject = ["name": "A", "prepTime": "PT10M", "prepTimeSeconds": 600]
        let body = MealieRecipeMapping.body(for: Recipe(title: "A", prepMinutes: 10), patching: remote, tags: [], categories: [])
        XCTAssertEqual(body["prepTime"] as? String, "PT10M")
        let changed = MealieRecipeMapping.body(for: Recipe(title: "A", prepMinutes: 15), patching: remote, tags: [], categories: [])
        XCTAssertEqual(changed["prepTime"] as? String, "15 minutes")
        XCTAssertEqual(changed["prepTimeSeconds"] as? Int, 900)
    }

    func testCategoriesStayCategories() {
        let remote: MealieObject = ["recipeCategory": [["name": "Mains"]]]
        let labels = MealieRecipeMapping.labels(for: Recipe(title: "A", tags: ["mains", "Quick", "quick"]), remote: remote)
        XCTAssertEqual(labels.categories, ["mains"])
        XCTAssertEqual(labels.tags, ["Quick"])
    }

    func testStepExtrasSurviveARoundTrip() {
        var recipe = Recipe(title: "Video", steps: ["Chop.", "Fry."], stepTimestamps: [10, nil], wantToCook: true, queuedAt: Date(timeIntervalSince1970: 1_700_000_000))
        recipe.imageURL = "https://example.com/p.jpg"
        let body = MealieRecipeMapping.body(for: recipe, patching: [:], tags: [], categories: [])
        let back = MealieRecipeMapping.recipe(from: body, rating: nil, existing: nil, id: recipe.id)
        XCTAssertEqual(back.stepTimestamps, [10, nil])
        XCTAssertTrue(back.wantToCook)
        XCTAssertEqual(back.queuedAt, recipe.queuedAt)
        XCTAssertEqual(back.imageURL, recipe.imageURL)
    }

    func testStepPhotosFollowTheirStepWhenStepsMove() {
        let photo = UUID()
        var existing = Recipe(title: "A", steps: ["Mix.", "Bake."])
        existing.stepImages = [nil, photo]
        let remote: MealieObject = ["name": "A", "recipeInstructions": [["text": "Preheat."], ["text": "Mix."], ["text": "Bake."]]]
        let updated = MealieRecipeMapping.recipe(from: remote, rating: nil, existing: existing, id: existing.id)
        XCTAssertEqual(updated.stepImages, [nil, nil, photo])
    }

    func testHashPlannerCoversEveryCase() {
        typealias Sync = MealieSync
        let links = [
            "same": Sync.HashLink(remoteID: "r-same", hash: "a"),
            "localEdit": Sync.HashLink(remoteID: "r-localEdit", hash: "a"),
            "remoteEdit": Sync.HashLink(remoteID: "r-remoteEdit", hash: "a"),
            "bothEdit": Sync.HashLink(remoteID: "r-bothEdit", hash: "a"),
            "localGone": Sync.HashLink(remoteID: "r-localGone", hash: "a"),
            "remoteGone": Sync.HashLink(remoteID: "r-remoteGone", hash: "a"),
            "editedThenGone": Sync.HashLink(remoteID: "r-editedThenGone", hash: "a"),
            "bothGone": Sync.HashLink(remoteID: "r-bothGone", hash: "a"),
        ]
        let local = ["same": "a", "localEdit": "b", "remoteEdit": "a", "bothEdit": "b", "remoteGone": "a", "editedThenGone": "b", "new": "n", "twin": "t"]
        let remote = ["r-same": "a", "r-localEdit": "a", "r-remoteEdit": "b", "r-bothEdit": "c", "r-localGone": "a", "r-twin": "t", "r-fresh": "f"]
        let steps = Sync.planHashSync(local: local, remote: remote, links: links)
        XCTAssertEqual(Set(steps), [
            .updateRemote("localEdit", remoteID: "r-localEdit"),
            .updateLocal("remoteEdit", remoteID: "r-remoteEdit"),
            .updateRemote("bothEdit", remoteID: "r-bothEdit"),
            .deleteRemote("localGone", remoteID: "r-localGone"),
            .deleteLocal("remoteGone"),
            .createRemote("editedThenGone"),
            .unlink("bothGone"),
            .createRemote("new"),
            .link("twin", remoteID: "r-twin", hash: "t"),
            .createLocal(remoteID: "r-fresh"),
        ])
    }
}

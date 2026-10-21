import ArgumentParser
import Foundation
import RecipeKit

struct MealieCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "mealie",
        abstract: "Sync the library with a Mealie server.",
        discussion: """
        Syncs recipes with photos, the meal plan and a shopping list both ways; when both sides edited the same \
        recipe, the later edit wins. Create an API token in Mealie (your profile, API Tokens), then set MEALIE_URL \
        and MEALIE_TOKEN so the token stays out of your shell history.
        """
    )

    @OptionGroup var library: LibraryOptions
    @Option(name: .long, help: "Mealie address, such as https://mealie.example.com. Defaults to MEALIE_URL.")
    var server: String?
    @Option(name: .long, help: "Name of the Mealie shopping list that holds the groceries.")
    var list = "Recipes"
    @Flag(name: .long, help: "Leave the meal plan out of the sync.")
    var skipMealPlan = false
    @Flag(name: .long, help: "Leave the groceries out of the sync.")
    var skipGroceries = false
    @Flag(name: .long, help: "Go ahead even if the pass would delete most of what was synced before.")
    var allowMassDeletion = false
    @Flag(name: .long, help: "Output the result as JSON.")
    var json = false

    func run() async throws {
        let environment = ProcessInfo.processInfo.environment
        guard let address = server ?? environment["MEALIE_URL"], let url = MealieClient.normalizedServer(address) else {
            throw ValidationError("Give the Mealie address with --server or MEALIE_URL (http:// or https://).")
        }
        guard let token = environment["MEALIE_TOKEN"], !token.isEmpty else {
            throw ValidationError("Set MEALIE_TOKEN to an API token from Mealie (your profile, API Tokens).")
        }
        let root = library.resolved
        let options = MealieSync.Options(shoppingListName: list, syncMealPlan: !skipMealPlan, syncGroceries: !skipGroceries, allowMassDeletion: allowMassDeletion)
        let sync = MealieSync(
            library: root.library, server: url, api: MealieClient(server: url, token: token),
            stateURL: MealieSync.defaultStateURL(library: root.root, server: url), options: options
        )
        let report = try await sync.sync()
        if json {
            try printJSON(report)
            return
        }
        print("Synced \(root.root.path) with \(url.absoluteString)")
        for (name, counts) in [("recipes", report.recipes), ("photos", report.photos), ("meal plan", report.mealPlan), ("groceries", report.groceries), ("timeline", report.timeline)] {
            print("  \(name): sent \(counts.sent), received \(counts.received), deleted in Mealie \(counts.deletedInMealie), deleted here \(counts.deletedHere)")
            if counts.conflicts > 0 { print("    \(counts.conflicts) edited on both sides (the later edit was kept)") }
        }
        for problem in report.problems { print("  ! \(problem)") }
    }
}

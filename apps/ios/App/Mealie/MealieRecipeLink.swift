import Foundation
import RecipeKit

/// The page for a recipe on the user's own Mealie server, once it has synced there from this device.
enum MealieRecipeLink {
    private static var groupSlugs: [String: String] = [:]

    @MainActor
    static func url(for recipe: Recipe) async -> URL? {
        guard let connection = MealieCredentials.load(), let server = MealieClient.normalizedServer(connection.server) else { return nil }
        let root = await Task.detached { RecipeLocation.resolveForApp().root }.value
        let stateURL = MealieSync.defaultStateURL(library: root, server: server)
        guard let slug = await Task.detached(operation: { MealieSync.slug(forRecipe: recipe.id, stateURL: stateURL, server: server) }).value else {
            return nil
        }
        var group = groupSlugs[connection.server]
        if group == nil, let user = try? await MealieClient(server: server, token: connection.token).currentUser() {
            group = user.groupSlug
            groupSlugs[connection.server] = user.groupSlug
        }
        return MealieClient.recipePageURL(server: server, groupSlug: group, slug: slug)
    }
}

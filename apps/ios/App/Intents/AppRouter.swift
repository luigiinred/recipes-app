import Foundation
import RecipeKit

/// Lets an intent ask the running app to show a recipe or start cooking.
@MainActor
final class AppRouter: ObservableObject {
    static let shared = AppRouter()

    @Published var recipeID: UUID?
    @Published var cookRecipeID: UUID?
    @Published var reminder: ReminderKind?
    @Published var mealieLink: MealieLink?
    @Published var destination: AppDestination?
    @Published var feedPost: FeedEntry?
    /// Set by the tab bar's add button; the tab it names starts adding and clears it.
    @Published var add: AppDestination?
    /// A recipe to open straight into editing, on a Mac where its page edits in place.
    @Published var editRecipeID: UUID?
    /// The Mac shows Settings as a section of the main window.
    @Published var showsSettings = false
}

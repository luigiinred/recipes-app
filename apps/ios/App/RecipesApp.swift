import RecipeKit
import SwiftUI

@main
struct RecipesApp: App {
    @StateObject private var library = RecipeLibrary()
    @StateObject private var feeds = FeedLoader()
    @StateObject private var cook = CookSession()
    @StateObject private var timers = TimerCenter()
    @StateObject private var router = AppRouter.shared
    @StateObject private var mealie = MealieSyncController()
    @Environment(\.scenePhase) private var scenePhase

    init() { ReminderCenter.shared.install() }

    var body: some Scene {
        WindowGroup {
            RootView()
                .onboardingTour()
                .mealiePairingPrompt()
                .environmentObject(library)
                .environmentObject(feeds)
                .environmentObject(cook)
                .environmentObject(timers)
                .environmentObject(router)
                .environmentObject(mealie)
                .appTheme()
                #if os(macOS)
                .sizedFromEnvironment()
                #endif
                .task { await library.run() }
                .task { await mealie.run() }
                .onChange(of: library.recipes) { mealie.request(); rescheduleReminders() }
                .onChange(of: library.mealPlan) { mealie.request(); rescheduleReminders() }
                .onChange(of: library.groceries) { mealie.request() }
                .onChange(of: scenePhase) { if scenePhase == .active { mealie.refresh(); mealie.request(); rescheduleReminders() } }
                .onOpenURL(perform: open)
                .task {
                    // App Store captures on an unfolded iPhone Duo can't drive the app with UI tests, so they open a link at launch.
                    if let link = ProcessInfo.processInfo.environment["RECIPES_OPEN_URL"], let url = URL(string: link) { open(url) }
                }
        }
        #if os(macOS)
        Settings {
            SettingsView(inSheet: false)
                .environmentObject(library)
                .environmentObject(mealie)
                .appTheme()
        }
        #endif
    }

    private func open(_ url: URL) {
        if let link = MealieLink(url: url) { router.mealieLink = link }
        else if let id = RecipeLink.cookRecipeID(from: url) { router.cookRecipeID = id }
        else if let id = RecipeLink.recipeID(from: url) { router.recipeID = id }
        else if let destination = RecipeLink.destination(from: url) { router.destination = destination }
    }

    private func rescheduleReminders() {
        Task { await ReminderCenter.shared.reschedule(plan: library.mealPlan, recipes: library.recipes) }
    }
}

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
                .onOpenURL { url in
                    if let id = RecipeLink.cookRecipeID(from: url) { router.cookRecipeID = id }
                    else if let id = RecipeLink.recipeID(from: url) { router.recipeID = id }
                    else if let destination = RecipeLink.destination(from: url) { router.destination = destination }
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

    private func rescheduleReminders() {
        Task { await ReminderCenter.shared.reschedule(plan: library.mealPlan, recipes: library.recipes) }
    }
}

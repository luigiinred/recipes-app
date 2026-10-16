import SwiftUI

@main
struct RecipesApp: App {
    @StateObject private var library = RecipeLibrary()
    @StateObject private var feeds = FeedLoader()
    @StateObject private var cook = CookSession()
    @StateObject private var timers = TimerCenter()
    @StateObject private var router = AppRouter.shared

    var body: some Scene {
        WindowGroup {
            RootView()
                .onboardingTour()
                .environmentObject(library)
                .environmentObject(feeds)
                .environmentObject(cook)
                .environmentObject(timers)
                .environmentObject(router)
                .tint(Theme.accent)
                #if os(macOS)
                .sizedFromEnvironment()
                #endif
                .task { await library.run() }
                #if os(iOS)
                .task { await TimerLiveActivities.endAll() }
                #endif
                .onOpenURL { url in
                    if let id = RecipeLink.recipeID(from: url) { router.recipeID = id }
                }
        }
        #if os(macOS)
        Settings {
            SettingsView(inSheet: false)
                .environmentObject(library)
                .tint(Theme.accent)
        }
        #endif
    }
}

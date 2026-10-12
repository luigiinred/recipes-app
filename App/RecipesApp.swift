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
                .environmentObject(library)
                .environmentObject(feeds)
                .environmentObject(cook)
                .environmentObject(timers)
                .environmentObject(router)
                .tint(Theme.accent)
                .task { await library.run() }
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

enum Theme {
    static let accent = Color(red: 0.86, green: 0.28, blue: 0.22)
}

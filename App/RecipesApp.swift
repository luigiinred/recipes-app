import SwiftUI

@main
struct RecipesApp: App {
    @StateObject private var library = RecipeLibrary()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(library)
                .tint(Theme.accent)
        }
    }
}

enum Theme {
    static let accent = Color(red: 0.86, green: 0.28, blue: 0.22)
}

import ImagePlayground
import RecipeKit
import SwiftUI

enum SettingsPage: Hashable {
    case recipes, planner, cooking, groceries, intelligence, data
}

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    var inSheet = true
    /// iPad: the pages sit in a sidebar next to the page you pick, instead of being pushed.
    var splitsPages = false
    /// Fixed Apple Intelligence state for previews and snapshots, so they don't depend on the machine.
    var intelligenceOverride: (status: AppleIntelligence.Status, imagePlayground: Bool)?
    var listing = AppStoreLink.listing
    var writeReview = AppStoreLink.writeReview

    @State private var showingTour = false
    @State private var page: SettingsPage? = .recipes

    var body: some View {
        Group {
            if splitsPages { split } else { stack }
        }
        #if os(iOS)
        .fullScreenCover(isPresented: $showingTour) { OnboardingView { showingTour = false } }
        #else
        .sheet(isPresented: $showingTour) { OnboardingView { showingTour = false } }
        #endif
        #if os(macOS)
        .frame(minWidth: 460, minHeight: 520)
        #endif
    }

    private var stack: some View {
        NavigationStack {
            Form { rows }
                .formStyle(.grouped)
                .navigationTitle("Settings")
                #if os(iOS)
                .navigationBarTitleDisplayMode(.inline)
                #endif
                .toolbar {
                    if inSheet { ToolbarItem(placement: .confirmationAction) { ConfirmButton { dismiss() } } }
                }
                .navigationDestination(for: SettingsPage.self) { destination($0) }
        }
    }

    private var split: some View {
        NavigationSplitView {
            List(selection: $page) { rows }
                .navigationTitle("Settings")
                .navigationSplitViewColumnWidth(min: 320, ideal: 380, max: 460)
                #if os(iOS)
                .toolbar(removing: .sidebarToggle)
                #endif
        } detail: {
            NavigationStack {
                if let page { destination(page) } else { ContentUnavailableView("Settings", systemImage: "gearshape") }
            }
        }
        .ignoresSafeArea(.container, edges: .top)
    }

    @ViewBuilder
    private var rows: some View {
        Section {
            NavigationLink(value: SettingsPage.recipes) { Label("Recipes", systemImage: "book.closed") }
            NavigationLink(value: SettingsPage.planner) { Label("Planner", systemImage: "calendar") }
            NavigationLink(value: SettingsPage.cooking) { Label("Cooking", systemImage: "frying.pan") }
            NavigationLink(value: SettingsPage.groceries) { Label("Groceries", systemImage: "checklist") }
        }
        Section {
            NavigationLink(value: SettingsPage.intelligence) { Label("Apple Intelligence", systemImage: "sparkles") }
        }
        Section {
            NavigationLink(value: SettingsPage.data) { Label("Data & Developer", systemImage: "externaldrive") }
        }
        if let listing, let writeReview {
            Section {
                Link(destination: writeReview) { Label("Leave a Review", systemImage: "star.bubble") }
                ShareLink(
                    item: listing,
                    message: Text("I keep all my recipes in Recipes. It's free, open source, and has no ads or account.")
                ) { Label("Tell a Friend Who Cooks", systemImage: "heart") }
            } header: {
                Text("Help Support Us")
            } footer: {
                Text("Recipes is free, open source, and will never show you an ad, so word of mouth is our whole marketing budget. A kind review is how the next home cook finds a recipe box that doesn't nag them.")
            }
        }
        Section {
            Link(destination: FeedbackLink.url(for: .bug)) { Label("Report a Bug", systemImage: "ladybug") }
            Link(destination: FeedbackLink.url(for: .feature)) { Label("Suggest a Change", systemImage: "lightbulb") }
        } header: {
            Text("Feedback")
        } footer: {
            Text("Opens a ready-to-fill GitHub issue with your app version and system already added. Nothing from your recipes is included. You'll need a free GitHub account to send it.")
        }
        Section {
            Button { showingTour = true } label: { Label("Show Welcome Tour", systemImage: "sparkles") }
            Link(destination: URL(string: "https://github.com/luigiinred/recipes-app")!) {
                Label("Source Code", systemImage: "chevron.left.forwardslash.chevron.right")
            }
        }
    }

    @ViewBuilder
    private func destination(_ page: SettingsPage) -> some View {
        switch page {
        case .recipes: RecipesSettingsPage()
        case .planner: PlannerSettingsPage()
        case .cooking: CookingSettingsPage()
        case .groceries: GroceriesSettingsPage()
        case .intelligence: IntelligenceSettingsPage(override: intelligenceOverride)
        case .data: DataSettingsPage()
        }
    }
}

private struct RecipesSettingsPage: View {
    @AppStorage(AppSettings.Key.listStyle) private var listStyle = RecipeListStyle.list
    @AppStorage(AppSettings.Key.ratingStyle) private var ratingStyle = RatingStyle.favorites.rawValue
    @AppStorage(AppSettings.Key.reviewImports) private var reviewImports = true
    @AppStorage(AppSettings.Key.showDeleteSwipe) private var showDeleteSwipe = false

    var body: some View {
        Form {
            Section {
                Picker("Recipe list", selection: $listStyle) {
                    ForEach(RecipeListStyle.allCases, id: \.self) { Label($0.title, systemImage: $0.symbol).tag($0) }
                }
                Picker("Mark recipes with", selection: $ratingStyle) {
                    ForEach(RatingStyle.allCases, id: \.rawValue) { Text($0.title).tag($0.rawValue) }
                }
            } header: {
                Text("Browsing")
            } footer: {
                Text("Favorites are a heart on the recipes you love. Star ratings give each recipe one to five stars, and Top Rated lists the 4 and 5 star ones. Switching never deletes either.")
            }
            Section {
                Toggle("Show Delete", isOn: $showDeleteSwipe)
            } header: {
                Text("Swipe actions")
            } footer: {
                Text("Swipe a recipe left for Up Next and Favorite. Turn this on to add Delete, which always asks before removing anything.")
            }
            Section {
                Toggle("Review before saving", isOn: $reviewImports)
            } header: {
                Text("Importing")
            } footer: {
                Text("Open the title and categories for a check after every import, including from the Share sheet.")
            }
        }
        .formStyle(.grouped)
        .settingsPage("Recipes")
    }
}

private struct PlannerSettingsPage: View {
    @AppStorage(AppSettings.Key.defaultMeal) private var defaultMeal = MealChoice.automatic.rawValue
    @AppStorage(AppSettings.Key.hiddenMeals) private var hiddenMeals = ""
    @AppStorage(AppSettings.Key.weekStart) private var weekStart = AppSettings.WeekStart.system.rawValue

    var body: some View {
        Form {
            Section {
                Picker("Add recipes as", selection: $defaultMeal) {
                    ForEach(MealChoice.allCases, id: \.rawValue) { Text($0.title).tag($0.rawValue) }
                }
            } footer: {
                Text("Automatic files a recipe under breakfast, lunch, a snack, or dinner based on the time of day. You can still change the meal whenever you add one. Recipes in Up Next leave the queue when you plan them.")
            }
            Section("My Week") {
                Picker("Week starts on", selection: $weekStart) {
                    ForEach(AppSettings.WeekStart.allCases, id: \.rawValue) { Text($0.title).tag($0.rawValue) }
                }
            }
            Section("Meals to plan") {
                ForEach(Meal.allCases, id: \.self) { meal in
                    Toggle(isOn: shown(meal)) { Label(meal.title, systemImage: meal.symbol) }
                }
            }
        }
        .formStyle(.grouped)
        .settingsPage("Planner")
    }

    private func shown(_ meal: Meal) -> Binding<Bool> {
        Binding(
            get: { !AppSettings.hiddenMeals(hiddenMeals).contains(meal) },
            set: { visible in
                var hidden = AppSettings.hiddenMeals(hiddenMeals)
                if visible { hidden.remove(meal) } else { hidden.insert(meal) }
                hiddenMeals = AppSettings.encode(hidden)
            }
        )
    }
}

private struct CookingSettingsPage: View {
    @AppStorage(AppSettings.Key.keepAwake) private var keepAwake = true

    var body: some View {
        Form {
            Section {
                Toggle("Keep the screen awake", isOn: $keepAwake)
            } header: {
                Text("Cook mode")
            } footer: {
                Text("Stops the screen from locking while you're following a recipe.")
            }
        }
        .formStyle(.grouped)
        .settingsPage("Cooking")
    }
}

private struct GroceriesSettingsPage: View {
    @EnvironmentObject private var library: RecipeLibrary

    var body: some View {
        Form {
            Section {
                Toggle("Sync with Reminders", isOn: Binding(
                    get: { library.remindersEnabled },
                    set: { value in Task { await library.setRemindersEnabled(value) } }
                ))
            } footer: {
                Text("Keeps your grocery list in a “Groceries” list in the Reminders app, in both directions.")
            }
        }
        .formStyle(.grouped)
        .settingsPage("Groceries")
    }
}

private struct IntelligenceSettingsPage: View {
    @Environment(\.supportsImagePlayground) private var supportsImagePlayground
    let override: (status: AppleIntelligence.Status, imagePlayground: Bool)?

    var body: some View {
        let status = override?.status ?? AppleIntelligence.status
        Form {
            Section {
                statusRow("Smart Plan for My Week", ready: status.isAvailable)
                statusRow("Recipes from video captions", ready: status.isAvailable)
                statusRow("Photos with Image Playground", ready: override?.imagePlayground ?? supportsImagePlayground)
            } footer: {
                if status.isAvailable {
                    Text("Everything runs on this device. Smart Plan fills your week from your recipes, and videos without a written recipe are turned into one from their captions.")
                } else {
                    Text(status.explanation + " Smart Plan falls back to a simple rotation, and a video without a written recipe opens as a draft with its captions beside it.")
                }
            }
        }
        .formStyle(.grouped)
        .settingsPage("Apple Intelligence")
    }

    private func statusRow(_ title: String, ready: Bool) -> some View {
        LabeledContent {
            Label(ready ? "Ready" : "Not available", systemImage: ready ? "checkmark.circle.fill" : "exclamationmark.circle")
                .foregroundStyle(ready ? Theme.accent : Color.secondary)
        } label: {
            Text(title)
        }
    }
}

private struct DataSettingsPage: View {
    @EnvironmentObject private var library: RecipeLibrary
    @State private var exportDocument: LibraryExportDocument?
    @State private var isExportPresented = false
    @State private var isExporting = false
    @State private var exportError: String?
    @State private var tidyMessage: String?

    var body: some View {
        Form {
            Section {
                Button {
                    Task {
                        let count = await library.tidyRecipes()
                        tidyMessage = count == 0 ? "Every recipe is already tidy." : "Cleaned up \(count) \(count == 1 ? "recipe" : "recipes")."
                    }
                } label: {
                    Label("Tidy imported recipes", systemImage: "wand.and.sparkles")
                }
            } header: {
                Text("Clean up")
            } footer: {
                Text("Removes stray symbols from ingredients, turns labels like “Dressing:” into sections, and splits steps that were pasted as one block.")
            }
            Section {
                Button { Task { await prepareExport() } } label: {
                    Label("Export all data as JSON", systemImage: "square.and.arrow.up")
                }
                .disabled(isExporting)
            } header: {
                Text("Your data")
            } footer: {
                Text("Saves every recipe, photo, planned meal, and grocery item to one JSON file that you own. Photos are included as base64.")
            }
            Section("Developer") {
                NavigationLink { DeveloperToolsView() } label: { Label("Developer Tools", systemImage: "wrench.and.screwdriver") }
            }
        }
        .formStyle(.grouped)
        .fileExporter(
            isPresented: $isExportPresented,
            document: exportDocument,
            contentType: .json,
            defaultFilename: LibraryExportDocument.defaultFilename()
        ) { result in
            if case .failure(let error) = result { exportError = error.localizedDescription }
        }
        .alert("Tidy imported recipes", isPresented: Binding(get: { tidyMessage != nil }, set: { if !$0 { tidyMessage = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(tidyMessage ?? "")
        }
        .alert("Couldn't export", isPresented: Binding(get: { exportError != nil }, set: { if !$0 { exportError = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(exportError ?? "")
        }
        .settingsPage("Data & Developer")
    }

    private func prepareExport() async {
        isExporting = true
        defer { isExporting = false }
        do {
            exportDocument = LibraryExportDocument(data: try await library.exportJSON())
            isExportPresented = true
        } catch {
            exportError = error.localizedDescription
        }
    }
}

private extension View {
    func settingsPage(_ title: String) -> some View {
        navigationTitle(title)
        #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
        #endif
    }
}

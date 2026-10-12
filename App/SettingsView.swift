import RecipeKit
import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var library: RecipeLibrary
    @Environment(\.dismiss) private var dismiss
    var inSheet = true

    @AppStorage(AppSettings.Key.defaultMeal) private var defaultMeal = MealChoice.automatic.rawValue
    @AppStorage(AppSettings.Key.hiddenMeals) private var hiddenMeals = ""
    @AppStorage(AppSettings.Key.weekStart) private var weekStart = AppSettings.WeekStart.system.rawValue
    @AppStorage(AppSettings.Key.listStyle) private var listStyle = RecipeListStyle.list
    @AppStorage(AppSettings.Key.reviewImports) private var reviewImports = true
    @AppStorage(AppSettings.Key.keepAwake) private var keepAwake = true
    @AppStorage(AppSettings.Key.ratingStyle) private var ratingStyle = RatingStyle.favorites.rawValue

    @State private var exportDocument: LibraryExportDocument?
    @State private var isExportPresented = false
    @State private var isExporting = false
    @State private var exportError: String?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Add recipes as", selection: $defaultMeal) {
                        ForEach(MealChoice.allCases, id: \.rawValue) { Text($0.title).tag($0.rawValue) }
                    }
                    Picker("Week starts on", selection: $weekStart) {
                        ForEach(AppSettings.WeekStart.allCases, id: \.rawValue) { Text($0.title).tag($0.rawValue) }
                    }
                } header: {
                    Text("Planner")
                } footer: {
                    Text("Automatic files a recipe under breakfast, lunch, a snack, or dinner based on the time of day. You can still change the meal whenever you add one. Recipes in Up Next leave the queue when you plan them.")
                }
                Section("Meals in the planner") {
                    ForEach(Meal.allCases, id: \.self) { meal in
                        Toggle(isOn: shown(meal)) { Label(meal.title, systemImage: meal.symbol) }
                    }
                }
                Section {
                    Picker("Recipe list", selection: $listStyle) {
                        ForEach(RecipeListStyle.allCases, id: \.self) { Label($0.title, systemImage: $0.symbol).tag($0) }
                    }
                    Picker("Mark recipes with", selection: $ratingStyle) {
                        ForEach(RatingStyle.allCases, id: \.rawValue) { Text($0.title).tag($0.rawValue) }
                    }
                    Toggle("Review imports before saving", isOn: $reviewImports)
                } header: {
                    Text("Recipes")
                } footer: {
                    Text("Favorites are a heart on the recipes you love. Star ratings give each recipe one to five stars, and Top Rated lists the 4 and 5 star ones. Switching never deletes either.")
                }
                Section {
                    Toggle("Sync with Reminders", isOn: Binding(
                        get: { library.remindersEnabled },
                        set: { value in Task { await library.setRemindersEnabled(value) } }
                    ))
                } header: {
                    Text("Groceries")
                } footer: {
                    Text("Keeps your grocery list in a “Groceries” list in the Reminders app, in both directions.")
                }
                Section("Cooking") {
                    Toggle("Keep the screen awake in cook mode", isOn: $keepAwake)
                }
                Section("Developer") {
                    NavigationLink { DeveloperToolsView() } label: { Label("Developer Tools", systemImage: "wrench.and.screwdriver") }
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
            .alert("Couldn't export", isPresented: Binding(get: { exportError != nil }, set: { if !$0 { exportError = nil } })) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(exportError ?? "")
            }
            .navigationTitle("Settings")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                if inSheet { ToolbarItem(placement: .confirmationAction) { ConfirmButton { dismiss() } } }
            }
        }
        #if os(macOS)
        .frame(minWidth: 460, minHeight: 520)
        #endif
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

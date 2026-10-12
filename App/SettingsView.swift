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
                    Text("Calendar")
                } footer: {
                    Text("Automatic files a recipe under breakfast, lunch, a snack, or dinner based on the time of day. You can still change the meal whenever you add one.")
                }
                Section("Meals in the planner") {
                    ForEach(Meal.allCases, id: \.self) { meal in
                        Toggle(isOn: shown(meal)) { Label(meal.title, systemImage: meal.symbol) }
                    }
                }
                Section("Recipes") {
                    Picker("Recipe list", selection: $listStyle) {
                        ForEach(RecipeListStyle.allCases, id: \.self) { Label($0.title, systemImage: $0.symbol).tag($0) }
                    }
                    Toggle("Review imports before saving", isOn: $reviewImports)
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
            }
            .formStyle(.grouped)
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

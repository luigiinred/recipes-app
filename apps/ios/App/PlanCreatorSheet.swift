import RecipeKit
import SwiftUI

/// Builds a week from recommended recipes: pick a few and they fill the open days in order.
struct PlanCreatorSheet: View {
    static let recommendationLimit = 12

    @EnvironmentObject private var library: RecipeLibrary
    @Environment(\.dismiss) private var dismiss
    @Environment(\.referenceDate) private var referenceDate
    @Environment(\.appAccent) private var accent
    let weekStart: Date
    var smartPlan: (() -> Void)?

    @AppStorage(AppSettings.Key.weekStart) private var weekStartSetting = AppSettings.WeekStart.system.rawValue
    @State private var meal = Meal.dinner
    @State private var chosen: [UUID] = []
    @State private var seeded = false

    private var calendar: Calendar { AppSettings.calendar(weekStart: weekStartSetting) }

    /// Up Next first, then favorites and top rated, then the newest of the rest.
    private var recommended: [Recipe] {
        let cookable = library.recipes.filter { !$0.isIdea }
        let queued = RecipeCollection.wantToCook.filter(cookable)
        let loved = cookable.filter { !$0.wantToCook && ($0.isFavorite || ($0.rating ?? 0) >= 4) }
        let rest = cookable.filter { !$0.wantToCook && !$0.isFavorite && ($0.rating ?? 0) < 4 }.sorted { $0.createdAt > $1.createdAt }
        return Array((queued + loved + rest).prefix(Self.recommendationLimit))
    }

    /// The week's days from today on, skipping any whose slot for `meal` is taken.
    private var openDays: [String] {
        let today = calendar.startOfDay(for: referenceDate ?? Date())
        let taken = Set(library.mealPlan.filter { $0.meal == meal }.map(\.day))
        return (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: weekStart) }
            .filter { $0 >= today || !calendar.isDate(weekStart, equalTo: today, toGranularity: .weekOfYear) }
            .map { DayKey.string(from: $0, calendar: calendar) }
            .filter { !taken.contains($0) }
    }

    private var suggestions: [PlanSuggestion] {
        zip(chosen, openDays).map { PlanSuggestion(recipeID: $0, day: $1, meal: meal) }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Picker("Plan as", selection: $meal) {
                        ForEach(Meal.allCases, id: \.self) { Label($0.title, systemImage: $0.symbol).tag($0) }
                    }
                } footer: {
                    Text(openDays.isEmpty ? "Every day left this week already has a \(meal.title.lowercased())." :
                        "\(openDays.count) open \(openDays.count == 1 ? "day" : "days") this week. Recipes fill them in the order you pick them.")
                }
                Section {
                    ForEach(recommended) { recipe in
                        Button { toggle(recipe.id) } label: { row(recipe) }
                            .buttonStyle(.plain)
                    }
                } header: {
                    Text("Recommended")
                } footer: {
                    Text("Up Next comes first, then your favorites. Recipes leave Up Next once they're planned.")
                }
                if let smartPlan {
                    Section {
                        Button {
                            dismiss()
                            smartPlan()
                        } label: { Label("Let Smart Plan Choose", systemImage: "sparkles") }
                    }
                }
            }
            .themedCanvas()
            .navigationTitle("Create a Plan")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { CancelButton() }
                ToolbarItem(placement: .confirmationAction) {
                    ConfirmButton(title: "Add to My Week", isDisabled: suggestions.isEmpty) {
                        Task { await library.plan(suggestions) }
                        dismiss()
                    }
                }
            }
            .onAppear {
                guard !seeded else { return }
                seeded = true
                chosen = Array(recommended.prefix(min(openDays.count, 5)).map(\.id))
            }
        }
        #if os(macOS)
        .frame(minWidth: 420, minHeight: 560)
        #endif
    }

    private func row(_ recipe: Recipe) -> some View {
        let index = chosen.firstIndex(of: recipe.id)
        let day = index.flatMap { openDays.indices.contains($0) ? openDays[$0] : nil }
        return HStack(spacing: 12) {
            RecipeRow(recipe: recipe)
            Spacer(minLength: 0)
            VStack(alignment: .trailing, spacing: 2) {
                Image(systemName: index == nil ? "circle" : "checkmark.circle.fill")
                    .imageScale(.large)
                    .foregroundStyle(index == nil ? AnyShapeStyle(.tertiary) : AnyShapeStyle(accent))
                if let day, let date = DayKey.date(from: day) {
                    Text(date, format: .dateTime.weekday(.abbreviated)).appFont(.caption, weight: .semibold).foregroundStyle(accent)
                }
            }
        }
        .contentShape(Rectangle())
        .accessibilityAddTraits(index == nil ? [] : .isSelected)
    }

    private func toggle(_ id: UUID) {
        if let index = chosen.firstIndex(of: id) { chosen.remove(at: index) } else { chosen.append(id) }
    }
}

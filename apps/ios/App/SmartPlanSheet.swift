import RecipeKit
import SwiftUI

/// Asks Apple Intelligence to fill the open slots of a week with recipes that go together, then lets you tweak the result.
struct SmartPlanSheet: View {
    @EnvironmentObject private var library: RecipeLibrary
    @Environment(\.dismiss) private var dismiss
    let weekStart: Date

    @AppStorage(AppSettings.Key.weekStart) private var weekStartSetting = AppSettings.WeekStart.system.rawValue
    @State private var meals: Set<Meal> = [.dinner]
    @State private var phase = Phase.options
    @State private var suggestions: [PlanSuggestion] = []
    @State private var usedAppleIntelligence = false

    private enum Phase { case options, working, review }

    private var calendar: Calendar { AppSettings.calendar(weekStart: weekStartSetting) }
    private var dayKeys: [String] {
        (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: weekStart) }.map { DayKey.string(from: $0, calendar: calendar) }
    }

    var body: some View {
        NavigationStack {
            Group {
                switch phase {
                case .options: options
                case .working:
                    VStack(spacing: 6) {
                        MascotLoader(height: 170)
                        Text("Planning your week…").font(.system(.title3, weight: .bold))
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                case .review: review
                }
            }
            .navigationTitle("Smart Plan")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { CancelButton() }
                if phase == .review {
                    ToolbarItem(placement: .confirmationAction) {
                        ConfirmButton(title: "Add to My Week", isDisabled: suggestions.isEmpty) {
                            Task { await library.plan(suggestions) }
                            dismiss()
                        }
                    }
                }
            }
        }
        #if os(macOS)
        .frame(minWidth: 420, minHeight: 520)
        #endif
    }

    private var status: AppleIntelligence.Status { AppleIntelligence.status }

    private var options: some View {
        Form {
            Section {
                ForEach(Meal.allCases, id: \.self) { meal in
                    Toggle(isOn: Binding(
                        get: { meals.contains(meal) },
                        set: { if $0 { meals.insert(meal) } else { meals.remove(meal) } }
                    )) { Label(meal.title, systemImage: meal.symbol) }
                }
            } header: {
                Text("Plan these meals")
            } footer: {
                Text("Only empty slots this week are filled. Recipes in Up Next come first, then favorites, and they leave the queue once planned.")
            }
            Section {
                Button { run() } label: {
                    Label("Plan My Week", systemImage: "sparkles").frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(meals.isEmpty || library.recipes.isEmpty)
            } footer: {
                if status.isAvailable {
                    Text("Apple Intelligence picks recipes that fit together and balances the week. It runs on your device.")
                } else {
                    Text("\(status.explanation) Until then, a simple rotation of your Up Next recipes and favorites is used.")
                }
            }
        }
        .formStyle(.grouped)
    }

    private var review: some View {
        List {
            Section {
                Label(usedAppleIntelligence ? "Planned with Apple Intelligence" : "Planned from Up Next and favorites",
                      systemImage: usedAppleIntelligence ? "sparkles" : "arrow.triangle.2.circlepath")
                    .font(.footnote).foregroundStyle(.secondary)
            }
            ForEach(dayKeys.filter { day in suggestions.contains { $0.day == day } }, id: \.self) { day in
                Section(header: Text(DayKey.date(from: day)?.formatted(.dateTime.weekday(.wide).month().day()) ?? day)) {
                    ForEach(suggestions.filter { $0.day == day }.sorted { $0.meal.order < $1.meal.order }) { suggestion in
                        HStack(spacing: 12) {
                            Image(systemName: suggestion.meal.symbol).foregroundStyle(Theme.accent).frame(width: 24)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(library.recipe(id: suggestion.recipeID)?.title ?? "Recipe").font(.system(.body))
                                Text(suggestion.meal.title).font(.caption).foregroundStyle(.secondary)
                            }
                        }
                        .swipeActions {
                            Button(role: .destructive) { suggestions.removeAll { $0.id == suggestion.id } } label: { Label("Remove", systemImage: "trash") }
                        }
                    }
                }
            }
        }
        .overlay {
            if suggestions.isEmpty {
                MascotEmptyState(scene: .sour, character: .lemon, title: "Nothing to plan",
                                 message: "Every slot for those meals is already filled, or there are no recipes to use.") {
                    Button("Back") { phase = .options }.buttonStyle(PaperButtonStyle()).frame(maxWidth: 240)
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            Button { run() } label: { Label("Try Again", systemImage: "arrow.clockwise").frame(maxWidth: .infinity) }
                .buttonStyle(.bordered)
                .padding(.horizontal, 16).padding(.vertical, 8)
                .background(.bar)
        }
    }

    private func run() {
        let taken = Set(library.mealPlan.map { PlanRequest.slotKey($0.day, $0.meal) })
        let cookable = library.recipes.filter { !$0.isIdea }
        let queued = RecipeCollection.wantToCook.filter(cookable)
        let rest = cookable.filter { !$0.wantToCook }
        let candidates = (queued + rest).map {
            PlanCandidate(id: $0.id, title: $0.title, tags: $0.tags.map(CategoryTree.displayName), minutes: $0.totalMinutes,
                          isFavorite: $0.isFavorite || ($0.rating ?? 0) >= 4, isQueued: $0.wantToCook)
        }
        let request = PlanRequest(days: dayKeys, meals: Meal.allCases.filter(meals.contains), recipes: candidates, taken: taken)
        phase = .working
        Task {
            let result = await SmartPlanner.suggest(request)
            suggestions = result.suggestions
            usedAppleIntelligence = result.usedAppleIntelligence
            phase = .review
        }
    }
}

import RecipeKit
import SwiftUI

/// One week at a glance: each day's meals, with a quick way to add more or let Apple Intelligence fill the gaps.
struct MyWeekView: View {
    @EnvironmentObject private var library: RecipeLibrary
    @EnvironmentObject private var router: AppRouter
    @Environment(\.referenceDate) private var referenceDate
    let open: (UUID) -> Void

    @State private var weekStart: Date
    @State private var addingOn: Date?
    @State private var smartPlanning: Bool
    @AppStorage(AppSettings.Key.weekStart) private var weekStartSetting = AppSettings.WeekStart.system.rawValue

    init(open: @escaping (UUID) -> Void, showsSmartPlan: Bool = false) {
        self.open = open
        let calendar = AppSettings.calendar()
        _weekStart = State(initialValue: calendar.dateInterval(of: .weekOfYear, for: Date())?.start ?? Date())
        _smartPlanning = State(initialValue: showsSmartPlan)
    }

    private var calendar: Calendar { AppSettings.calendar(weekStart: weekStartSetting) }
    private var today: Date { calendar.startOfDay(for: referenceDate ?? Date()) }
    private var days: [Date] { (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: weekStart) } }
    private var isThisWeek: Bool { days.contains { calendar.isDate($0, inSameDayAs: today) } }

    private func entries(on day: Date) -> [MealPlanEntry] {
        let key = DayKey.string(from: day, calendar: calendar)
        return library.mealPlan.filter { $0.day == key }.sorted { ($0.meal.order, $0.title) < ($1.meal.order, $1.title) }
    }

    var body: some View {
        VStack(spacing: 0) {
            weekBar
            List {
                ForEach(days, id: \.self) { day in
                    Section {
                        ForEach(entries(on: day)) { row($0) }
                        addRow(for: day)
                    } header: {
                        header(for: day)
                    }
                }
            }
            .listStyle(.plain)
            .themedCanvas()
            .animation(.snappy, value: library.mealPlan.map(\.id))
        }
        .onAppear { jumpToToday() }
        .onChange(of: router.add) { _, target in
            guard target == .plan else { return }
            router.add = nil
            addingOn = today
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { smartPlanning = true } label: { Label("Smart Plan", systemImage: "sparkles") }
                    .disabled(library.recipes.isEmpty)
            }
        }
        .sheet(item: $addingOn) { AddMealSheet(day: $0) }
        .sheet(isPresented: $smartPlanning) { SmartPlanSheet(weekStart: weekStart) }
    }

    private var weekBar: some View {
        HStack(spacing: 12) {
            Button { shift(-1) } label: { Image(systemName: "chevron.left") }
                .accessibilityLabel("Previous week")
            Text(rangeTitle).font(.headline).frame(maxWidth: .infinity)
                .contentTransition(.numericText())
            Button { shift(1) } label: { Image(systemName: "chevron.right") }
                .accessibilityLabel("Next week")
        }
        .buttonStyle(.plain)
        .foregroundStyle(Theme.accent)
        .padding(.horizontal, 20).padding(.vertical, 6)
        .overlay(alignment: .trailing) {
            if !isThisWeek {
                Button("Today") { withAnimation(.snappy) { jumpToToday() } }
                    .font(.footnote.weight(.semibold)).foregroundStyle(Theme.accent)
                    .padding(.trailing, 48)
            }
        }
    }

    private var rangeTitle: String {
        guard let last = days.last else { return "" }
        let style = Date.FormatStyle().month(.abbreviated).day()
        return "\(weekStart.formatted(style)) – \(last.formatted(style))"
    }

    private func header(for day: Date) -> some View {
        let isToday = calendar.isDate(day, inSameDayAs: today)
        return HStack(spacing: 6) {
            Text(day, format: .dateTime.weekday(.wide)).font(.subheadline.weight(.semibold))
            Text(day, format: .dateTime.month(.abbreviated).day()).font(.subheadline).foregroundStyle(.secondary)
            if isToday {
                Text("Today").font(.caption2.weight(.bold)).textCase(.uppercase)
                    .padding(.horizontal, 7).padding(.vertical, 2)
                    .background(Theme.accent, in: Capsule()).foregroundStyle(.white)
            }
            Spacer()
        }
        .foregroundStyle(isToday ? AnyShapeStyle(Theme.accent) : AnyShapeStyle(.primary))
        .textCase(nil)
    }

    private func row(_ entry: MealPlanEntry) -> some View {
        Button {
            if let id = entry.recipeID, library.recipe(id: id) != nil { open(id) }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: entry.meal.symbol).foregroundStyle(Theme.accent).frame(width: 24)
                VStack(alignment: .leading, spacing: 1) {
                    Text(entry.title).font(.system(.body))
                    Text(entry.meal.title).font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .themedRow()
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) { Task { await library.remove(entry) } } label: { Label("Remove", systemImage: "trash") }
        }
        .contextMenu {
            Menu("Meal", systemImage: "fork.knife") {
                ForEach(Meal.allCases, id: \.self) { meal in
                    Button(meal.title, systemImage: meal.symbol) {
                        var changed = entry
                        changed.meal = meal
                        Task { await library.update(changed) }
                    }
                }
            }
            Menu("Move to", systemImage: "calendar") {
                ForEach(days, id: \.self) { day in
                    Button(day.formatted(.dateTime.weekday(.wide))) {
                        var changed = entry
                        changed.day = DayKey.string(from: day, calendar: calendar)
                        Task { await library.update(changed) }
                    }
                }
            }
            Divider()
            Button("Remove", systemImage: "trash", role: .destructive) { Task { await library.remove(entry) } }
        }
    }

    private func addRow(for day: Date) -> some View {
        Button { addingOn = day } label: {
            Label("Add meal", systemImage: "plus")
                .font(.subheadline)
                .foregroundStyle(Theme.accent)
        }
        .buttonStyle(.plain)
        .themedRow()
        .accessibilityLabel("Add meal on \(day.formatted(.dateTime.weekday(.wide)))")
    }

    private func shift(_ weeks: Int) {
        withAnimation(.snappy) { weekStart = calendar.date(byAdding: .weekOfYear, value: weeks, to: weekStart) ?? weekStart }
    }

    private func jumpToToday() {
        weekStart = calendar.dateInterval(of: .weekOfYear, for: today)?.start ?? today
    }
}

/// Pick a recipe for a day, or jot down an idea: Up Next first, or anything in the library.
struct AddMealSheet: View {
    @EnvironmentObject private var library: RecipeLibrary
    @Environment(\.dismiss) private var dismiss
    let day: Date

    @State private var meal: Meal
    @State private var search = ""
    @State private var idea = ""
    @State private var source: Source

    enum Source: String, CaseIterable { case queue = "Up Next", all = "All Recipes" }

    init(day: Date, initialMeal: Meal = AppSettings.defaultMeal(), source: Source? = nil) {
        self.day = day
        _meal = State(initialValue: initialMeal)
        _source = State(initialValue: source ?? .queue)
    }

    private var queued: [Recipe] { RecipeCollection.wantToCook.filter(library.recipes) }
    private var recipes: [Recipe] {
        let pool = source == .queue && !queued.isEmpty ? queued : library.recipes
        return pool.filter { $0.matches(search) }
    }

    private var trimmedIdea: String { idea.trimmingCharacters(in: .whitespacesAndNewlines) }

    private func addIdea() {
        guard !trimmedIdea.isEmpty else { return }
        Task { await library.plan(idea: trimmedIdea, on: day, meal: meal) }
        dismiss()
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                HStack(spacing: 12) {
                    TextField("Or add an idea, like “Spaghetti” or “Leftovers”", text: $idea)
                        .submitLabel(.done)
                        .onSubmit(addIdea)
                    Button("Add", action: addIdea).disabled(trimmedIdea.isEmpty)
                }
                .padding(.horizontal, 16).padding(.vertical, 10)
                Divider()
                if !queued.isEmpty {
                    Picker("Source", selection: $source) {
                        ForEach(Source.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented).labelsHidden()
                    .padding(.horizontal, 16).padding(.vertical, 8)
                }
                List(recipes) { recipe in
                    Button {
                        Task { await library.plan(recipe, on: day, meal: meal) }
                        dismiss()
                    } label: { RecipeRow(recipe: recipe) }
                    .buttonStyle(.plain)
                }
                .listStyle(.plain)
                .overlay {
                    if library.recipes.isEmpty {
                        EmptyLibraryView()
                    } else if recipes.isEmpty {
                        ContentUnavailableView.search(text: search)
                    }
                }
            }
            .searchable(text: $search, prompt: "Search recipes")
            .navigationTitle(day.formatted(.dateTime.weekday(.wide).month().day()))
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { CancelButton() }
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Picker("Meal", selection: $meal) {
                            ForEach(Meal.allCases, id: \.self) { Label($0.title, systemImage: $0.symbol).tag($0) }
                        }
                    } label: { Label(meal.title, systemImage: meal.symbol) }
                }
            }
        }
        #if os(macOS)
        .frame(minWidth: 420, minHeight: 520)
        #endif
    }
}

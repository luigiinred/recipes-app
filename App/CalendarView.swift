import RecipeKit
import SwiftUI

struct CalendarView: View {
    @EnvironmentObject private var library: RecipeLibrary
    @Environment(\.referenceDate) private var referenceDate
    let open: (UUID) -> Void
    @Binding var mode: CalendarMode

    @State private var pickingDay: Date?
    @State private var selectedDay: Date
    @State private var range: CalendarRange
    @State private var scrollID: Date?

    init(open: @escaping (UUID) -> Void, mode: Binding<CalendarMode>, range: CalendarRange = .month, selectedDay: Date? = nil) {
        self.open = open
        _mode = mode
        _range = State(initialValue: range)
        _selectedDay = State(initialValue: Calendar.current.startOfDay(for: selectedDay ?? Date()))
    }

    @AppStorage(AppSettings.Key.weekStart) private var weekStartSetting = AppSettings.WeekStart.system.rawValue
    private var calendar: Calendar { AppSettings.calendar(weekStart: weekStartSetting) }
    private var today: Date { calendar.startOfDay(for: referenceDate ?? Date()) }

    private var days: [Date] {
        let anchor = referenceDate == nil ? selectedDay : max(selectedDay, today)
        let first = calendar.date(byAdding: .day, value: -14, to: min(today, selectedDay)) ?? today
        let last = calendar.date(byAdding: .day, value: 75, to: max(today, anchor)) ?? today
        let count = (calendar.dateComponents([.day], from: first, to: last).day ?? 90) + 1
        return (0..<count).compactMap { calendar.date(byAdding: .day, value: $0, to: first) }
    }

    private var counts: [String: Int] {
        Dictionary(library.mealPlan.map { ($0.day, 1) }, uniquingKeysWith: +)
    }

    var body: some View {
        VStack(spacing: 0) {
            CalendarHeader(range: $range, selected: $selectedDay, counts: counts, today: today)
            Divider()
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(days, id: \.self) { day in
                        VStack(alignment: .leading, spacing: 0) {
                            header(for: day)
                            ForEach(entries(on: day)) { entry in
                                entryRow(entry)
                            }
                            Divider().padding(.top, 8)
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
                        .id(day)
                    }
                }
                .scrollTargetLayout()
            }
            .scrollPosition(id: $scrollID, anchor: .top)
            .onAppear {
                if let referenceDate { selectedDay = calendar.startOfDay(for: referenceDate) }
                scrollID = selectedDay
            }
            .onChange(of: selectedDay) { _, day in
                withAnimation { scrollID = calendar.startOfDay(for: day) }
            }
        }
        .navigationTitle("Calendar")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar { ToolbarItem(placement: .primaryAction) { CalendarModeButton(mode: $mode) } }
        .sheet(item: $pickingDay) { day in
            RecipePickerSheet(day: day)
        }
    }

    private func entries(on day: Date) -> [MealPlanEntry] {
        let key = DayKey.string(from: day, calendar: calendar)
        return library.mealPlan.filter { $0.day == key }.sorted { $0.meal.order < $1.meal.order }
    }

    private func header(for day: Date) -> some View {
        let isToday = calendar.isDate(day, inSameDayAs: today)
        return HStack(alignment: .center, spacing: 10) {
            Text(day, format: .dateTime.day())
                .font(.system(size: 34, weight: .light, design: .serif))
                .frame(minWidth: 44, alignment: .trailing)
                .foregroundStyle(isToday ? Theme.accent : .primary)
            VStack(alignment: .leading, spacing: 0) {
                Text(day, format: .dateTime.weekday(.wide)).font(.caption.weight(.bold)).textCase(.uppercase)
                Text(day, format: .dateTime.month(.wide)).font(.caption).textCase(.uppercase).foregroundStyle(.secondary)
            }
            Spacer()
            Button { pickingDay = day } label: { Image(systemName: "plus").foregroundStyle(Theme.accent) }
                .buttonStyle(.plain)
                .accessibilityLabel("Add recipe on this day")
        }
        .foregroundStyle(.primary)
    }

    private func entryRow(_ entry: MealPlanEntry) -> some View {
        Button {
            if let id = entry.recipeID, library.recipe(id: id) != nil { open(id) }
        } label: {
            Label {
                Text(entry.title).font(.system(.body, design: .serif))
            } icon: {
                Image(systemName: entry.meal.symbol).foregroundStyle(Theme.accent)
            }
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .contextMenu {
            Menu("Meal") {
                ForEach(Meal.allCases, id: \.self) { meal in
                    Button(meal.title, systemImage: meal.symbol) {
                        var changed = entry
                        changed.meal = meal
                        Task { await library.update(changed) }
                    }
                }
            }
            Button("Remove", role: .destructive) { Task { await library.remove(entry) } }
        }
    }
}

struct RecipePickerSheet: View {
    @EnvironmentObject private var library: RecipeLibrary
    @Environment(\.dismiss) private var dismiss
    let day: Date
    @State private var meal: Meal
    @State private var search = ""

    init(day: Date, initialMeal: Meal = AppSettings.defaultMeal()) {
        self.day = day
        _meal = State(initialValue: initialMeal)
    }

    var body: some View {
        NavigationStack {
            List(library.recipes.filter { $0.matches(search) }) { recipe in
                Button {
                    Task { await library.plan(recipe, on: day, meal: meal) }
                    dismiss()
                } label: {
                    Text(recipe.title).font(.system(.body, design: .serif))
                }
                .buttonStyle(.plain)
            }
            .overlay {
                if library.recipes.isEmpty {
                    ContentUnavailableView("No recipes yet", systemImage: "fork.knife")
                }
            }
            .persistentSearch(text: $search, prompt: "Search recipes")
            .navigationTitle(day.formatted(.dateTime.weekday(.wide).month().day()))
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { CancelButton() }
                ToolbarItem(placement: .principal) {
                    Picker("Meal", selection: $meal) {
                        ForEach(Meal.allCases, id: \.self) { Label($0.title, systemImage: $0.symbol).tag($0) }
                    }
                    .pickerStyle(.menu)
                }
            }
        }
        #if os(macOS)
        .frame(minWidth: 420, minHeight: 480)
        #endif
    }
}


struct CalendarModeButton: View {
    @Binding var mode: CalendarMode

    var body: some View {
        Button {
            withAnimation(.snappy) { mode = mode == .agenda ? .planner : .agenda }
        } label: {
            Label(mode == .agenda ? "Weekly Planner" : "Agenda", systemImage: mode == .agenda ? "rectangle.split.3x1" : "list.bullet.below.rectangle")
        }
        .help(mode == .agenda ? "Switch to the weekly planner" : "Switch to the agenda")
    }
}

import RecipeKit
import SwiftUI

/// A week of meal slots. Drop recipes from the drawer into a slot, or drag planned meals between slots.
struct WeekPlannerView: View {
    @EnvironmentObject private var library: RecipeLibrary
    @Environment(\.referenceDate) private var referenceDate
    let open: (UUID) -> Void
    /// Compact layouts add recipes from a sheet; wider ones show the recipe drawer as its own column.
    var isCompact = false
    @Binding var mode: CalendarMode

    @State private var weekStart: Date
    @State private var pickingSlot: PlannerSlotID?
    @AppStorage(AppSettings.Key.weekStart) private var weekStartSetting = AppSettings.WeekStart.system.rawValue
    @AppStorage(AppSettings.Key.hiddenMeals) private var hiddenMealsSetting = ""

    init(open: @escaping (UUID) -> Void, mode: Binding<CalendarMode>, isCompact: Bool = false, showsAddSheet: Bool = false, weekContaining day: Date? = nil) {
        self.open = open
        _mode = mode
        self.isCompact = isCompact
        let calendar = AppSettings.calendar()
        let anchor = day ?? Date()
        _weekStart = State(initialValue: calendar.dateInterval(of: .weekOfYear, for: anchor)?.start ?? anchor)
        _pickingSlot = State(initialValue: showsAddSheet ? PlannerSlotID(day: calendar.startOfDay(for: anchor), meal: AppSettings.defaultMeal()) : nil)
    }

    private var calendar: Calendar { AppSettings.calendar(weekStart: weekStartSetting) }
    private var today: Date { calendar.startOfDay(for: referenceDate ?? Date()) }
    private var days: [Date] { (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: weekStart) } }

    /// Meals hidden in Settings stay out of the grid unless something is already planned in them this week.
    private var meals: [Meal] {
        let hidden = AppSettings.hiddenMeals(hiddenMealsSetting)
        let keys = Set(days.map { DayKey.string(from: $0) })
        let used = Set(library.mealPlan.filter { keys.contains($0.day) }.map(\.meal))
        return Meal.allCases.filter { !hidden.contains($0) || used.contains($0) }
    }

    var body: some View {
        VStack(spacing: 0) {
            weekBar
            Divider()
            GeometryReader { geometry in
                ScrollView(.vertical) {
                    if geometry.size.width >= 620 { grid(width: geometry.size.width) } else { stack }
                }
            }
        }
        .onAppear {
            if let referenceDate { weekStart = calendar.dateInterval(of: .weekOfYear, for: referenceDate)?.start ?? referenceDate }
        }
        .navigationTitle("Planner")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            if isCompact {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        pickingSlot = PlannerSlotID(day: today, meal: AppSettings.defaultMeal())
                    } label: { Label("Add Recipe", systemImage: "plus") }
                }
                ToolbarItem(placement: .primaryAction) { CalendarModeButton(mode: $mode) }
            }
        }
        .sheet(item: $pickingSlot) { slot in
            PlannerAddSheet(day: slot.day, initialMeal: slot.meal)
        }
    }

    private var weekBar: some View {
        HStack(spacing: 6) {
            Text(weekTitle).font(.system(.title3, design: .serif, weight: .semibold))
            Spacer()
            Button { shift(-1) } label: { Image(systemName: "chevron.left").frame(width: 30, height: 30) }
            Button { weekStart = calendar.dateInterval(of: .weekOfYear, for: today)?.start ?? today } label: { Text("Today").font(.subheadline.weight(.semibold)) }
            Button { shift(1) } label: { Image(systemName: "chevron.right").frame(width: 30, height: 30) }
        }
        .buttonStyle(.plain)
        .foregroundStyle(Theme.accent)
        .padding(.horizontal, 16).padding(.vertical, 10)
    }

    private var weekTitle: String {
        guard let last = days.last else { return "" }
        return "\(weekStart.formatted(.dateTime.month(.abbreviated).day())) – \(last.formatted(.dateTime.month(.abbreviated).day()))"
    }

    private func shift(_ weeks: Int) {
        if let next = calendar.date(byAdding: .weekOfYear, value: weeks, to: weekStart) { withAnimation { weekStart = next } }
    }

    private func grid(width: CGFloat) -> some View {
        let labelWidth: CGFloat = 78
        return VStack(spacing: 0) {
            HStack(spacing: 0) {
                Color.clear.frame(width: labelWidth)
                ForEach(days, id: \.self) { day in dayHeader(day).frame(maxWidth: .infinity) }
            }
            ForEach(meals, id: \.self) { meal in
                HStack(alignment: .top, spacing: 0) {
                    Label(meal.title, systemImage: meal.symbol)
                        .font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                        .labelStyle(.titleAndIcon)
                        .frame(width: labelWidth, alignment: .leading)
                        .padding(.leading, 8).padding(.top, 10)
                    ForEach(days, id: \.self) { day in
                        PlannerSlot(slot: PlannerSlotID(day: day, meal: meal), compact: true, open: open) { pickingSlot = $0 }
                            .frame(maxWidth: .infinity, minHeight: 84)
                    }
                }
                Divider()
            }
        }
    }

    private var stack: some View {
        LazyVStack(alignment: .leading, spacing: 12) {
            ForEach(days, id: \.self) { day in
                VStack(alignment: .leading, spacing: 4) {
                    dayHeader(day, wide: true)
                    ForEach(meals, id: \.self) { meal in
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: meal.symbol).font(.caption).foregroundStyle(.secondary).frame(width: 18).padding(.top, 12)
                            PlannerSlot(slot: PlannerSlotID(day: day, meal: meal), compact: false, open: open) { pickingSlot = $0 }
                        }
                    }
                }
                .padding(12)
                .background(.background.secondary, in: RoundedRectangle(cornerRadius: 14))
            }
        }
        .padding(16)
    }

    private func dayHeader(_ day: Date, wide: Bool = false) -> some View {
        let isToday = calendar.isDate(day, inSameDayAs: today)
        return HStack(spacing: 6) {
            Text(day, format: .dateTime.weekday(wide ? .wide : .abbreviated)).font(.caption.weight(.bold)).textCase(.uppercase)
            Text(day, format: .dateTime.day())
                .font(.system(.subheadline, design: .rounded, weight: .semibold))
                .frame(width: 26, height: 26)
                .foregroundStyle(isToday ? Color.white : Color.primary)
                .background(isToday ? Theme.accent : Color.clear, in: Circle())
        }
        .frame(maxWidth: wide ? .infinity : nil, alignment: wide ? .leading : .center)
        .padding(.vertical, 6)
    }
}

struct PlannerSlotID: Identifiable, Hashable {
    var day: Date
    var meal: Meal
    var id: String { DayKey.string(from: day) + meal.rawValue }
}

struct PlannerSlot: View {
    @EnvironmentObject private var library: RecipeLibrary
    let slot: PlannerSlotID
    let compact: Bool
    let open: (UUID) -> Void
    let add: (PlannerSlotID) -> Void

    @State private var targeted = false

    private var entries: [MealPlanEntry] {
        let key = DayKey.string(from: slot.day)
        return library.mealPlan.filter { $0.day == key && $0.meal == slot.meal }.sorted { $0.createdAt < $1.createdAt }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(entries) { entry in
                Button {
                    if let id = entry.recipeID, library.recipe(id: id) != nil { open(id) }
                } label: {
                    Text(entry.title)
                        .font(.system(compact ? .caption : .subheadline, design: .serif, weight: .medium))
                        .lineLimit(compact ? 3 : 2)
                        .multilineTextAlignment(.leading)
                        .padding(.horizontal, 8).padding(.vertical, 5)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Theme.accent.opacity(0.14), in: RoundedRectangle(cornerRadius: 8))
                        .foregroundStyle(.primary)
                }
                .buttonStyle(.plain)
                .draggable(PlannerPayload(kind: .entry, id: entry.id))
                .contextMenu {
                    Button("Remove", systemImage: "minus.circle", role: .destructive) { Task { await library.removeEntry(id: entry.id) } }
                }
            }
            if entries.isEmpty || targeted {
                Button { add(slot) } label: {
                    Image(systemName: "plus").font(.caption).foregroundStyle(.tertiary)
                        .frame(maxWidth: .infinity, minHeight: compact ? 56 : 30)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Add a recipe")
            }
        }
        .padding(4)
        .background(targeted ? Theme.accent.opacity(0.18) : Color.clear, in: RoundedRectangle(cornerRadius: 10))
        .overlay { RoundedRectangle(cornerRadius: 10).strokeBorder(targeted ? Theme.accent : Color.secondary.opacity(compact ? 0.0 : 0.15), lineWidth: targeted ? 2 : 1) }
        .dropDestination(for: PlannerPayload.self) { items, _ in
            guard let item = items.first else { return false }
            Task { await library.drop(item, on: slot.day, meal: slot.meal) }
            return true
        } isTargeted: { targeted = $0 }
    }
}

/// A search-and-pick sheet for adding to the planner. On iPhone it stays partly open without dimming the page,
/// so recipes can be dragged from it straight into a slot.
struct PlannerAddSheet: View {
    @EnvironmentObject private var library: RecipeLibrary
    @Environment(\.dismiss) private var dismiss
    let day: Date
    @State private var meal: Meal

    init(day: Date, initialMeal: Meal = AppSettings.defaultMeal()) {
        self.day = day
        _meal = State(initialValue: initialMeal)
    }

    var body: some View {
        NavigationStack {
            RecipeDrawer(mode: .constant(nil), onSelect: { recipe in
                Task { await library.plan(recipe, on: day, meal: meal) }
                dismiss()
            })
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
        .presentationDetents([.medium, .large])
        .presentationBackgroundInteraction(.enabled(upThrough: .medium))
        #if os(macOS)
        .frame(minWidth: 420, minHeight: 520)
        #endif
    }
}

import RecipeKit
import SwiftUI

struct WeekBar: View {
    @Binding var weekStart: Date
    let calendar: Calendar
    let today: Date

    private var days: [Date] { (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: weekStart) } }
    private var isThisWeek: Bool { days.contains { calendar.isDate($0, inSameDayAs: today) } }

    var body: some View {
        HStack(spacing: 12) {
            Button { shift(-1) } label: { Image(systemName: "chevron.left") }
                .accessibilityLabel("Previous week")
            Text(rangeTitle).appFont(.headline).frame(maxWidth: .infinity)
                .contentTransition(.numericText())
            Button { shift(1) } label: { Image(systemName: "chevron.right") }
                .accessibilityLabel("Next week")
        }
        .buttonStyle(.plain)
        .foregroundStyle(Theme.accent)
        .padding(.horizontal, 20).padding(.vertical, 6)
        .overlay(alignment: .trailing) {
            if !isThisWeek {
                Button("Today") { withAnimation(.snappy) { weekStart = calendar.dateInterval(of: .weekOfYear, for: today)?.start ?? today } }
                    .appFont(.footnote, weight: .semibold).foregroundStyle(Theme.accent)
                    .padding(.trailing, 48)
            }
        }
    }

    private var rangeTitle: String {
        guard let last = days.last else { return "" }
        let style = Date.FormatStyle().month(.abbreviated).day()
        return "\(weekStart.formatted(style)) – \(last.formatted(style))"
    }

    private func shift(_ weeks: Int) {
        withAnimation(.snappy) { weekStart = calendar.date(byAdding: .weekOfYear, value: weeks, to: weekStart) ?? weekStart }
    }
}

/// Pick a recipe for a day, or type a meal as it is: Up Next first, or anything in the library.
struct AddMealSheet: View {
    @EnvironmentObject private var library: RecipeLibrary
    @SheetDismiss private var dismiss
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
    private var notes: [UpNextNote] {
        guard source == .queue else { return [] }
        return library.upNextNotes.filter { search.isEmpty || $0.title.localizedCaseInsensitiveContains(search) }.sorted { $0.queuedAt < $1.queuedAt }
    }
    private var recipes: [Recipe] {
        let pool = source == .queue && !queued.isEmpty ? queued : library.recipes
        return pool.filter { $0.matches(search) }
    }

    private var trimmedIdea: String { idea.trimmingCharacters(in: .whitespacesAndNewlines) }

    private func addIdea() {
        guard !trimmedIdea.isEmpty else { return }
        Task { await library.plan(text: trimmedIdea, on: day, meal: meal) }
        dismiss()
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                HStack(spacing: 12) {
                    TextField("Or type a meal, like “Eggs” or “Leftovers”", text: $idea)
                        .submitLabel(.done)
                        .onSubmit(addIdea)
                    Button("Add", action: addIdea).disabled(trimmedIdea.isEmpty)
                }
                .padding(.horizontal, 16).padding(.vertical, 10)
                Divider()
                if !queued.isEmpty || !library.upNextNotes.isEmpty {
                    Picker("Source", selection: $source) {
                        ForEach(Source.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented).labelsHidden()
                    .padding(.horizontal, 16).padding(.vertical, 8)
                }
                List {
                    ForEach(notes) { note in
                        Button {
                            Task { await library.plan(note, on: day, meal: meal) }
                            dismiss()
                        } label: { FreeTextRow(title: note.title) }
                        .buttonStyle(.plain)
                    }
                    ForEach(recipes) { recipe in
                        Button {
                            Task { await library.plan(recipe, on: day, meal: meal) }
                            dismiss()
                        } label: { RecipeRow(recipe: recipe) }
                        .buttonStyle(.plain)
                    }
                }
                .listStyle(.plain)
                .overlay {
                    if library.recipes.isEmpty, notes.isEmpty {
                        EmptyLibraryView()
                    } else if recipes.isEmpty, notes.isEmpty {
                        ContentUnavailableView.search(text: search)
                    }
                }
            }
            .searchable(text: $search, prompt: "Search My Recipes")
            .panelTitle(day.formatted(.dateTime.weekday(.wide).month().day()))
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
        .sheetFrame(minWidth: 420, minHeight: 520)
        #endif
    }
}

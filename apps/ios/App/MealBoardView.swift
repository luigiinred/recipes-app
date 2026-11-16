import CoreTransferable
import RecipeKit
import SwiftUI

/// A card on the meal board: a recipe from the library or Up Next, a note in Up Next, or a planned meal.
enum BoardCard: Codable, Hashable, Transferable {
    case recipe(UUID)
    case note(UUID)
    case meal(UUID)

    static var transferRepresentation: some TransferRepresentation {
        CodableRepresentation(contentType: .json)
        ProxyRepresentation(importing: { (item: RecipeDragItem) in BoardCard.recipe(item.id) })
    }
}

/// Up Next and the week as columns beside the library on wide screens, and as a strip of day pills on iPhone.
struct MealBoardView: View {
    @EnvironmentObject private var library: RecipeLibrary
    @EnvironmentObject private var router: AppRouter
    @Environment(\.referenceDate) private var referenceDate
    @Environment(\.appAccent) private var accent
    @Environment(\.appearance) private var appearance
    #if os(iOS)
    @Environment(\.horizontalSizeClass) private var sizeClass
    #endif
    @AppStorage(AppSettings.Key.weekStart) private var weekStartSetting = AppSettings.WeekStart.system.rawValue
    @AppStorage(AppSettings.Key.boardShowsRecipes) private var showsRecipes = true
    let open: (UUID) -> Void

    @State private var weekStart: Date
    @State private var addingOn: Date?
    @State private var addingToUpNext = false
    @State private var smartPlanning: Bool
    @State private var creatingPlan = false
    @State private var openNote: UpNextNote?
    @State private var typedMeal: MealPlanEntry?
    @State private var targetedColumn: String?
    /// The iPhone's selected pill: "upNext" or a day key.
    @State private var page: String?

    init(open: @escaping (UUID) -> Void, showsSmartPlan: Bool = false) {
        self.open = open
        let calendar = AppSettings.calendar()
        _weekStart = State(initialValue: calendar.dateInterval(of: .weekOfYear, for: Date())?.start ?? Date())
        _smartPlanning = State(initialValue: showsSmartPlan)
    }

    private var isCompact: Bool {
        #if os(iOS)
        sizeClass != .regular
        #else
        false
        #endif
    }

    private var calendar: Calendar { AppSettings.calendar(weekStart: weekStartSetting) }
    private var today: Date { calendar.startOfDay(for: referenceDate ?? Date()) }
    private var days: [Date] { (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: weekStart) } }

    private func entries(on day: Date) -> [MealPlanEntry] {
        let key = DayKey.string(from: day, calendar: calendar)
        return library.mealPlan.filter { $0.day == key }.sorted { ($0.meal.order, $0.title) < ($1.meal.order, $1.title) }
    }

    var body: some View {
        Group {
            if isCompact { compactPlanner } else { wideBoard }
        }
        .themedCanvas()
        .animation(.snappy, value: showsRecipes)
        .onAppear { weekStart = calendar.dateInterval(of: .weekOfYear, for: today)?.start ?? today }
        .onChange(of: router.add) { _, target in
            guard target == .plan else { return }
            router.add = nil
            addingOn = today
        }
        .sensoryFeedback(.selection, trigger: targetedColumn) { _, new in new != nil }
        .toolbar {
            ToolbarItem(placement: .navigation) {
                Button { showsRecipes.toggle() } label: {
                    Label(showsRecipes ? "Hide My Recipes" : "Show My Recipes", systemImage: isCompact ? "books.vertical" : "sidebar.leading")
                }
            }
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button("Add to Up Next", systemImage: "text.line.first.and.arrowtriangle.forward") { addingToUpNext = true }
                    Button("Add a Meal Today", systemImage: "calendar.badge.plus") { addingOn = today }
                    Divider()
                    Button("Create a Plan", systemImage: "checklist") { creatingPlan = true }
                    Button("Smart Plan", systemImage: "sparkles") { smartPlanning = true }
                        .disabled(library.recipes.isEmpty)
                } label: { Label("Add", systemImage: "plus") }
            }
        }
        .panel(item: $addingOn) { AddMealSheet(day: $0) }
        .panel(isPresented: $addingToUpNext) { UpNextPickerSheet() }
        .panel(item: $openNote) { FreeTextSheet(item: .note($0), open: open) }
        .panel(item: $typedMeal) { FreeTextSheet(item: .entry($0), open: open) }
        .panel(isPresented: $smartPlanning) { SmartPlanSheet(weekStart: weekStart) }
        .panel(isPresented: $creatingPlan) {
            PlanCreatorSheet(weekStart: weekStart) {
                Task { @MainActor in
                    try? await Task.sleep(for: .milliseconds(400))
                    smartPlanning = true
                }
            }
        }
    }

    private var wideBoard: some View {
        HStack(spacing: 0) {
            if showsRecipes {
                // No hard minimum width: a fixed width here outgrows the window as the sidebar opens, and AppKit aborts.
                BoardRecipesPanel()
                    .frame(minWidth: 0, idealWidth: 296, maxWidth: 296)
                    .transition(.move(edge: .leading).combined(with: .opacity))
                Divider()
            }
            VStack(spacing: 0) {
                WeekBar(weekStart: $weekStart, calendar: calendar, today: today)
                board
            }
            .frame(minWidth: 0, maxWidth: .infinity)
            .clipped()
        }
    }

    private var board: some View {
        ScrollView(.horizontal) {
            HStack(alignment: .top, spacing: 16) {
                upNextColumn.frame(width: 264)
                ForEach(days, id: \.self) { day in
                    dayColumn(day).frame(width: 264)
                }
            }
            .scrollTargetLayout()
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
        }
        .scrollTargetBehavior(.viewAligned)
        .scrollIndicators(.hidden)
        .animation(.snappy, value: library.mealPlan.map(\.id))
        .animation(.snappy, value: library.upNext.map(\.id))
    }

    // MARK: iPhone

    private var selectedPage: String { page ?? DayKey.string(from: days.contains { calendar.isDate($0, inSameDayAs: today) } ? today : weekStart, calendar: calendar) }

    private var compactPlanner: some View {
        VStack(spacing: 0) {
            WeekBar(weekStart: $weekStart, calendar: calendar, today: today)
            dayStrip
            Divider()
            if showsRecipes {
                BoardRecipesPanel()
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            } else {
                pageGrid
            }
        }
        .onChange(of: weekStart) { page = nil }
    }

    private var dayStrip: some View {
        HStack(spacing: 4) {
            pill(id: "upNext", letter: "Next", count: library.upNext.count, isToday: false) {
                Image(systemName: "text.line.first.and.arrowtriangle.forward").appFont(.subheadline, weight: .semibold)
            }
            .dropDestination(for: BoardCard.self) { cards, _ in drop(cards, inUpNextAt: nil) } isTargeted: { target("upNext", $0) }
            .accessibilityLabel("Up Next, \(library.upNext.count)")
            .accessibilityIdentifier("board.upNext")
            ForEach(days, id: \.self) { day in
                let key = DayKey.string(from: day, calendar: calendar)
                pill(id: key, letter: day.formatted(.dateTime.weekday(.narrow)), count: entries(on: day).count,
                     isToday: calendar.isDate(day, inSameDayAs: today)) {
                    Text(day, format: .dateTime.day()).appFont(.headline).monospacedDigit()
                }
                .dropDestination(for: BoardCard.self) { cards, _ in drop(cards, on: day) } isTargeted: { target(key, $0) }
                .accessibilityLabel("\(day.formatted(.dateTime.weekday(.wide).month().day())), \(entries(on: day).count) meals")
                .accessibilityIdentifier("board.day.\(key)")
            }
        }
        .padding(.horizontal, 8)
        .padding(.top, 4)
        .padding(.bottom, 16)
    }

    /// A day as a tall capsule: it grows when picked or when a card hovers over it, and its dots count the meals.
    private func pill(id: String, letter: String, count: Int, isToday: Bool, @ViewBuilder label: () -> some View) -> some View {
        let isSelected = !showsRecipes && selectedPage == id
        let isTargeted = targetedColumn == id
        return Button {
            withAnimation(.snappy) {
                page = id
                showsRecipes = false
            }
        } label: {
            VStack(spacing: 8) {
                Text(letter).appFont(.caption, weight: .semibold)
                    .foregroundStyle(isToday ? AnyShapeStyle(.white) : AnyShapeStyle(.secondary))
                    .frame(minWidth: 22, minHeight: 22)
                    .background { if isToday { Circle().fill(accent) } }
                VStack(spacing: 6) {
                    label()
                    HStack(spacing: 3) {
                        ForEach(0..<min(count, 3), id: \.self) { _ in Circle().frame(width: 5, height: 5) }
                    }
                    .frame(height: 5)
                }
                .foregroundStyle(isSelected ? AnyShapeStyle(.white) : AnyShapeStyle(accent))
                .frame(maxWidth: .infinity, minHeight: 64)
                .background(isSelected ? AnyShapeStyle(accent) : AnyShapeStyle(appearance.surface ?? Color.secondary.opacity(0.12)),
                            in: Capsule(style: .continuous))
                .overlay { Capsule(style: .continuous).strokeBorder(accent, lineWidth: isTargeted ? 2 : 0) }
                .scaleEffect(isTargeted ? 1.18 : isSelected ? 1.08 : 1)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isTargeted)
        .animation(.snappy, value: isSelected)
    }

    private func target(_ id: String, _ isTargeted: Bool) {
        targetedColumn = isTargeted ? id : (targetedColumn == id ? nil : targetedColumn)
    }

    @ViewBuilder
    private var pageGrid: some View {
        let isUpNext = selectedPage == "upNext"
        let day = DayKey.date(from: selectedPage, calendar: calendar)
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(isUpNext ? "Up Next" : day.map { pageTitle(for: $0) } ?? "")
                    .appFont(.title2, weight: .bold)
                    .contentTransition(.numericText())
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 16), GridItem(.flexible(), spacing: 16)], spacing: 16) {
                    if isUpNext {
                        ForEach(Array(library.upNext.enumerated()), id: \.element.id) { index, item in
                            upNextCard(item, tile: true)
                                .dropDestination(for: BoardCard.self) { cards, _ in drop(cards, inUpNextAt: index) }
                        }
                        addTile("Add to Up Next") { addingToUpNext = true }
                    } else if let day {
                        ForEach(entries(on: day)) { mealCard($0, tile: true) }
                        addTile("Add meal") { addingOn = day }
                    }
                }
                if isUpNext ? library.upNext.isEmpty : day.map { entries(on: $0).isEmpty } ?? false {
                    Text("Tap \(Image(systemName: "books.vertical")) and drag a recipe onto a day.")
                        .appFont(.footnote).foregroundStyle(.secondary)
                }
            }
            .padding(16)
        }
        .dropDestination(for: BoardCard.self) { cards, _ in
            if isUpNext { drop(cards, inUpNextAt: nil) } else if let day { drop(cards, on: day) } else { false }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("board.page")
        .animation(.snappy, value: selectedPage)
        .animation(.snappy, value: library.mealPlan.map(\.id))
        .animation(.snappy, value: library.upNext.map(\.id))
    }

    private func pageTitle(for day: Date) -> String {
        if calendar.isDate(day, inSameDayAs: today) { return "Today, \(day.formatted(.dateTime.month(.wide).day()))" }
        if let tomorrow = calendar.date(byAdding: .day, value: 1, to: today), calendar.isDate(day, inSameDayAs: tomorrow) {
            return "Tomorrow, \(day.formatted(.dateTime.month(.wide).day()))"
        }
        return day.formatted(.dateTime.weekday(.wide).month(.wide).day())
    }

    private func addTile(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: "plus").appFont(.title2, weight: .semibold)
                Text(title).appFont(.subheadline, weight: .semibold)
            }
            .foregroundStyle(accent)
            .frame(maxWidth: .infinity)
            .aspectRatio(0.8, contentMode: .fit)
            .background {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(accent.opacity(0.4), style: StrokeStyle(lineWidth: 1.5, dash: [6, 4]))
            }
            .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    // MARK: Up Next

    private var upNextColumn: some View {
        let queue = library.upNext
        return BoardColumn(isTargeted: targetedColumn == "upNext") {
            HStack {
                Label("Up Next", systemImage: "text.line.first.and.arrowtriangle.forward").appFont(.headline)
                Spacer()
                Text("\(queue.count)").appFont(.subheadline).foregroundStyle(.secondary)
            }
            .foregroundStyle(Theme.accent)
        } cards: {
            ForEach(Array(queue.enumerated()), id: \.element.id) { index, item in
                upNextCard(item)
                    .dropDestination(for: BoardCard.self) { cards, _ in
                        drop(cards, inUpNextAt: index)
                    }
            }
            if queue.isEmpty {
                Text("Drag recipes here to cook them soon.").appFont(.footnote).foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 60)
            }
        } footer: {
            addButton("Add") { addingToUpNext = true }
        }
        .dropDestination(for: BoardCard.self) { cards, _ in
            drop(cards, inUpNextAt: nil)
        } isTargeted: { targetedColumn = $0 ? "upNext" : (targetedColumn == "upNext" ? nil : targetedColumn) }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("board.upNext")
    }

    @ViewBuilder
    private func upNextCard(_ item: UpNextItem, tile: Bool = false) -> some View {
        switch item {
        case .recipe(let recipe):
            Button { open(recipe.id) } label: { BoardCardView(recipe: recipe, title: recipe.title, subtitle: nil, tile: tile) }
                .buttonStyle(.plain)
                .accessibilityIdentifier("board.card.\(recipe.title)")
                .draggable(BoardCard.recipe(recipe.id)) { BoardCardView(recipe: recipe, title: recipe.title, subtitle: nil).dragPreviewEnvironment(library, accent: accent, appearance: appearance) }
                .contextMenu {
                    Menu("Plan for", systemImage: "calendar.badge.plus") { dayButtons { day in Task { await library.plan(recipe, on: day, meal: AppSettings.defaultMeal()) } } }
                    Button("Made It", systemImage: "checkmark.circle") { Task { await library.logMade(recipe) } }
                    Divider()
                    Button("Remove from Up Next", systemImage: "minus.circle", role: .destructive) { Task { await library.setQueued(recipe, false) } }
                }
        case .note(let note):
            Button { openNote = note } label: { BoardCardView(recipe: nil, title: note.title, subtitle: "No recipe yet", tile: tile) }
                .buttonStyle(.plain)
                .accessibilityIdentifier("board.card.\(note.title)")
                .draggable(BoardCard.note(note.id)) { BoardCardView(recipe: nil, title: note.title, subtitle: nil).dragPreviewEnvironment(library, accent: accent, appearance: appearance) }
                .contextMenu {
                    Menu("Plan for", systemImage: "calendar.badge.plus") { dayButtons { day in Task { await library.plan(note, on: day, meal: AppSettings.defaultMeal()) } } }
                    Button("Make It an Idea", systemImage: "lightbulb") { Task { await library.makeIdea(from: note) } }
                    Divider()
                    Button("Remove from Up Next", systemImage: "minus.circle", role: .destructive) { Task { await library.remove(note) } }
                }
        }
    }

    // MARK: Days

    private func dayColumn(_ day: Date) -> some View {
        let key = DayKey.string(from: day, calendar: calendar)
        let isToday = calendar.isDate(day, inSameDayAs: today)
        return BoardColumn(isTargeted: targetedColumn == key) {
            HStack(spacing: 6) {
                Text(day, format: .dateTime.weekday(.wide)).appFont(.headline)
                Text(day, format: .dateTime.month(.abbreviated).day()).appFont(.subheadline).foregroundStyle(.secondary)
                Spacer()
                if isToday {
                    Text("Today").appFont(.caption2, weight: .bold).textCase(.uppercase)
                        .padding(.horizontal, 7).padding(.vertical, 2)
                        .background(Theme.accent, in: Capsule()).foregroundStyle(.white)
                }
            }
            .foregroundStyle(isToday ? AnyShapeStyle(Theme.accent) : AnyShapeStyle(.primary))
        } cards: {
            ForEach(entries(on: day)) { mealCard($0) }
        } footer: {
            addButton("Add meal") { addingOn = day }
                .accessibilityLabel("Add meal on \(day.formatted(.dateTime.weekday(.wide)))")
        }
        .dropDestination(for: BoardCard.self) { cards, _ in
            drop(cards, on: day)
        } isTargeted: { targetedColumn = $0 ? key : (targetedColumn == key ? nil : targetedColumn) }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("board.day.\(key)")
    }

    private func mealCard(_ entry: MealPlanEntry, tile: Bool = false) -> some View {
        let recipe = library.recipe(id: entry.recipeID)
        let subtitle = recipe == nil ? "\(entry.meal.title) · No recipe yet" : entry.meal.title
        return Button {
            if let recipe { open(recipe.id) } else { typedMeal = entry }
        } label: { BoardCardView(recipe: recipe, title: entry.title, subtitle: tile ? entry.meal.title : subtitle, symbol: entry.meal.symbol, tile: tile) }
        .buttonStyle(.plain)
        .accessibilityIdentifier("board.card.\(entry.title)")
        .draggable(BoardCard.meal(entry.id)) { BoardCardView(recipe: recipe, title: entry.title, subtitle: nil).dragPreviewEnvironment(library, accent: accent, appearance: appearance) }
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
            Menu("Move to", systemImage: "calendar") { dayButtons { day in move(entry, to: day) } }
            Button("Back to Up Next", systemImage: "text.line.first.and.arrowtriangle.forward") { Task { await library.unplan(entry) } }
            Divider()
            Button("Remove", systemImage: "trash", role: .destructive) { Task { await library.remove(entry) } }
        }
    }

    private func dayButtons(_ action: @escaping (Date) -> Void) -> some View {
        ForEach(days, id: \.self) { day in
            Button(day.formatted(.dateTime.weekday(.wide))) { action(day) }
        }
    }

    private func addButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: "plus").appFont(.subheadline).foregroundStyle(Theme.accent)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: Dropping

    private func drop(_ cards: [BoardCard], inUpNextAt index: Int?) -> Bool {
        guard !cards.isEmpty else { return false }
        Task {
            for card in cards {
                var id: UUID?
                switch card {
                case .recipe(let recipeID):
                    guard let recipe = library.recipe(id: recipeID) else { continue }
                    if !recipe.wantToCook { await library.setQueued(recipe, true) }
                    id = recipeID
                case .note(let noteID):
                    id = noteID
                case .meal(let entryID):
                    guard let entry = library.mealPlan.first(where: { $0.id == entryID }) else { continue }
                    await library.unplan(entry)
                    id = entry.recipeID ?? library.upNextNotes.first { $0.title.localizedCaseInsensitiveCompare(entry.title) == .orderedSame }?.id
                }
                if let id, let index { await library.moveQueued(id, to: index) }
            }
        }
        return true
    }

    private func drop(_ cards: [BoardCard], on day: Date) -> Bool {
        guard !cards.isEmpty else { return false }
        Task {
            for card in cards {
                switch card {
                case .recipe(let id):
                    guard let recipe = library.recipe(id: id) else { continue }
                    await library.plan(recipe, on: day, meal: AppSettings.defaultMeal())
                case .note(let id):
                    guard let note = library.upNextNotes.first(where: { $0.id == id }) else { continue }
                    await library.plan(note, on: day, meal: AppSettings.defaultMeal())
                case .meal(let id):
                    guard let entry = library.mealPlan.first(where: { $0.id == id }) else { continue }
                    move(entry, to: day)
                }
            }
        }
        return true
    }

    private func move(_ entry: MealPlanEntry, to day: Date) {
        let key = DayKey.string(from: day, calendar: calendar)
        guard entry.day != key else { return }
        var changed = entry
        changed.day = key
        Task { await library.update(changed) }
    }
}

private struct BoardColumn<Header: View, Cards: View, Footer: View>: View {
    @Environment(\.appearance) private var appearance
    @Environment(\.appAccent) private var accent
    let isTargeted: Bool
    @ViewBuilder let header: Header
    @ViewBuilder let cards: Cards
    @ViewBuilder let footer: Footer

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            header
            ScrollView {
                VStack(spacing: 8) { cards }
            }
            .scrollIndicators(.never)
            .scrollBounceBehavior(.basedOnSize)
            footer
        }
        .padding(16)
        .frame(maxHeight: .infinity, alignment: .top)
        .background(appearance.surface ?? Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .background(accent.opacity(isTargeted ? 0.14 : 0), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(accent, lineWidth: isTargeted ? 2 : 0)
        }
        .scaleEffect(isTargeted ? 1.015 : 1)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isTargeted)
        .contentShape(Rectangle())
    }
}

private struct BoardCardView: View {
    @Environment(\.appearance) private var appearance
    @Environment(\.appAccent) private var accent
    let recipe: Recipe?
    let title: String
    let subtitle: String?
    var symbol: String?
    var tile = false

    var body: some View {
        if tile { tileBody } else { rowBody }
    }

    /// A photo card: the meal as a chip on top, the title over a scrim at the bottom.
    private var tileBody: some View {
        Color.clear
            .aspectRatio(0.8, contentMode: .fit)
            .overlay {
                if let recipe {
                    RecipeImageView(recipe: recipe)
                } else {
                    accent.opacity(0.14).overlay { Image(systemName: "text.quote").appFont(.title).foregroundStyle(accent) }
                }
            }
            .overlay(alignment: .bottomLeading) {
                Text(title)
                    .appFont(.subheadline, weight: .semibold)
                    .lineLimit(2)
                    .foregroundStyle(recipe == nil ? AnyShapeStyle(.primary) : AnyShapeStyle(.white))
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background {
                        if recipe != nil { LinearGradient(colors: [.clear, .black.opacity(0.6)], startPoint: .top, endPoint: .bottom) }
                    }
            }
            .overlay(alignment: .topLeading) {
                if let subtitle {
                    Label {
                        Text(subtitle)
                    } icon: {
                        if let symbol { Image(systemName: symbol) }
                    }
                    .appFont(.caption, weight: .semibold)
                    .padding(.horizontal, 8).padding(.vertical, 4)
                    .background(.ultraThinMaterial, in: Capsule())
                    .padding(8)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .contentShape(.dragPreview, RoundedRectangle(cornerRadius: 16, style: .continuous))
            .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var rowBody: some View {
        HStack(spacing: 8) {
            Group {
                if let recipe {
                    RecipeImageView(recipe: recipe)
                } else {
                    accent.opacity(0.12).overlay { Image(systemName: "text.quote").foregroundStyle(accent) }
                }
            }
            .frame(width: 44, height: 44)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            VStack(alignment: .leading, spacing: 4) {
                Text(title).appFont(.subheadline, weight: .semibold).lineLimit(2)
                if let subtitle {
                    Label {
                        Text(subtitle)
                    } icon: {
                        if let symbol { Image(systemName: symbol) }
                    }
                    .labelStyle(.titleAndIcon)
                    .appFont(.caption).foregroundStyle(.secondary).lineLimit(1)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(8)
        .background(appearance.canvas ?? Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .contentShape(.dragPreview, RoundedRectangle(cornerRadius: 12, style: .continuous))
        .contentShape(Rectangle())
    }
}

/// The library to drag from. Dropping a board card back here takes it off the board.
private struct BoardRecipesPanel: View {
    @EnvironmentObject private var library: RecipeLibrary
    @Environment(\.appAccent) private var accent
    @Environment(\.appearance) private var appearance
    @State private var search = ""
    @State private var isTargeted = false

    private var recipes: [Recipe] {
        library.recipes.filter { $0.matches(search) }.sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("My Recipes").appFont(.headline).padding(.horizontal, 16).padding(.top, 8)
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                TextField("Search", text: $search).textFieldStyle(.plain)
            }
            .padding(8)
            .background(Color.secondary.opacity(0.12), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .padding(.horizontal, 8).padding(.vertical, 8)
            ScrollView {
                LazyVStack(spacing: 4) {
                    ForEach(recipes) { recipe in
                        row(recipe)
                            .accessibilityElement(children: .combine)
                            .accessibilityIdentifier("board.recipe.\(recipe.title)")
                            .draggable(RecipeDragItem(id: recipe.id)) {
                                BoardCardView(recipe: recipe, title: recipe.title, subtitle: nil).dragPreviewEnvironment(library, accent: accent, appearance: appearance)
                            }
                    }
                }
                .padding(.horizontal, 8).padding(.bottom, 8)
            }
            .overlay {
                if library.recipes.isEmpty { EmptyLibraryView() } else if recipes.isEmpty { ContentUnavailableView.search(text: search) }
            }
        }
        .background { if isTargeted { accent.opacity(0.08) } }
        .dropDestination(for: BoardCard.self) { cards, _ in
            Task {
                for card in cards {
                    switch card {
                    case .recipe(let id): if let recipe = library.recipe(id: id), recipe.wantToCook { await library.setQueued(recipe, false) }
                    case .note(let id): if let note = library.upNextNotes.first(where: { $0.id == id }) { await library.remove(note) }
                    case .meal(let id): await library.removeEntry(id: id)
                    }
                }
            }
            return !cards.isEmpty
        } isTargeted: { isTargeted = $0 }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("board.recipes")
    }

    private func row(_ recipe: Recipe) -> some View {
        HStack(spacing: 8) {
            RecipeImageView(recipe: recipe)
                .frame(width: 44, height: 44)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            Text(recipe.title).appFont(.subheadline).lineLimit(2)
            Spacer(minLength: 0)
            if recipe.wantToCook {
                Image(systemName: "text.line.first.and.arrowtriangle.forward").appFont(.caption).foregroundStyle(accent)
                    .accessibilityLabel("In Up Next")
            }
        }
        .padding(4)
        .frame(minHeight: 48)
        .contentShape(Rectangle())
    }
}

private extension View {
    // A drag preview is drawn outside the window's view tree, so it gets none of the app's environment.
    func dragPreviewEnvironment(_ library: RecipeLibrary, accent: Color, appearance: ThemePalette) -> some View {
        frame(width: 220)
            .environmentObject(library)
            .environment(\.appAccent, accent)
            .environment(\.appearance, appearance)
    }
}

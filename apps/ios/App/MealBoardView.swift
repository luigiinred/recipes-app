import CoreTransferable
import RecipeKit
import SwiftUI
#if os(iOS)
import UIKit
#endif

/// A card on the meal board: a recipe from the library or Up Next, a note in Up Next, or a planned meal.
enum BoardCard: Codable, Hashable, Transferable {
    case recipe(UUID)
    case note(UUID)
    case meal(UUID)
    /// An online search result, planned by its name until its recipe is imported.
    case web(URL, String)

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
    @AppStorage(AppSettings.Key.boardShowsUpNext) private var showsUpNext = true
    /// A Mac window's search lists its results where Up Next sits, so Up Next steps aside while there are any.
    @Environment(\.windowSearchIsShowing) private var windowSearchIsShowing
    let open: (UUID) -> Void

    @State private var weekStart: Date
    @State private var addingOn: Date?
    @State private var addingToUpNext = false
    @State private var smartPlanning: Bool
    @State private var creatingPlan = false
    @State private var openNote: UpNextNote?
    @State private var typedMeal: MealPlanEntry?
    @State private var targetedColumn: String?
    /// The card being dragged, hidden in place so it reads as moving rather than copied.
    @State private var dragging: BoardCard?
    /// The Up Next card a drag hovers over; the gap it lands in opens above it.
    @State private var upNextHover: Int?
    /// The meal a drag hovers over; what's dropped goes just before it.
    @State private var mealHover: UUID?
    /// -1 or 1 while a drag holds at the pager's leading or trailing edge, turning it a day at a time.
    @State private var edgeHover: Int?
    /// The iPhone strip's centered day, which is the one shown.
    @State private var centered: String?
    @State private var strip = ScrollPosition(idType: String.self)
    @State private var stripWidth: CGFloat = 0
    /// How far the pager has scrolled; a day's width of it is a pill's width of the strip, so the strip moves with it rather than after it.
    @State private var pagerX: CGFloat = 0
    @State private var pagerWidth: CGFloat = 0
    @State private var stripX: CGFloat = 0
    @State private var stripMoving = false
    /// While typing a meal on iPhone the Up Next tray steps aside for the keyboard.
    @State private var addingMeal = false
    /// The iPhone's Up Next sheet: low, with a row of cards, or pulled up to show them all.
    @State private var sheetStep = SheetStep.cards
    @State private var sheetHeight: CGFloat = 0
    @State private var bottomInset: CGFloat = 0
    @State private var plannerHeight: CGFloat = 0
    @State private var searchingUpNext = false

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
        return library.mealPlan.filter { $0.day == key }.sorted(by: MealPlanEntry.dayOrder)
    }

    var body: some View {
        Group {
            if isCompact { compactPlanner } else { wideBoard }
        }
        .themedCanvas()
        .onAppear { weekStart = calendar.dateInterval(of: .weekOfYear, for: today)?.start ?? today }
        .onChange(of: router.add) { _, target in
            guard target == .plan else { return }
            router.add = nil
            addingOn = today
        }
        .sensoryFeedback(.selection, trigger: targetedColumn) { _, new in new != nil }
        .toolbar {
            if !isCompact {
                ToolbarItem(placement: .primaryAction) {
                    Button { showsUpNext.toggle() } label: {
                        Label(showsUpNext ? "Hide Up Next" : "Show Up Next", systemImage: "sidebar.trailing")
                    }
                    .help(showsUpNext ? "Hide Up Next" : "Show Up Next")
                }
            }
            // Adding happens in each day and in Up Next; this keeps the week-at-once planners in reach.
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button("Create a Plan", systemImage: "checklist") { creatingPlan = true }
                    Button("Smart Plan", systemImage: "sparkles") { smartPlanning = true }
                        .disabled(library.recipes.isEmpty)
                } label: { Label("Plan My Week", systemImage: "sparkles") }
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

    /// The week fills the window, and Up Next is a column at its trailing edge that can be put away.
    private var wideBoard: some View {
        HStack(spacing: 0) {
            VStack(spacing: 0) {
                WeekBar(weekStart: $weekStart, calendar: calendar, today: today)
                board
            }
            .frame(minWidth: 0, maxWidth: .infinity)
            .clipped()
            if showsUpNext, !windowSearchIsShowing {
                Divider()
                // No hard minimum width: a fixed width here outgrows the window as the sidebar opens, and AppKit aborts.
                upNextColumn
                    .frame(minWidth: 0, idealWidth: 300, maxWidth: 300)
                    .transition(.move(edge: .trailing).combined(with: .opacity))
            }
        }
        .animation(.snappy, value: showsUpNext)
    }

    private var upNextColumn: some View {
        let queue = library.upNext
        return VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Label("Up Next", systemImage: "text.line.first.and.arrowtriangle.forward").appFont(.headline).foregroundStyle(accent)
                Text("\(queue.count)").appFont(.subheadline).foregroundStyle(.secondary)
            }
            upNextQuickAdd
            ScrollView { upNextGrid }
            .scrollIndicators(.never)
        }
        .padding(16)
        .frame(maxHeight: .infinity, alignment: .top)
        .background { accent.opacity(targetedColumn == "upNext" ? 0.1 : 0) }
        .background(.bar)
        .dropDestination(for: BoardCard.self) { cards, _ in
            drop(cards, inUpNextAt: nil)
        } isTargeted: { target("upNext", $0) }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("board.upNext")
        .animation(.snappy, value: queue.map(\.id))
        .animation(.snappy, value: targetedColumn)
        .animation(.snappy, value: upNextHover)
    }

    /// Every Up Next card as a mini photo card, a drop on one landing just before it.
    /// Every Up Next item as a row; a drop on one lands just before it, with a gap opening there.
    private var upNextGrid: some View {
        let queue = library.upNext
        return LazyVStack(spacing: 0) {
            ForEach(Array(queue.enumerated()), id: \.element.id) { index, item in
                VStack(spacing: 0) {
                    if upNextHover == index { DropSlot().padding(.vertical, 4) }
                    upNextCard(item)
                    if index < queue.count - 1 { Divider().padding(.leading, 70) }
                }
                .transition(.asymmetric(
                    insertion: .move(edge: .bottom).combined(with: .opacity)
                        .animation(.spring(response: 0.4, dampingFraction: 0.8).delay(Double(min(index, 12)) * 0.03)),
                    removal: .opacity))
                .dropDestination(for: BoardCard.self) { cards, _ in
                    drop(cards, inUpNextAt: index)
                } isTargeted: { upNextHover = $0 ? index : (upNextHover == index ? nil : upNextHover) }
            }
            if targetedColumn == "upNext" { DropSlot().padding(.vertical, 4) }
            if queue.isEmpty, targetedColumn != "upNext" {
                Text("Drag recipes here, or add one with +, to cook them soon.").appFont(.footnote).foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 60)
            }
        }
    }

    private var upNextQuickAdd: some View {
        QuickAddField(prompt: "Add to Up Next", identifier: "quickAdd.upNext") { recipe in
            if !recipe.wantToCook { Task { await library.setQueued(recipe, true) } }
        } addText: { text in
            Task { await library.queue(text: text) }
        }
    }

    private var board: some View {
        ScrollView(.horizontal) {
            HStack(alignment: .top, spacing: 16) {
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
        .animation(.snappy, value: targetedColumn)
        .animation(.snappy, value: upNextHover)
    }

    // MARK: iPhone

    private var selectedPage: String { centered ?? DayKey.string(from: today, calendar: calendar) }

    /// The Up Next sheet's three heights, as in Maps: its title alone, a row of cards, or every card.
    enum SheetStep: Int {
        case title, cards, all
    }

    private var compactPlanner: some View {
        VStack(spacing: 0) {
            dayStrip
            dayPager
                .padding(.bottom, addingMeal ? 0 : max(0, sheetHeight - bottomInset))
        }
        .overlay(alignment: .bottom) {
            if !addingMeal {
                upNextSheet
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .onGeometryChange(for: CGFloat.self) { $0.safeAreaInsets.bottom } action: { bottomInset = $0 }
        .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { plannerHeight = $0 }
        #if os(iOS)
        .fullScreenCover(isPresented: $searchingUpNext) { UpNextPickerSheet() }
        #endif
    }

    /// Nil lets the title step hug its title; the other steps take a share of the screen.
    private var sheetContentHeight: CGFloat? {
        switch sheetStep {
        case .title: nil
        case .cards: max(220, plannerHeight * 0.42)
        case .all: max(320, plannerHeight * 0.84)
        }
    }

    private func moveSheet(_ step: Int) {
        let next = SheetStep(rawValue: min(max(sheetStep.rawValue + step, 0), SheetStep.all.rawValue)) ?? sheetStep
        withAnimation(.snappy) { sheetStep = next }
    }

    private static let pillWidth: CGFloat = 48
    private static let pillStride: CGFloat = pillWidth + 6
    /// A day is most of the width, centered, so the days either side peek in.
    private var pagerColumnWidth: CGFloat { max(0, pagerWidth * 0.82) }
    private var pagerStride: CGFloat { pagerColumnWidth + 12 }

    /// Keeps the strip at the same fraction of a day as the pager while the pager moves.
    private func followPager() {
        guard !stripMoving, pagerStride > 12 else { return }
        strip.scrollTo(x: pagerX / pagerStride * Self.pillStride)
    }

    /// Weeks either side of today, to swipe through.
    private var stripDays: [Date] { (-35...70).compactMap { calendar.date(byAdding: .day, value: $0, to: today) } }

    /// A strip of days that snaps one to its center; the centered day is the one shown.
    private var dayStrip: some View {
        HStack(spacing: 0) {
            ScrollView(.horizontal) {
                LazyHStack(spacing: 6) {
                    ForEach(Array(stripDays.enumerated()), id: \.element) { index, day in
                        let key = DayKey.string(from: day, calendar: calendar)
                        pill(id: key, focus: pillFocus(index), top: day.formatted(.dateTime.weekday(.abbreviated)), count: entries(on: day).count,
                             isToday: calendar.isDate(day, inSameDayAs: today)) {
                            Text(day, format: .dateTime.day()).appFont(.headline).monospacedDigit()
                        } select: {
                            centered = key
                        }
                        .frame(width: Self.pillWidth)
                        .id(key)
                        .dropDestination(for: BoardCard.self) { cards, _ in drop(cards, on: day) } isTargeted: { target(key, $0) }
                        .accessibilityLabel("\(day.formatted(.dateTime.weekday(.wide).month().day())), \(entries(on: day).count) meals")
                        .accessibilityIdentifier("board.pill.\(key)")
                    }
                }
                .scrollTargetLayout()
                .padding(.vertical, 6)
            }
            .contentMargins(.horizontal, max(0, (stripWidth - Self.pillWidth) / 2), for: .scrollContent)
            .scrollTargetBehavior(.viewAligned)
            .scrollPosition($strip, anchor: .center)
            .scrollIndicators(.hidden)
            .fixedSize(horizontal: false, vertical: true)
            .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { stripWidth = $0 }
            .onScrollGeometryChange(for: CGFloat.self) { $0.contentOffset.x } action: { _, x in stripX = x }
            .onScrollPhaseChange { old, new in
                stripMoving = new == .interacting || new == .decelerating
                // A swipe on the strip picks the day it settles on, and the pager follows.
                if new == .idle, old == .interacting || old == .decelerating {
                    let index = min(max(Int((stripX / Self.pillStride).rounded()), 0), stripDays.count - 1)
                    withAnimation(.snappy) { centered = DayKey.string(from: stripDays[index], calendar: calendar) }
                }
            }
        }
        .padding(.top, 4)
        .padding(.bottom, 8)
        .sensoryFeedback(.selection, trigger: centered)
        .onAppear {
            if centered == nil { centered = DayKey.string(from: today, calendar: calendar) }
            strip.scrollTo(id: selectedPage, anchor: .center)
        }
        .onChange(of: centered) { _, key in
            guard let key, let day = DayKey.date(from: key, calendar: calendar) else { return }
            weekStart = calendar.dateInterval(of: .weekOfYear, for: day)?.start ?? day
        }
    }

    /// A short capsule with its weekday on top; the picked one fills with the accent, and one under a dragged card grows.
    private func pill(id: String, focus: CGFloat, top: String, count: Int, isToday: Bool, @ViewBuilder label: () -> some View,
                      select: @escaping () -> Void) -> some View {
        let isTargeted = targetedColumn == id
        let content = label()
        return Button {
            withAnimation(.snappy) { select() }
        } label: {
            // The plain face, with the picked face over it faded in by how near the pager is to this day,
            // so the highlight slides from day to day as the pager moves instead of jumping when it stops.
            ZStack {
                pillFace(top: top, count: count, isToday: isToday, picked: false) { content }
                pillFace(top: top, count: count, isToday: isToday, picked: true) { content }
                    .opacity(focus)
            }
            .overlay {
                Capsule(style: .continuous).strokeBorder(accent, lineWidth: isTargeted ? 2 : 0)
            }
            .scaleEffect(isTargeted ? 1.15 : 1 + 0.08 * focus)
            .contentShape(Capsule(style: .continuous))
        }
        .buttonStyle(.plain)
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isTargeted)
        .accessibilityAddTraits(selectedPage == id ? .isSelected : [])
    }

    /// 1 for the day the pager is on, falling to 0 a day away, read from how far the pager has scrolled.
    private func pillFocus(_ index: Int) -> CGFloat {
        guard pagerStride > 12 else { return selectedPage == DayKey.string(from: stripDays[index], calendar: calendar) ? 1 : 0 }
        return max(0, 1 - abs(CGFloat(index) - pagerX / pagerStride))
    }

    private func pillFace(top: String, count: Int, isToday: Bool, picked: Bool, @ViewBuilder label: () -> some View) -> some View {
        VStack(spacing: 4) {
            Text(top).appFont(.caption2, weight: .semibold).textCase(.uppercase)
                .foregroundStyle(picked ? AnyShapeStyle(.white.opacity(0.85)) : isToday ? AnyShapeStyle(accent) : AnyShapeStyle(.secondary))
            label()
            HStack(spacing: 3) {
                ForEach(0..<min(count, 3), id: \.self) { _ in Circle().frame(width: 4, height: 4) }
            }
            .frame(height: 4)
        }
        .foregroundStyle(picked ? AnyShapeStyle(.white) : AnyShapeStyle(accent))
        .frame(maxWidth: .infinity, minHeight: 60)
        .background(picked ? AnyShapeStyle(accent) : AnyShapeStyle(appearance.surface ?? Color.secondary.opacity(0.12)),
                    in: Capsule(style: .continuous))
        .overlay {
            if isToday, !picked { Capsule(style: .continuous).strokeBorder(accent, lineWidth: 1) }
        }
    }

    private func target(_ id: String, _ isTargeted: Bool) {
        targetedColumn = isTargeted ? id : (targetedColumn == id ? nil : targetedColumn)
    }

    /// The day columns the Mac shows, one at a time with its neighbors peeking in; the centered one is the strip's.
    private var dayPager: some View {
        // Laid out only once its width is known, so it opens centered on the picked day rather than wherever zero-width columns put it.
        Color.clear
            .overlay { if pagerWidth > 0 { pagerScroll } }
            .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { pagerWidth = $0 }
    }

    private var pagerScroll: some View {
        ScrollView(.horizontal) {
            LazyHStack(spacing: 12) {
                ForEach(stripDays, id: \.self) { day in
                    dayColumn(day)
                        .frame(width: pagerColumnWidth)
                        .id(DayKey.string(from: day, calendar: calendar))
                }
            }
            .scrollTargetLayout()
            .padding(.vertical, 12)
        }
        .scrollPosition(id: $centered, anchor: .center)
        .scrollTargetBehavior(DayPaging(stride: pagerStride, from: pagerX))
        .contentMargins(.horizontal, (pagerWidth - pagerColumnWidth) / 2, for: .scrollContent)
        .scrollIndicators(.hidden)
        .scrollDismissesKeyboard(.immediately)
        .onScrollGeometryChange(for: CGFloat.self) { $0.contentOffset.x } action: { _, x in
            pagerX = x
            followPager()
        }
        .overlay(alignment: .leading) { pagerEdge(-1) }
        .overlay(alignment: .trailing) { pagerEdge(1) }
        .task(id: edgeHover) {
            while let step = edgeHover, !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(550))
                guard !Task.isCancelled, edgeHover == step else { return }
                withAnimation(.snappy) { centered = neighbor(of: selectedPage, by: step) }
            }
        }
        .sensoryFeedback(.selection, trigger: edgeHover) { _, new in new != nil }
        .animation(.snappy, value: library.mealPlan.map(\.id))
        .animation(.snappy, value: targetedColumn)
        .animation(.snappy, value: mealHover)
    }

    /// Holding a dragged card here turns the pager toward that side; letting go drops it on the day in the middle.
    private func pagerEdge(_ step: Int) -> some View {
        Color.clear
            .frame(width: 28)
            .frame(maxHeight: .infinity)
            .contentShape(Rectangle())
            .allowsHitTesting(dragging != nil || targetedColumn != nil || edgeHover != nil)
            .dropDestination(for: BoardCard.self) { cards, _ in
                edgeHover = nil
                guard let day = DayKey.date(from: selectedPage, calendar: calendar) else { return false }
                return drop(cards, on: day)
            } isTargeted: { on in
                edgeHover = on ? step : (edgeHover == step ? nil : edgeHover)
            }
            .accessibilityHidden(true)
    }

    private func neighbor(of key: String, by step: Int) -> String {
        guard let day = DayKey.date(from: key, calendar: calendar),
              let next = calendar.date(byAdding: .day, value: step, to: day) else { return key }
        return DayKey.string(from: next, calendar: calendar)
    }

    // MARK: Up Next

    /// Up Next sits under the plan as a shelf to drag from, unlike the days above it.
    /// Up Next on iPhone: a glass sheet over the bottom of the plan, like Find My's. Low, it shows a row of cards;
    /// pulled up, all of them. Cards drag both ways between it and the days.
    private var upNextSheet: some View {
        let queue = library.upNext
        return VStack(alignment: .leading, spacing: 10) {
            VStack(spacing: 6) {
                Capsule().fill(.secondary.opacity(0.5)).frame(width: 36, height: 5)
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text("Up Next").appFont(.title2, weight: .bold)
                    if !queue.isEmpty { Text("\(queue.count)").appFont(.headline).foregroundStyle(.secondary) }
                    Spacer(minLength: 8)
                    if sheetStep != .title {
                        Button { searchingUpNext = true } label: {
                            Image(systemName: "plus")
                                .appFont(.title3, weight: .semibold)
                                .frame(width: 44, height: 44)
                        }
                        .buttonStyle(.plain)
                        .glassEffect(.regular.interactive(), in: Circle())
                        .accessibilityLabel("Add to Up Next")
                        .alignmentGuide(.firstTextBaseline) { $0[VerticalAlignment.center] + 6 }
                        .transition(.scale.combined(with: .opacity))
                    }
                }
            }
            .padding(.top, 8)
            .contentShape(Rectangle())
            .onTapGesture { withAnimation(.snappy) { sheetStep = sheetStep == .title ? .cards : .title } }
            .gesture(DragGesture(minimumDistance: 12).onEnded { value in
                withAnimation(.snappy) {
                    if value.translation.height < -30 { moveSheet(1) } else if value.translation.height > 30 { moveSheet(-1) }
                }
            })
            if sheetStep != .title {
                // The header moves the sheet, so a card can still be pressed and dragged out; pulling past the top of the cards lowers it.
                ScrollView { upNextGrid }
                    .scrollIndicators(.never)
                    .scrollDismissesKeyboard(.immediately)
                    .onScrollGeometryChange(for: Bool.self) { $0.contentOffset.y + $0.contentInsets.top < -40 } action: { _, pulled in
                        if pulled { moveSheet(-1) }
                    }
                    .frame(maxHeight: .infinity, alignment: .top)
                    .transition(.opacity)
            }
        }
        // Each step has its own height, as a Maps sheet does; the cards fill whatever the step gives them.
        .frame(height: sheetContentHeight, alignment: .top)
        .padding(.horizontal, 20)
        // Down to the bottom of the screen, like Maps: the content clears the home indicator, or the tab bar, which then sits inside the sheet.
        .padding(.bottom, max(bottomInset, 12))
        .background {
            ZStack {
                Color.clear.contentShape(Rectangle()).onTapGesture(perform: dismissKeyboard)
                RoundedRectangle(cornerRadius: 40, style: .continuous)
                    .fill(accent.opacity(targetedColumn == "upNext" ? 0.12 : 0))
            }
            .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 40, style: .continuous))
        }
        .padding(.horizontal, 8)
        .padding(.bottom, 8)
        .ignoresSafeArea(edges: .bottom)
        .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { if sheetStep != .all { sheetHeight = $0 } }
        .dropDestination(for: BoardCard.self) { cards, _ in
            drop(cards, inUpNextAt: nil)
        } isTargeted: { target("upNext", $0) }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("board.upNext")
        .animation(.snappy, value: queue.map(\.id))
        .animation(.snappy, value: targetedColumn)
        .animation(.snappy, value: upNextHover)
    }

    @ViewBuilder
    private func upNextCard(_ item: UpNextItem, tile: Bool = false) -> some View {
        switch item {
        case .recipe(let recipe):
            Button { open(recipe.id) } label: { BoardCardView(recipe: recipe, title: recipe.title, subtitle: nil, tile: tile) }
                .buttonStyle(.plain)
                .accessibilityIdentifier("board.card.\(recipe.title)")
                .movable(.recipe(recipe.id), dragging: $dragging, collapses: !tile) { BoardCardView(recipe: recipe, title: recipe.title, subtitle: nil).dragPreviewEnvironment(library, accent: accent, appearance: appearance) }
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
                .movable(.note(note.id), dragging: $dragging, collapses: !tile) { BoardCardView(recipe: nil, title: note.title, subtitle: nil).dragPreviewEnvironment(library, accent: accent, appearance: appearance) }
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
            ForEach(Meal.allCases, id: \.self) { meal in mealSection(meal, on: day) }
            if entries(on: day).isEmpty, targetedColumn != key, dragging == nil {
                Text("Nothing planned yet. Type a meal, or drag one in from Up Next.")
                    .appFont(.footnote)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        } footer: {
            quickAdd(on: day)
        }
        .dropDestination(for: BoardCard.self) { cards, _ in
            drop(cards, on: day)
        } isTargeted: { targetedColumn = $0 ? key : (targetedColumn == key ? nil : targetedColumn) }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("board.day.\(key)")
    }

    /// A meal's rows under its name. Empty meals only show while something is being dragged, as places to drop it.
    @ViewBuilder
    private func mealSection(_ meal: Meal, on day: Date) -> some View {
        let meals = entries(on: day).filter { $0.meal == meal }
        let sectionKey = "\(DayKey.string(from: day, calendar: calendar))/\(meal.rawValue)"
        if !meals.isEmpty || dragging != nil || targetedColumn == sectionKey {
            VStack(alignment: .leading, spacing: 0) {
                Label(meal.title, systemImage: meal.symbol)
                    .appFont(.caption, weight: .bold)
                    .textCase(.uppercase)
                    .foregroundStyle(.secondary)
                    .padding(.top, 6)
                    .padding(.bottom, 2)
                ForEach(Array(meals.enumerated()), id: \.element.id) { index, entry in
                    VStack(spacing: 0) {
                        if mealHover == entry.id { DropSlot().padding(.vertical, 4) }
                        mealCard(entry)
                        if index < meals.count - 1 { Divider().padding(.leading, 70) }
                    }
                    .dropDestination(for: BoardCard.self) { cards, _ in drop(cards, on: day, before: entry) } isTargeted: { hoverMeal(entry.id, $0) }
                }
                if targetedColumn == sectionKey || (meals.isEmpty && dragging != nil) {
                    DropSlot().padding(.vertical, 4).opacity(targetedColumn == sectionKey ? 1 : 0.5)
                }
            }
            .contentShape(Rectangle())
            .dropDestination(for: BoardCard.self) { cards, _ in drop(cards, on: day, meal: meal) } isTargeted: { target(sectionKey, $0) }
        }
    }

    private func mealCard(_ entry: MealPlanEntry, tile: Bool = false) -> some View {
        let recipe = library.recipe(id: entry.recipeID)
        let subtitle: String? = recipe == nil ? "No recipe yet" : nil
        return Button {
            if let recipe { open(recipe.id) } else { typedMeal = entry }
        } label: { BoardCardView(recipe: recipe, title: entry.title, subtitle: tile ? entry.meal.title : subtitle, symbol: tile ? entry.meal.symbol : nil, tile: tile) }
        .buttonStyle(.plain)
        .accessibilityIdentifier("board.card.\(entry.title)")
        .movable(.meal(entry.id), dragging: $dragging, collapses: !tile) { BoardCardView(recipe: recipe, title: entry.title, subtitle: nil).dragPreviewEnvironment(library, accent: accent, appearance: appearance) }
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

    /// Small photo cards, as many to a row as fit.
    private static let miniColumns = [GridItem(.adaptive(minimum: 92), spacing: 8)]

    private func quickAdd(on day: Date) -> some View {
        QuickAddField(prompt: "Add a meal", identifier: "quickAdd.day.\(DayKey.string(from: day, calendar: calendar))",
                      onFocusChange: { focused in withAnimation(.snappy) { addingMeal = focused && isCompact } }) { recipe in
            Task { await library.plan(recipe, on: day, meal: AppSettings.defaultMeal()) }
        } addText: { text in
            Task { await library.plan(text: text, on: day, meal: AppSettings.defaultMeal()) }
        }
    }

    private func hoverMeal(_ id: UUID, _ isTargeted: Bool) {
        mealHover = isTargeted ? id : (mealHover == id ? nil : mealHover)
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
                case .web(let url, let title):
                    await library.queue(importing: url, title: title, at: index)
                }
                if let id, let index { await library.moveQueued(id, to: index) }
            }
        }
        return true
    }

    /// Drops on a day, just before `target` when one's under the drag, else after the rest of its kind of meal.
    private func drop(_ cards: [BoardCard], on day: Date, before target: MealPlanEntry? = nil, meal chosen: Meal? = nil) -> Bool {
        guard !cards.isEmpty else { return false }
        let meal = target?.meal ?? chosen ?? AppSettings.defaultMeal()
        Task {
            for card in cards {
                switch card {
                case .recipe(let id):
                    guard let recipe = library.recipe(id: id) else { continue }
                    await library.plan(recipe, on: day, meal: meal, before: target)
                case .note(let id):
                    guard let note = library.upNextNotes.first(where: { $0.id == id }) else { continue }
                    await library.plan(note, on: day, meal: meal, before: target)
                case .meal(let id):
                    guard let entry = library.mealPlan.first(where: { $0.id == id }) else { continue }
                    if let chosen, target == nil {
                        var retimed = entry
                        retimed.meal = chosen
                        await library.place(retimed, on: DayKey.string(from: day, calendar: calendar), before: nil)
                    } else if target == nil { move(entry, to: day) } else { await library.place(entry, on: DayKey.string(from: day, calendar: calendar), before: target) }
                case .web(let url, let title):
                    await library.plan(importing: url, title: title, on: day, meal: meal, before: target)
                }
            }
        }
        return true
    }

    private func move(_ entry: MealPlanEntry, to day: Date) {
        let key = DayKey.string(from: day, calendar: calendar)
        guard entry.day != key else { return }
        Task { await library.place(entry, on: key, before: nil) }
    }
}

/// Where a dragged card will land.
private struct DropSlot: View {
    @Environment(\.appAccent) private var accent
    var tile = false

    var body: some View {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
            .fill(accent.opacity(0.1))
            .strokeBorder(accent.opacity(0.6), style: StrokeStyle(lineWidth: 1.5, dash: [6, 4]))
            .frame(height: tile ? nil : 60)
            .aspectRatio(tile ? 0.8 : nil, contentMode: .fit)
            .transition(.scale(scale: 0.9).combined(with: .opacity))
            .accessibilityHidden(true)
    }
}

private extension View {
    /// Drags `card`, leaving no copy behind: the card hides while it's lifted, and in a column its space closes up.
    func movable(_ card: BoardCard, dragging: Binding<BoardCard?>, collapses: Bool, @ViewBuilder preview: @escaping () -> some View) -> some View {
        let lifted = dragging.wrappedValue == card
        return opacity(lifted ? 0 : 1)
            .frame(height: lifted && collapses ? 0 : nil)
            .clipped()
            .draggable(card, preview: preview)
            .modifier(DragTracking(card: card, dragging: dragging))
            .animation(.snappy, value: lifted)
    }
}

/// Older systems can't follow a drag session, so there the card stays put while its preview moves.
private struct DragTracking: ViewModifier {
    let card: BoardCard
    @Binding var dragging: BoardCard?

    func body(content: Content) -> some View {
        if #available(iOS 27.0, macOS 26.0, *) {
            content.onDragSessionUpdated { session in
                switch session.phase {
                case .initial, .active: if dragging != card { dragging = card }
                default: if dragging == card { dragging = nil }
                }
            }
        } else {
            content
        }
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
            // The add field follows the meals rather than sitting at the column's foot, so a short day reads top to bottom
            // and stays in view when the Up Next sheet covers the lower half.
            ScrollView {
                VStack(spacing: 8) {
                    cards
                    footer
                }
            }
            .scrollIndicators(.never)
            .scrollBounceBehavior(.basedOnSize)
            .scrollDismissesKeyboard(.immediately)
        }
        .padding(16)
        .frame(maxHeight: .infinity, alignment: .top)
        .background { Color.clear.contentShape(Rectangle()).onTapGesture(perform: dismissKeyboard) }
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
                    accent.opacity(0.14).overlay { Image(systemName: "text.quote").appFont(.title3).foregroundStyle(accent) }
                }
            }
            .overlay(alignment: .bottomLeading) {
                Text(title)
                    .appFont(.footnote, weight: .semibold)
                    .lineLimit(2)
                    .foregroundStyle(recipe == nil ? AnyShapeStyle(.primary) : AnyShapeStyle(.white))
                    .padding(8)
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
                    .appFont(.caption2, weight: .semibold)
                    .padding(.horizontal, 6).padding(.vertical, 3)
                    .background(.ultraThinMaterial, in: Capsule())
                    .padding(6)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .zoomSource(recipe, cornerRadius: 16)
            .contentShape(.dragPreview, RoundedRectangle(cornerRadius: 16, style: .continuous))
            .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    /// A list row like the App Store's: picture, title, and the meal or a note under it.
    private var rowBody: some View {
        ThumbnailRow(title: title, thumbnailSize: 52) {
            Group {
                if let recipe {
                    RecipeImageView(recipe: recipe)
                } else {
                    accent.opacity(0.12).overlay { Image(systemName: "text.quote").foregroundStyle(accent) }
                }
            }
            .zoomSource(recipe, cornerRadius: 12)
        } subtitle: {
            if let subtitle {
                Label {
                    Text(subtitle)
                } icon: {
                    if let symbol { Image(systemName: symbol) }
                }
                .labelStyle(.titleAndIcon)
            }
        }
        .padding(.horizontal, 4)
        .background(appearance.surface ?? Color.clear)
        .contentShape(.dragPreview, RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

private extension View {
    @ViewBuilder
    func zoomSource(_ recipe: Recipe?, cornerRadius: CGFloat) -> some View {
        if let recipe { recipeZoomSource(recipe.id, in: "board", cornerRadius: cornerRadius) } else { self }
    }
}

extension View {
    // A drag preview is drawn outside the window's view tree, so it gets none of the app's environment.
    func dragPreviewEnvironment(_ library: RecipeLibrary, accent: Color, appearance: ThemePalette) -> some View {
        frame(width: 220)
            .environmentObject(library)
            .environment(\.appAccent, accent)
            .environment(\.appearance, appearance)
    }
}

/// Puts the keyboard away; a tap on the board's empty space calls it, so any field closes the way it opened.
@MainActor
func dismissKeyboard() {
    #if os(iOS)
    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    #endif
}

/// A page per day: a swipe always comes to rest on a day, and on the one next to where it started, never between two.
private struct DayPaging: ScrollTargetBehavior {
    let stride: CGFloat
    let from: CGFloat

    func updateTarget(_ target: inout ScrollTarget, context: TargetContext) {
        guard stride > 0 else { return }
        var page = (target.rect.minX / stride).rounded()
        // Only a swipe is held to one day; a jump to a day, as when the pager opens on today, lands where it's aimed.
        if context.velocity != .zero {
            let here = (from / stride).rounded()
            page = min(max(page, here - 1), here + 1)
        }
        target.rect.origin.x = max(0, page * stride)
    }
}


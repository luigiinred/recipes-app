import RecipeKit
import SwiftUI
import WidgetKit

// MARK: - Timeline

struct SnapshotEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetSnapshot
    let store: WidgetStore?
}

struct SnapshotProvider: TimelineProvider {
    enum Cadence { case daily, sixHours }
    let cadence: Cadence

    func placeholder(in context: Context) -> SnapshotEntry { SnapshotEntry(date: Date(), snapshot: .sample, store: nil) }

    func getSnapshot(in context: Context, completion: @escaping (SnapshotEntry) -> Void) {
        completion(context.isPreview ? placeholder(in: context) : entry(at: Date()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<SnapshotEntry>) -> Void) {
        let calendar = Calendar.current
        let now = Date()
        var dates = [now]
        switch cadence {
        case .daily:
            let midnight = calendar.nextDate(after: now, matching: DateComponents(hour: 0, minute: 0), matchingPolicy: .nextTime) ?? now.addingTimeInterval(86_400)
            dates.append(midnight)
        case .sixHours:
            let hour = calendar.component(.hour, from: now)
            let start = calendar.date(bySettingHour: hour / 6 * 6, minute: 0, second: 0, of: now) ?? now
            dates += (1...4).compactMap { calendar.date(byAdding: .hour, value: 6 * $0, to: start) }
        }
        completion(Timeline(entries: dates.map(entry(at:)), policy: .after(dates.last ?? now)))
    }

    private func entry(at date: Date) -> SnapshotEntry {
        let store = WidgetStore.shared
        return SnapshotEntry(date: date, snapshot: store?.load() ?? .empty, store: store)
    }
}

extension WidgetSnapshot {
    static let sample = WidgetSnapshot(
        meals: [
            .init(id: UUID(), recipeID: nil, title: "Lemon pasta", day: DayKey.string(from: Date()), meal: .dinner),
            .init(id: UUID(), recipeID: nil, title: "Overnight oats", day: DayKey.string(from: Date()), meal: .breakfast),
        ],
        upNext: [
            .init(id: UUID(), title: "Chicken tikka masala", minutes: 45),
            .init(id: UUID(), title: "Banana bread", minutes: 70),
            .init(id: UUID(), title: "Green curry", minutes: 30),
        ],
        toBuy: [.init(id: UUID(), name: "Milk", quantity: "1 L"), .init(id: UUID(), name: "Eggs", quantity: "12"), .init(id: UUID(), name: "Basil")],
        pool: [.init(id: UUID(), title: "Weeknight ramen", minutes: 25)]
    )
}

// MARK: - Shared pieces

private func widgetAccent(of snapshot: WidgetSnapshot) -> Color {
    guard let hex = snapshot.accentHex, hex.count == 6, let value = UInt32(hex, radix: 16) else {
        return Color(red: 0.86, green: 0.28, blue: 0.22)
    }
    return Color(red: Double(value >> 16 & 0xFF) / 255, green: Double(value >> 8 & 0xFF) / 255, blue: Double(value & 0xFF) / 255)
}

private func duration(_ minutes: Int) -> String {
    minutes < 60 ? "\(minutes) min" : minutes % 60 == 0 ? "\(minutes / 60) hr" : "\(minutes / 60) hr \(minutes % 60) min"
}

private struct Header: View {
    let title: String
    let symbol: String
    let accent: Color
    var detail: String?

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: symbol).foregroundStyle(accent)
            Text(title).foregroundStyle(accent)
            Spacer(minLength: 0)
            if let detail { Text(detail).foregroundStyle(.secondary) }
        }
        .font(.caption.weight(.semibold))
        .lineLimit(1)
    }
}

private struct DishPhoto: View {
    let dish: WidgetSnapshot.Dish
    let store: WidgetStore?

    var body: some View {
        if dish.hasImage, let store, let image = UIImage(contentsOfFile: store.imageURL(for: dish.id).path) {
            Image(uiImage: image).resizable().scaledToFill()
        } else {
            ZStack {
                Rectangle().fill(.quaternary)
                Image(systemName: "fork.knife").foregroundStyle(.secondary)
            }
        }
    }
}

private struct Empty: View {
    let symbol: String
    let message: String

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: symbol).font(.title2).foregroundStyle(.secondary)
            Text(message).font(.caption).foregroundStyle(.secondary).multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private enum Destination {
    static let plan = URL(string: "recipes://plan")!
    static let groceries = URL(string: "recipes://groceries")!
}

/// A recipe tap target where the family allows one (small widgets only take `widgetURL`).
private struct RecipeLinkView<Content: View>: View {
    let id: UUID?
    @ViewBuilder let content: Content

    var body: some View {
        if let id { Link(destination: RecipeLink.url(for: id)) { content } } else { content }
    }
}

// MARK: - Meal plan

struct MealPlanWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "MealPlanWidget", provider: SnapshotProvider(cadence: .daily)) { entry in
            MealPlanView(entry: entry).containerBackground(.background, for: .widget).widgetURL(Destination.plan)
        }
        .configurationDisplayName("Meal Plan")
        .description("What you plan to eat today and the days ahead.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge, .accessoryRectangular])
    }
}

private struct MealPlanView: View {
    @Environment(\.widgetFamily) private var family
    let entry: SnapshotEntry

    private var accent: Color { widgetAccent(of: entry.snapshot) }
    private var calendar: Calendar { .current }

    private func day(_ offset: Int) -> Date {
        calendar.date(byAdding: .day, value: offset, to: calendar.startOfDay(for: entry.date)) ?? entry.date
    }

    var body: some View {
        switch family {
        case .accessoryRectangular:
            VStack(alignment: .leading, spacing: 2) {
                Text("Today").font(.caption.weight(.semibold))
                let meals = entry.snapshot.meals(on: day(0), calendar: calendar)
                if meals.isEmpty {
                    Text("Nothing planned").font(.caption).foregroundStyle(.secondary)
                } else {
                    ForEach(meals.prefix(2)) { Text($0.title).font(.caption).lineLimit(1) }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        case .systemMedium:
            HStack(alignment: .top, spacing: 14) {
                column(offset: 0, limit: 3)
                Divider()
                column(offset: 1, limit: 3)
            }
        case .systemLarge:
            VStack(alignment: .leading, spacing: 10) {
                Header(title: "Meal Plan", symbol: "calendar", accent: accent)
                ForEach(0..<5, id: \.self) { offset in
                    HStack(alignment: .firstTextBaseline, spacing: 10) {
                        Text(label(for: offset)).font(.subheadline.weight(.semibold))
                            .foregroundStyle(offset == 0 ? accent : .primary).frame(width: 64, alignment: .leading)
                        meals(offset: offset, limit: 3)
                    }
                    if offset < 4 { Divider() }
                }
                Spacer(minLength: 0)
            }
        default:
            column(offset: 0, limit: 3)
        }
    }

    private func label(for offset: Int) -> String {
        offset == 0 ? "Today" : day(offset).formatted(.dateTime.weekday(.abbreviated).day())
    }

    private func column(offset: Int, limit: Int) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Header(title: offset == 0 ? "Today" : "Tomorrow", symbol: "calendar", accent: accent, detail: day(offset).formatted(.dateTime.weekday(.abbreviated).day()))
            meals(offset: offset, limit: limit)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func meals(offset: Int, limit: Int) -> some View {
        let meals = entry.snapshot.meals(on: day(offset), calendar: calendar)
        VStack(alignment: .leading, spacing: 5) {
            if meals.isEmpty {
                Text("Nothing planned").font(.subheadline).foregroundStyle(.secondary)
            } else {
                ForEach(meals.prefix(limit)) { meal in
                    RecipeLinkView(id: family == .systemSmall ? nil : meal.recipeID) {
                        HStack(spacing: 6) {
                            Image(systemName: meal.meal.symbol).font(.caption).foregroundStyle(accent).frame(width: 16)
                            Text(meal.title).font(.subheadline).lineLimit(1)
                        }
                    }
                }
                if meals.count > limit { Text("+\(meals.count - limit) more").font(.caption).foregroundStyle(.secondary) }
            }
        }
    }
}

// MARK: - Up Next

struct UpNextWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "UpNextWidget", provider: SnapshotProvider(cadence: .daily)) { entry in
            UpNextView(entry: entry).containerBackground(.background, for: .widget).widgetURL(Destination.plan)
        }
        .configurationDisplayName("Up Next")
        .description("The recipes you lined up to cook soon.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge, .accessoryRectangular])
    }
}

private struct UpNextView: View {
    @Environment(\.widgetFamily) private var family
    let entry: SnapshotEntry

    private var accent: Color { widgetAccent(of: entry.snapshot) }
    private var queue: [WidgetSnapshot.Dish] { entry.snapshot.upNext }

    var body: some View {
        switch family {
        case .accessoryRectangular:
            VStack(alignment: .leading, spacing: 2) {
                Text("Up Next").font(.caption.weight(.semibold))
                if queue.isEmpty {
                    Text("Nothing lined up").font(.caption).foregroundStyle(.secondary)
                } else {
                    ForEach(queue.prefix(2)) { Text($0.title).font(.caption).lineLimit(1) }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        case .systemSmall:
            VStack(alignment: .leading, spacing: 6) {
                Header(title: "Up Next", symbol: "text.line.first.and.arrowtriangle.forward", accent: accent)
                if queue.isEmpty {
                    Empty(symbol: "text.line.first.and.arrowtriangle.forward", message: "Swipe a recipe to line it up")
                } else {
                    ForEach(queue.prefix(3)) { Text($0.title).font(.subheadline.weight(.medium)).lineLimit(2) }
                    Spacer(minLength: 0)
                }
            }
        default:
            let limit = family == .systemLarge ? 6 : 3
            let photo: CGFloat = family == .systemLarge ? 40 : 32
            VStack(alignment: .leading, spacing: 6) {
                Header(title: "Up Next", symbol: "text.line.first.and.arrowtriangle.forward", accent: accent, detail: queue.isEmpty ? nil : "\(queue.count)")
                if queue.isEmpty {
                    Empty(symbol: "text.line.first.and.arrowtriangle.forward", message: "Swipe a recipe left in your library to line it up")
                } else {
                    ForEach(queue.prefix(limit)) { dish in
                        RecipeLinkView(id: dish.id) {
                            HStack(spacing: 10) {
                                DishPhoto(dish: dish, store: entry.store)
                                    .frame(width: photo, height: photo).clipShape(RoundedRectangle(cornerRadius: 8))
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(dish.title).font(.subheadline.weight(.medium)).lineLimit(1)
                                    if let minutes = dish.minutes { Text(duration(minutes)).font(.caption).foregroundStyle(.secondary) }
                                }
                                Spacer(minLength: 0)
                            }
                        }
                    }
                    Spacer(minLength: 0)
                }
            }
        }
    }
}

// MARK: - Groceries

struct GroceriesWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "GroceriesWidget", provider: SnapshotProvider(cadence: .daily)) { entry in
            GroceriesView(entry: entry).containerBackground(.background, for: .widget).widgetURL(Destination.groceries)
        }
        .configurationDisplayName("Groceries")
        .description("What is left on your shopping list.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge, .accessoryRectangular, .accessoryCircular])
    }
}

private struct GroceriesView: View {
    @Environment(\.widgetFamily) private var family
    let entry: SnapshotEntry

    private var accent: Color { widgetAccent(of: entry.snapshot) }
    private var items: [WidgetSnapshot.Item] { entry.snapshot.toBuy }

    var body: some View {
        switch family {
        case .accessoryCircular:
            VStack(spacing: 0) {
                Image(systemName: "checklist").font(.caption)
                Text("\(items.count)").font(.title3.weight(.semibold))
            }
        case .accessoryRectangular:
            VStack(alignment: .leading, spacing: 2) {
                Text(items.isEmpty ? "Groceries" : "\(items.count) to buy").font(.caption.weight(.semibold))
                if items.isEmpty {
                    Text("All set").font(.caption).foregroundStyle(.secondary)
                } else {
                    ForEach(items.prefix(2)) { Text($0.name).font(.caption).lineLimit(1) }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        default:
            let limit = family == .systemSmall ? 4 : family == .systemMedium ? 6 : 14
            let columns = family == .systemSmall ? 1 : 2
            VStack(alignment: .leading, spacing: 8) {
                Header(title: "Groceries", symbol: "checklist", accent: accent, detail: items.isEmpty ? nil : "\(items.count) to buy")
                if items.isEmpty {
                    Empty(symbol: "cart", message: entry.snapshot.checkedCount > 0 ? "Everything is checked off" : "Nothing to buy")
                } else {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), alignment: .topLeading), count: columns), alignment: .leading, spacing: 6) {
                        ForEach(items.prefix(limit)) { item in
                            HStack(spacing: 6) {
                                Image(systemName: "circle").font(.caption).foregroundStyle(accent)
                                Text(item.quantity.isEmpty ? item.name : "\(item.name) · \(item.quantity)")
                                    .font(.subheadline).lineLimit(1)
                            }
                        }
                    }
                    if items.count > limit { Text("+\(items.count - limit) more").font(.caption).foregroundStyle(.secondary) }
                    Spacer(minLength: 0)
                }
            }
        }
    }
}

// MARK: - Random recipe

struct RandomRecipeWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "RandomRecipeWidget", provider: SnapshotProvider(cadence: .sixHours)) { entry in
            RandomRecipeView(entry: entry).containerBackground(for: .widget) { RandomBackground(entry: entry) }
        }
        .configurationDisplayName("Random Recipe")
        .description("A recipe from your library, changing through the day.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
        .contentMarginsDisabled()
    }
}

private struct RandomBackground: View {
    let entry: SnapshotEntry

    var body: some View {
        if let dish = entry.snapshot.randomDish(at: entry.date) {
            DishPhoto(dish: dish, store: entry.store)
        } else {
            Color(.secondarySystemBackground)
        }
    }
}

private struct RandomRecipeView: View {
    let entry: SnapshotEntry

    var body: some View {
        if let dish = entry.snapshot.randomDish(at: entry.date) {
            VStack(alignment: .leading, spacing: 2) {
                Spacer(minLength: 0)
                Text("Try this").font(.caption2.weight(.semibold)).textCase(.uppercase).foregroundStyle(.white.opacity(0.8))
                Text(dish.title).font(.headline).lineLimit(2).foregroundStyle(.white)
                if let minutes = dish.minutes { Text(duration(minutes)).font(.caption).foregroundStyle(.white.opacity(0.8)) }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(LinearGradient(colors: [.clear, .black.opacity(0.65)], startPoint: .center, endPoint: .bottom))
            .widgetURL(RecipeLink.url(for: dish.id))
        } else {
            Empty(symbol: "fork.knife", message: "Add recipes to see one here")
        }
    }
}

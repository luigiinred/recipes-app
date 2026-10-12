import RecipeKit
import SwiftUI

enum DrawerSort: String, CaseIterable {
    case title, newest, quickest, category

    var title: String {
        switch self {
        case .title: "Name"
        case .newest: "Recently Added"
        case .quickest: "Quickest"
        case .category: "Category"
        }
    }
}

enum DrawerFilter: String, CaseIterable {
    case all, favorites, wantToCook

    func title(for style: RatingStyle) -> String {
        switch self {
        case .all: "All"
        case .favorites: style == .stars ? "Top Rated" : "Favorites"
        case .wantToCook: "Up Next"
        }
    }
}

/// Every recipe in one searchable, sortable column. Drag a recipe onto the planner; drop a planned meal here to take it off.
struct RecipeDrawer: View {
    @EnvironmentObject private var library: RecipeLibrary
    @Binding var mode: CalendarMode?
    var showsClose = false
    var onClose: () -> Void = {}
    /// When set, tapping a recipe picks it (the add sheet); dragging still works either way.
    var onSelect: ((Recipe) -> Void)?

    @State private var search = ""
    @State private var sort = DrawerSort.title
    @State private var filter = DrawerFilter.all
    @AppStorage(AppSettings.Key.ratingStyle) private var ratingStyleRaw = RatingStyle.favorites.rawValue
    @State private var removeTargeted = false

    private var recipes: [Recipe] {
        var list = library.recipes.filter { $0.matches(search) }
        switch filter {
        case .all: break
        case .favorites:
            list = (RatingStyle(rawValue: ratingStyleRaw) ?? .favorites) == .stars ? RecipeCollection.topRated.filter(list) : list.filter(\.isFavorite)
        case .wantToCook: list = RecipeCollection.wantToCook.filter(list)
        }
        switch sort {
        case .title: return list
        case .newest: return list.sorted { $0.createdAt > $1.createdAt }
        case .quickest: return list.sorted { ($0.totalMinutes ?? .max) < ($1.totalMinutes ?? .max) }
        case .category:
            return list.sorted { (CategoryTree.displayName($0.tags.first ?? "~"), $0.title) < (CategoryTree.displayName($1.tags.first ?? "~"), $1.title) }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 8) {
                HStack {
                    Text("Recipes").font(.system(.title3, design: .serif, weight: .bold))
                    Spacer()
                    Menu {
                        Picker("Sort by", selection: $sort) {
                            ForEach(DrawerSort.allCases, id: \.self) { Text($0.title).tag($0) }
                        }
                    } label: { Label("Sort", systemImage: "arrow.up.arrow.down") }
                    .labelStyle(.iconOnly)
                    .menuStyle(.borderlessButton)
                    .fixedSize()
                    if showsClose {
                        Button(action: onClose) { Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary) }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Close")
                    }
                }
                Picker("Filter", selection: $filter) {
                    ForEach(DrawerFilter.allCases, id: \.self) { Text($0.title(for: RatingStyle(rawValue: ratingStyleRaw) ?? .favorites)).tag($0) }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                TextField("Search", text: $search)
                    .textFieldStyle(.roundedBorder)
            }
            .padding(12)
            List(recipes) { recipe in
                Button { onSelect?(recipe) } label: { DrawerRow(recipe: recipe) }
                    .buttonStyle(.plain)
                    .allowsHitTesting(onSelect != nil)
                    .draggable(PlannerPayload(kind: .recipe, id: recipe.id))
                    .listRowInsets(EdgeInsets(top: 4, leading: 12, bottom: 4, trailing: 12))
            }
            .listStyle(.plain)
            .overlay(alignment: .bottom) { removeHint }
        }
        .background(removeTargeted ? Theme.accent.opacity(0.08) : Color.clear)
        .dropDestination(for: PlannerPayload.self) { items, _ in
            let entryIDs = items.filter { $0.kind == .entry }.map(\.id)
            guard !entryIDs.isEmpty else { return false }
            Task { for id in entryIDs { await library.removeEntry(id: id) } }
            return true
        } isTargeted: { removeTargeted = $0 }
        .toolbar {
            if mode != nil {
                ToolbarItem(placement: .primaryAction) { CalendarModeButton(mode: Binding(get: { mode ?? .planner }, set: { mode = $0 })) }
            }
        }
    }

    @ViewBuilder
    private var removeHint: some View {
        if removeTargeted {
            Label("Drop to remove from the calendar", systemImage: "minus.circle.fill")
                .font(.footnote.weight(.semibold))
                .padding(.horizontal, 12).padding(.vertical, 8)
                .glassEffect(.regular.tint(Theme.accent.opacity(0.4)), in: Capsule())
                .padding(10)
        }
    }
}

struct DrawerRow: View {
    let recipe: Recipe

    var body: some View {
        HStack(spacing: 10) {
            RecipeImageView(recipe: recipe)
                .frame(width: 44, height: 44)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            VStack(alignment: .leading, spacing: 2) {
                Text(recipe.title).font(.system(.subheadline, design: .serif, weight: .semibold)).lineLimit(2)
                if let minutes = recipe.totalMinutes {
                    Text("\(minutes) min").font(.caption).foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 0)
            Image(systemName: "line.3.horizontal").font(.caption).foregroundStyle(.tertiary)
        }
        .contentShape(Rectangle())
    }
}

import RecipeKit
import SwiftUI

struct GroceriesView: View {
    enum Layout { case combined, toBuy, completed }

    @EnvironmentObject private var library: RecipeLibrary
    @EnvironmentObject private var router: AppRouter
    let layout: Layout
    var embedded = false

    @State private var newItem = ""
    @FocusState private var addingItem: Bool
    /// Checked off but still in place, struck through, for a moment before moving to Completed; a second tap keeps it.
    @State private var lingering: Set<GroceryItem.ID> = []
    @AppStorage(AppSettings.Key.groceryGrouping) private var grouping = GroceryGrouping.none
    @ObservedObject private var aisles = GroceryAisles.shared

    private struct Group: Identifiable {
        let id: String
        let title: String
        let items: [GroceryItem]
    }

    /// To Buy split by aisle, in store order, or by the recipe each item came from, with hand-added ones last.
    private var groups: [Group] {
        switch grouping {
        case .none:
            return [Group(id: "all", title: "", items: toBuy)]
        case .aisle:
            let byAisle = Dictionary(grouping: toBuy) { aisles.aisle(for: $0) }
            return GroceryAisle.allCases.compactMap { aisle in
                byAisle[aisle].map { Group(id: aisle.rawValue, title: aisle.title, items: $0) }
            }
        case .recipe:
            let byRecipe = Dictionary(grouping: toBuy) { $0.recipeID.flatMap { library.recipe(id: $0)?.title } ?? "" }
            return byRecipe.keys.sorted { $0.isEmpty ? false : $1.isEmpty ? true : $0.localizedCompare($1) == .orderedAscending }
                .map { Group(id: "recipe-\($0)", title: $0.isEmpty ? "Added by Hand" : $0, items: byRecipe[$0] ?? []) }
        }
    }

    private var toBuy: [GroceryItem] { sorted(library.groceries.filter { !$0.isChecked }) }
    private var completed: [GroceryItem] { sorted(library.groceries.filter(\.isChecked)) }

    var body: some View {
        List {
            if layout != .completed {
                if grouping == .none {
                    section(embedded ? "To Buy" : nil) {
                        ForEach(toBuy) { row($0) }
                        addField
                    }
                } else {
                    ForEach(groups) { group in
                        Section(group.title) { ForEach(group.items) { row($0) } }
                    }
                    Section { addField }
                }
            }
            if layout != .toBuy, !completed.isEmpty || layout == .completed {
                section(layout == .combined || embedded ? "Completed" : nil) {
                    ForEach(completed) { row($0) }
                }
            }
            if addingItem {
                // The empty space under the list, so a tap there puts the keyboard away.
                Color.clear
                    .frame(height: 400)
                    .contentShape(Rectangle())
                    .onTapGesture { addingItem = false }
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                    .accessibilityHidden(true)
            }
        }
        .listStyle(.plain)
        .scrollDismissesKeyboard(.immediately)
        .themedCanvas()
        .animation(.snappy, value: toBuy.map(\.id) + completed.map(\.id))
        .animation(.snappy, value: grouping)
        .task(id: grouping == .aisle ? toBuy.map(\.name) : []) {
            if grouping == .aisle { await aisles.sortUnknown(toBuy) }
        }
        .onChange(of: router.add) { _, target in
            guard target == .groceries, layout != .completed else { return }
            router.add = nil
            addingItem = true
        }
        .overlay {
            if layout == .completed, completed.isEmpty {
                EmptyStateView(symbol: "checkmark.circle", title: "Nothing completed", message: "Things you check off end up here.")
            } else if layout == .toBuy, toBuy.isEmpty {
                EmptyStateView(symbol: "cart", title: "Nothing to buy", message: "Add ingredients from any recipe.")
            }
        }
        .modifier(GroceriesChrome(embedded: embedded, title: layout == .completed ? "Completed" : "Groceries", showsMenu: layout != .completed))
    }

    @ViewBuilder
    private func section(_ title: String?, @ViewBuilder content: () -> some View) -> some View {
        if let title {
            Section(title) { content() }
        } else {
            Section { content() }
        }
    }

    private func sorted(_ items: [GroceryItem]) -> [GroceryItem] {
        items.sorted { ($0.createdAt, $0.name) < ($1.createdAt, $1.name) }
    }

    private func addItem() {
        let text = newItem.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        newItem = ""
        Task { await library.addGroceries([GroceryItem(parsing: text)]) }
    }

    private var addField: some View {
        TextField("Add item", text: $newItem)
            .focused($addingItem)
            .onSubmit(addItem)
            .submitLabel(.next)
            .themedRow()
            .accessibilityIdentifier("groceries.add")
    }

    private func toggle(_ item: GroceryItem) {
        if item.isChecked {
            Task { await library.setChecked(item, false) }
        } else if lingering.contains(item.id) {
            lingering.remove(item.id)
        } else {
            lingering.insert(item.id)
            Task {
                try? await Task.sleep(for: .seconds(2))
                guard lingering.remove(item.id) != nil else { return }
                await library.setChecked(item, true)
            }
        }
    }

    private func row(_ item: GroceryItem) -> some View {
        Button {
            // While typing, a tap on the list only puts the keyboard away.
            if addingItem { addingItem = false; return }
            toggle(item)
        } label: {
            let checked = item.isChecked || lingering.contains(item.id)
            HStack(spacing: 12) {
                Image(systemName: checked ? "checkmark.circle.fill" : "circle")
                    .appFont(.title3)
                    .foregroundStyle(checked ? AnyShapeStyle(Theme.accent) : AnyShapeStyle(.secondary))
                    .contentTransition(.symbolEffect(.replace))
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.name).appFont(.body, weight: .medium).strikethrough(checked)
                    if !item.quantity.isEmpty {
                        Text(item.quantity).appFont(.caption, weight: .bold).foregroundStyle(Theme.accent).strikethrough(checked)
                    }
                }
                .foregroundStyle(checked ? .secondary : .primary)
                .animation(.snappy, value: checked)
                Spacer()
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .themedRow()
        .contextMenu {
            Button("Delete", role: .destructive) { Task { await library.remove(item) } }
        }
        .swipeActions {
            Button("Delete", role: .destructive) { Task { await library.remove(item) } }
        }
    }
}

struct AddToGroceriesSheet: View {
    @EnvironmentObject private var library: RecipeLibrary
    @SheetDismiss private var dismiss
    let recipe: Recipe

    @State private var skipped: Set<Int> = []

    var body: some View {
        NavigationStack {
            List(Array(recipe.ingredients.enumerated()), id: \.offset) { index, text in
                let parts = IngredientParser.split(text)
                Button {
                    if !skipped.insert(index).inserted { skipped.remove(index) }
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: skipped.contains(index) ? "circle" : "checkmark.circle.fill")
                            .appFont(.title3)
                            .foregroundStyle(skipped.contains(index) ? AnyShapeStyle(Color.secondary) : AnyShapeStyle(Theme.accent))
                        VStack(alignment: .leading, spacing: 2) {
                            Text(parts.name).appFont(.body, weight: .medium)
                            if !parts.quantity.isEmpty {
                                Text(parts.quantity).appFont(.caption, weight: .bold).foregroundStyle(Theme.accent)
                            }
                        }
                        Spacer()
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            .panelTitle("Groceries")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { CancelButton() }
                ToolbarItem(placement: .confirmationAction) {
                    ConfirmButton(title: "Add to Groceries") {
                        let items = recipe.ingredients.enumerated()
                            .filter { !skipped.contains($0.offset) }
                            .map { GroceryItem(parsing: $0.element, recipeID: recipe.id) }
                        Task { await library.addGroceries(items) }
                        dismiss()
                    }
                }
            }
        }
        #if os(macOS)
        .sheetFrame(minWidth: 420, minHeight: 480)
        #endif
    }
}

private struct GroceriesChrome: ViewModifier {
    let embedded: Bool
    let title: String
    let showsMenu: Bool

    func body(content: Content) -> some View {
        if embedded {
            content
        } else {
            content
                .navigationTitle(title)
                .toolbar { if showsMenu { GroceriesMenu() } }
        }
    }
}

struct GroceriesMenu: ToolbarContent {
    @EnvironmentObject private var library: RecipeLibrary
    @AppStorage(AppSettings.Key.groceryGrouping) private var grouping = GroceryGrouping.none
    @State private var confirmingClearAll = false

    var body: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            Menu("Groceries Options", systemImage: "ellipsis") {
                Picker(selection: $grouping) {
                    ForEach(GroceryGrouping.allCases, id: \.self) { Text($0.title).tag($0) }
                } label: {
                    Label("Group By", systemImage: "rectangle.3.group")
                }
                .pickerStyle(.menu)
                Divider()
                Button("Clear Completed", systemImage: "checkmark.circle") {
                    Task { await library.clearCompleted() }
                }
                .disabled(!library.groceries.contains(where: \.isChecked))
                Button("Clear All", systemImage: "trash", role: .destructive) {
                    confirmingClearAll = true
                }
                .disabled(library.groceries.isEmpty)
            }
            .confirmationDialog("Clear the whole grocery list?", isPresented: $confirmingClearAll, titleVisibility: .visible) {
                Button("Clear All", role: .destructive) { Task { await library.clearAllGroceries() } }
            } message: {
                Text("This removes every item, including ones not yet bought.")
            }
        }
    }
}

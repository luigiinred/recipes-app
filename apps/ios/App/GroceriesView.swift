import RecipeKit
import SwiftUI

struct GroceriesView: View {
    enum Layout { case combined, toBuy, completed }

    @EnvironmentObject private var library: RecipeLibrary
    let layout: Layout
    var embedded = false

    @State private var newItem = ""

    private var toBuy: [GroceryItem] { sorted(library.groceries.filter { !$0.isChecked }) }
    private var completed: [GroceryItem] { sorted(library.groceries.filter(\.isChecked)) }

    var body: some View {
        List {
            if layout != .completed {
                section(embedded ? "To Buy" : nil) {
                    TextField("Add item", text: $newItem)
                        .onSubmit(addItem)
                        .themedRow()
                    ForEach(toBuy) { row($0) }
                }
            }
            if layout != .toBuy, !completed.isEmpty || layout == .completed {
                section(layout == .combined || embedded ? "Completed" : nil) {
                    ForEach(completed) { row($0) }
                }
            }
        }
        .listStyle(.plain)
        .themedCanvas()
        .animation(.snappy, value: toBuy.map(\.id) + completed.map(\.id))
        .overlay {
            if layout == .completed, completed.isEmpty {
                MascotEmptyState(scene: .idle, title: "Nothing completed", message: "Things you check off end up here.")
            } else if layout == .toBuy, toBuy.isEmpty {
                MascotEmptyState(scene: .hop, title: "Nothing to buy", message: "Add ingredients from any recipe.")
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

    private func row(_ item: GroceryItem) -> some View {
        Button {
            Task { await library.setChecked(item, !item.isChecked) }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: item.isChecked ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(item.isChecked ? AnyShapeStyle(Theme.accent) : AnyShapeStyle(.secondary))
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.name).font(.system(.body, weight: .medium))
                    if !item.quantity.isEmpty {
                        Text(item.quantity).font(.caption.weight(.bold)).foregroundStyle(Theme.accent)
                    }
                }
                .foregroundStyle(item.isChecked ? .secondary : .primary)
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
    @Environment(\.dismiss) private var dismiss
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
                            .font(.title3)
                            .foregroundStyle(skipped.contains(index) ? AnyShapeStyle(Color.secondary) : AnyShapeStyle(Theme.accent))
                        VStack(alignment: .leading, spacing: 2) {
                            Text(parts.name).font(.system(.body, weight: .medium))
                            if !parts.quantity.isEmpty {
                                Text(parts.quantity).font(.caption.weight(.bold)).foregroundStyle(Theme.accent)
                            }
                        }
                        Spacer()
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            .navigationTitle("Groceries")
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
        .frame(minWidth: 420, minHeight: 480)
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
    @State private var confirmingClearAll = false

    var body: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            Menu("Groceries Options", systemImage: "ellipsis.circle") {
                Button("Clear Completed", systemImage: "checkmark.circle") {
                    Task { await library.clearCompleted() }
                }
                .disabled(!library.groceries.contains(where: \.isChecked))
                Button("Clear All", systemImage: "trash", role: .destructive) {
                    confirmingClearAll = true
                }
                .disabled(library.groceries.isEmpty)
                if library.remindersStatus != .unavailable {
                    Divider()
                    Toggle("Sync with Reminders", systemImage: "checklist", isOn: Binding(
                        get: { library.remindersEnabled },
                        set: { value in Task { await library.setRemindersEnabled(value) } }
                    ))
                }
            }
            .confirmationDialog("Clear the whole grocery list?", isPresented: $confirmingClearAll, titleVisibility: .visible) {
                Button("Clear All", role: .destructive) { Task { await library.clearAllGroceries() } }
            } message: {
                Text("This removes every item, including ones not yet bought.")
            }
        }
    }
}

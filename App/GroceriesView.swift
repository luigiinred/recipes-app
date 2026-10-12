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
                Section(embedded ? "To Buy" : "") {
                    TextField("Add item", text: $newItem)
                        .onSubmit(addItem)
                    ForEach(toBuy) { row($0) }
                }
            }
            if layout != .toBuy, !completed.isEmpty || layout == .completed {
                Section(layout == .combined || embedded ? "Completed" : "") {
                    ForEach(completed) { row($0) }
                }
            }
        }
        .listStyle(.plain)
        .overlay {
            if layout == .completed, completed.isEmpty {
                ContentUnavailableView("Nothing completed", systemImage: "checkmark.circle")
            } else if layout == .toBuy, toBuy.isEmpty {
                ContentUnavailableView("Nothing to buy", systemImage: "checklist",
                                       description: Text("Add ingredients from any recipe."))
            }
        }
        .safeAreaInset(edge: .bottom) {
            if layout != .completed, !embedded { RemindersStatusBar() }
        }
        .modifier(GroceriesChrome(embedded: embedded, title: layout == .completed ? "Completed" : "Groceries", showsClear: layout != .toBuy))
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
                    .foregroundStyle(item.isChecked ? Theme.accent : .secondary)
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
                            .foregroundStyle(skipped.contains(index) ? Color.secondary : Theme.accent)
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
    let showsClear: Bool

    func body(content: Content) -> some View {
        if embedded {
            content
        } else {
            content
                .navigationTitle(title)
                .toolbar { if showsClear { ClearCompletedButton() } }
        }
    }
}

struct ClearCompletedButton: ToolbarContent {
    @EnvironmentObject private var library: RecipeLibrary

    var body: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            Button("Clear Completed", systemImage: "checkmark.circle") {
                Task { await library.clearCompleted() }
            }
            .disabled(!library.groceries.contains(where: \.isChecked))
        }
    }
}

struct RemindersStatusBar: View {
    @EnvironmentObject private var library: RecipeLibrary

    var body: some View {
        if library.remindersStatus != .unavailable {
            HStack(spacing: 10) {
                Image(systemName: icon).foregroundStyle(tint)
                Text(message).font(.footnote).foregroundStyle(.secondary).lineLimit(2)
                Spacer(minLength: 0)
                if let action {
                    Button(action.title) { Task { await library.setRemindersEnabled(action.enable) } }
                        .font(.footnote.weight(.semibold))
                        .buttonStyle(.plain)
                        .foregroundStyle(Theme.accent)
                }
            }
            .padding(.horizontal, 16).padding(.vertical, 10)
            .background(.bar)
        }
    }

    private var icon: String {
        switch library.remindersStatus {
        case .synced, .syncing: "checklist.checked"
        case .failed, .denied: "exclamationmark.triangle.fill"
        default: "checklist"
        }
    }

    private var tint: Color {
        switch library.remindersStatus {
        case .failed, .denied: .orange
        case .synced: Theme.accent
        default: .secondary
        }
    }

    private var message: String {
        switch library.remindersStatus {
        case .unavailable: ""
        case .off: "Not syncing with the Reminders app."
        case .needsAccess: "Allow access to sync this list with Reminders."
        case .denied: "Reminders access is off. Allow it in Settings to sync."
        case .syncing: "Syncing with Reminders…"
        case .synced: "Synced with the “Groceries” list in Reminders."
        case .failed(let reason): "Couldn't sync with Reminders: \(reason)"
        }
    }

    private var action: (title: String, enable: Bool)? {
        switch library.remindersStatus {
        case .off: ("Turn On", true)
        case .synced, .syncing: ("Turn Off", false)
        default: nil
        }
    }
}

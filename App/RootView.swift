import RecipeKit
import SwiftUI

struct RootView: View {
    @EnvironmentObject private var library: RecipeLibrary
    @State private var tag: String?
    @State private var selection: Recipe.ID?
    @State private var search = ""
    @State private var editing: Recipe?
    @State private var showingNew = false
    @State private var showingImport = false

    private var visible: [Recipe] {
        library.recipes.filter { recipe in
            (tag == nil || recipe.tags.contains(tag!)) && recipe.matches(search)
        }
    }

    var body: some View {
        NavigationSplitView {
            sidebar
        } content: {
            recipeList
        } detail: {
            if let recipe = library.recipes.first(where: { $0.id == selection }) {
                RecipeDetailView(recipe: recipe, onEdit: { editing = recipe })
                    .id(recipe.id)
            } else {
                ContentUnavailableView("Select a recipe", systemImage: "fork.knife")
            }
        }
        .task { await library.run() }
        .sheet(isPresented: $showingNew) {
            RecipeEditorView(recipe: Recipe(title: "")) { saved in
                Task { await library.save(saved) }
                selection = saved.id
            }
        }
        .sheet(isPresented: $showingImport) {
            ImportURLView { saved in
                Task { await library.save(saved) }
                selection = saved.id
            }
        }
        .sheet(item: $editing) { recipe in
            RecipeEditorView(recipe: recipe) { saved in
                Task { await library.save(saved) }
            }
        }
    }

    private var sidebar: some View {
        List(selection: $tag) {
            Label("All Recipes", systemImage: "book.closed").tag(String?.none)
            if !library.tags.isEmpty {
                Section("Collections") {
                    ForEach(library.tags, id: \.self) { name in
                        Label(name, systemImage: "tag").tag(String?.some(name))
                    }
                }
            }
        }
        .navigationTitle("Recipes")
        .safeAreaInset(edge: .bottom) {
            Label(library.isICloud ? "Synced with iCloud" : "Stored on this device",
                  systemImage: library.isICloud ? "icloud" : "internaldrive")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(8)
        }
    }

    private var recipeList: some View {
        List(selection: $selection) {
            ForEach(visible) { recipe in
                RecipeRow(recipe: recipe)
                    .tag(recipe.id)
                    .contextMenu {
                        Button("Edit") { editing = recipe }
                        Button("Delete", role: .destructive) { Task { await library.delete(recipe) } }
                    }
            }
            .onDelete { offsets in
                let doomed = offsets.map { visible[$0] }
                Task { for recipe in doomed { await library.delete(recipe) } }
            }
        }
        .overlay {
            if library.recipes.isEmpty {
                ContentUnavailableView("No recipes yet", systemImage: "fork.knife",
                                       description: Text("Tap + to add one, or use the recipes command-line tool."))
            } else if visible.isEmpty {
                ContentUnavailableView.search(text: search)
            }
        }
        .searchable(text: $search, prompt: "Search recipes")
        .navigationTitle(tag ?? "All Recipes")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button("New Recipe", systemImage: "square.and.pencil") { showingNew = true }
                    Button("Import from Web…", systemImage: "globe") { showingImport = true }
                } label: { Label("Add Recipe", systemImage: "plus") }
            }
        }
    }
}

struct RecipeRow: View {
    let recipe: Recipe

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(recipe.title)
                .font(.system(.headline, design: .serif))
            if !recipe.summary.isEmpty {
                Text(recipe.summary).font(.subheadline).foregroundStyle(.secondary).lineLimit(2)
            }
            if let minutes = recipe.totalMinutes {
                Label("\(minutes) min", systemImage: "clock").font(.caption).foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 3)
    }
}

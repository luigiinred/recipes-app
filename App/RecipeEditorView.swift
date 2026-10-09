import RecipeKit
import SwiftUI

struct RecipeEditorView: View {
    @Environment(\.dismiss) private var dismiss
    let original: Recipe
    let onSave: (Recipe) -> Void

    @State private var title: String
    @State private var summary: String
    @State private var servings: String
    @State private var prep: String
    @State private var cook: String
    @State private var ingredients: String
    @State private var steps: String
    @State private var tags: String
    @State private var source: String
    @State private var notes: String

    init(recipe: Recipe, onSave: @escaping (Recipe) -> Void) {
        original = recipe
        self.onSave = onSave
        _title = State(initialValue: recipe.title)
        _summary = State(initialValue: recipe.summary)
        _servings = State(initialValue: recipe.servings.map(String.init) ?? "")
        _prep = State(initialValue: recipe.prepMinutes.map(String.init) ?? "")
        _cook = State(initialValue: recipe.cookMinutes.map(String.init) ?? "")
        _ingredients = State(initialValue: recipe.ingredients.joined(separator: "\n"))
        _steps = State(initialValue: recipe.steps.joined(separator: "\n"))
        _tags = State(initialValue: recipe.tags.joined(separator: ", "))
        _source = State(initialValue: recipe.sourceURL ?? "")
        _notes = State(initialValue: recipe.notes)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Title", text: $title)
                    TextField("Summary", text: $summary, axis: .vertical)
                }
                Section {
                    TextField("Servings", text: $servings)
                    TextField("Prep minutes", text: $prep)
                    TextField("Cook minutes", text: $cook)
                    TextField("Tags (comma separated)", text: $tags)
                }
                Section("Ingredients — one per line") { editor($ingredients, minHeight: 140) }
                Section("Steps — one per line") { editor($steps, minHeight: 180) }
                Section {
                    TextField("Source URL", text: $source)
                    TextField("Notes", text: $notes, axis: .vertical)
                }
            }
            .formStyle(.grouped)
            .navigationTitle(original.title.isEmpty ? "New Recipe" : "Edit Recipe")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        #if os(macOS)
        .frame(minWidth: 520, minHeight: 640)
        #endif
    }

    private func editor(_ text: Binding<String>, minHeight: CGFloat) -> some View {
        TextEditor(text: text).frame(minHeight: minHeight)
    }

    private func lines(_ text: String) -> [String] {
        text.split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    private func save() {
        var recipe = original
        recipe.title = title
        recipe.summary = summary
        recipe.servings = Int(servings)
        recipe.prepMinutes = Int(prep)
        recipe.cookMinutes = Int(cook)
        recipe.ingredients = lines(ingredients)
        recipe.steps = lines(steps)
        recipe.tags = tags.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        let trimmedSource = source.trimmingCharacters(in: .whitespaces)
        recipe.sourceURL = trimmedSource.isEmpty ? nil : trimmedSource
        recipe.notes = notes
        onSave(recipe)
        dismiss()
    }
}

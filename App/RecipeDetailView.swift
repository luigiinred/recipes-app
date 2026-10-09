import RecipeKit
import SwiftUI

struct RecipeDetailView: View {
    @EnvironmentObject private var library: RecipeLibrary
    let recipe: Recipe
    let onEdit: () -> Void

    @State private var checkedIngredients: Set<Int> = []
    @State private var doneSteps: Set<Int> = []
    @State private var confirmingDelete = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                header
                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .top, spacing: 40) {
                        ingredients.frame(maxWidth: 320, alignment: .leading)
                        steps
                    }
                    VStack(alignment: .leading, spacing: 28) {
                        ingredients
                        steps
                    }
                }
                if !recipe.notes.isEmpty {
                    section("Notes") { Text(recipe.notes).foregroundStyle(.secondary) }
                }
                if let source = recipe.sourceURL, let url = URL(string: source) {
                    Link(destination: url) { Label(url.host ?? source, systemImage: "link") }
                }
            }
            .padding(24)
            .frame(maxWidth: 900, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .navigationTitle(recipe.title)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            ToolbarItemGroup {
                ShareLink(item: recipe.markdown)
                Button("Edit", systemImage: "pencil", action: onEdit)
                Button("Delete", systemImage: "trash") { confirmingDelete = true }
            }
        }
        .confirmationDialog("Delete \"\(recipe.title)\"?", isPresented: $confirmingDelete) {
            Button("Delete", role: .destructive) { Task { await library.delete(recipe) } }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(recipe.title).font(.system(.largeTitle, design: .serif, weight: .bold))
            if !recipe.summary.isEmpty {
                Text(recipe.summary).font(.title3).foregroundStyle(.secondary)
            }
            HStack(spacing: 16) {
                if let servings = recipe.servings { Label("\(servings) servings", systemImage: "person.2") }
                if let prep = recipe.prepMinutes { Label("Prep \(prep) min", systemImage: "knife") }
                if let cook = recipe.cookMinutes { Label("Cook \(cook) min", systemImage: "flame") }
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)
            if !recipe.tags.isEmpty {
                HStack {
                    ForEach(recipe.tags, id: \.self) { tag in
                        Text(tag)
                            .font(.caption.weight(.medium))
                            .padding(.horizontal, 10).padding(.vertical, 4)
                            .background(Theme.accent.opacity(0.12), in: Capsule())
                            .foregroundStyle(Theme.accent)
                    }
                }
            }
        }
    }

    private var ingredients: some View {
        section("Ingredients") {
            VStack(alignment: .leading, spacing: 12) {
                ForEach(Array(recipe.ingredients.enumerated()), id: \.offset) { index, text in
                    Button { toggle(&checkedIngredients, index) } label: {
                        HStack(alignment: .firstTextBaseline, spacing: 10) {
                            Image(systemName: checkedIngredients.contains(index) ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(checkedIngredients.contains(index) ? Theme.accent : .secondary)
                            Text(text)
                                .strikethrough(checkedIngredients.contains(index))
                                .foregroundStyle(checkedIngredients.contains(index) ? .secondary : .primary)
                                .multilineTextAlignment(.leading)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var steps: some View {
        section("Steps") {
            VStack(alignment: .leading, spacing: 18) {
                ForEach(Array(recipe.steps.enumerated()), id: \.offset) { index, text in
                    Button { toggle(&doneSteps, index) } label: {
                        HStack(alignment: .firstTextBaseline, spacing: 12) {
                            Text("\(index + 1)")
                                .font(.headline)
                                .foregroundStyle(.white)
                                .frame(width: 26, height: 26)
                                .background(doneSteps.contains(index) ? Color.secondary : Theme.accent, in: Circle())
                            Text(text)
                                .font(.system(.body, design: .serif))
                                .foregroundStyle(doneSteps.contains(index) ? .secondary : .primary)
                                .multilineTextAlignment(.leading)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title.uppercased()).font(.caption.weight(.semibold)).foregroundStyle(.secondary).tracking(1)
            content()
        }
    }

    private func toggle(_ set: inout Set<Int>, _ index: Int) {
        if !set.insert(index).inserted { set.remove(index) }
    }
}

import RecipeKit
import SwiftUI

/// Type to add: pick one of your recipes as it's suggested, or press Return to keep the words as they are.
struct QuickAddField: View {
    @EnvironmentObject private var library: RecipeLibrary
    @Environment(\.appAccent) private var accent
    let prompt: String
    var identifier: String?
    var onFocusChange: ((Bool) -> Void)?
    var focusesOnAppear = false
    let addRecipe: (Recipe) -> Void
    let addText: (String) -> Void
    @State private var text = ""
    @FocusState private var isFocused: Bool

    private var typed: String { text.trimmingCharacters(in: .whitespacesAndNewlines) }

    private var suggestions: [Recipe] {
        guard !typed.isEmpty else { return [] }
        return Array(library.recipes.filter { $0.matches(typed) }
            .sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
            .prefix(4))
    }

    var body: some View {
        // Suggestions open upward: the field sits at the foot of a day and in the tray at the bottom of the screen.
        VStack(alignment: .leading, spacing: 4) {
            if isFocused, !typed.isEmpty {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(suggestions) { recipe in
                        option(recipe.title, systemImage: "book.closed") { add(recipe) }
                    }
                    option("Add “\(typed)”", systemImage: "text.cursor") { addWords() }
                }
                .padding(4)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
            HStack(spacing: 8) {
                Image(systemName: "plus").appFont(.subheadline, weight: .semibold).foregroundStyle(accent)
                TextField(prompt, text: $text)
                    .textFieldStyle(.plain)
                    .appFont(.subheadline)
                    .focused($isFocused)
                    .accessibilityIdentifier(identifier ?? prompt)
                    .submitLabel(.done)
                    .onSubmit(submit)
            }
            .padding(.horizontal, 12)
            .frame(minHeight: 44)
            .background(Color.secondary.opacity(0.1), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .onTapGesture { isFocused = true }
        }
        .animation(.snappy, value: isFocused && !typed.isEmpty)
        .onChange(of: isFocused) { _, focused in onFocusChange?(focused) }
        .onAppear { if focusesOnAppear { isFocused = true } }
    }

    private func option(_ title: String, systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .appFont(.subheadline)
                .lineLimit(1)
                .frame(maxWidth: .infinity, minHeight: 36, alignment: .leading)
                .padding(.horizontal, 8)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    /// Return picks the recipe with exactly that name, or else adds the words.
    private func submit() {
        if let exact = suggestions.first(where: { $0.title.localizedCaseInsensitiveCompare(typed) == .orderedSame }) {
            add(exact)
        } else {
            addWords()
        }
    }

    private func add(_ recipe: Recipe) {
        addRecipe(recipe)
        text = ""
    }

    private func addWords() {
        guard !typed.isEmpty else { return }
        addText(typed)
        text = ""
    }
}

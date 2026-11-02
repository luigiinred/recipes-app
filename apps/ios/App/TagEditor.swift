import RecipeKit
import SwiftUI

/// Chips for the current categories, a field that adds one on Return or comma, and common or most-used ones to tap.
struct TagEditor: View {
    @EnvironmentObject private var library: RecipeLibrary
    @Binding var tags: [String]
    @State private var draft = ""
    @FocusState private var focused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if !tags.isEmpty {
                ChipFlow {
                    ForEach(tags, id: \.self) { tag in
                        Button { remove(tag) } label: {
                            HStack(spacing: 6) {
                                Text(CategoryTree.displayName(tag))
                                Image(systemName: "xmark").font(.caption2.weight(.bold))
                            }
                            .font(.callout.weight(.medium))
                            .tagChip()
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Remove \(CategoryTree.displayName(tag))")
                    }
                }
            }
            TextField("Add category", text: $draft)
                .focused($focused)
                .onSubmit { commit(); focused = true }
                .onChange(of: draft) { _, value in
                    if value.contains(",") { commit() }
                }
                #if os(iOS)
                .textInputAutocapitalization(.words)
                .submitLabel(.done)
                #endif
            if !suggestions.isEmpty {
                ChipFlow {
                    ForEach(suggestions, id: \.self) { tag in
                        Button { add(tag) } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "plus").font(.caption2.weight(.bold))
                                Text(CategoryTree.displayName(tag))
                            }
                            .font(.callout)
                            .lineLimit(1)
                            .fixedSize()
                            .padding(.horizontal, 12).padding(.vertical, 6)
                            .background(Color.secondary.opacity(0.14), in: Capsule())
                            .foregroundStyle(.primary)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Add \(CategoryTree.displayName(tag))")
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }

    private var suggestions: [String] {
        let counts = library.recipes.flatMap(\.tags).reduce(into: [String: Int]()) { $0[$1, default: 0] += 1 }
        let used = counts.sorted { ($1.value, $0.key) < ($0.value, $1.key) }.map(\.key)
        let query = draft.trimmingCharacters(in: .whitespaces)
        var seen = Set<String>()
        return (RecipeTags.vocabulary + used)
            .filter { tag in
                !contains(tag) && seen.insert(tag.lowercased()).inserted
                    && (query.isEmpty || CategoryTree.displayName(tag).localizedCaseInsensitiveContains(query))
            }
            .prefix(10)
            .map { $0 }
    }

    private func contains(_ tag: String) -> Bool {
        tags.contains { $0.caseInsensitiveCompare(tag) == .orderedSame }
    }

    private func add(_ tag: String) {
        let normalized = CategoryTree.normalized(tag)
        if !normalized.isEmpty, !contains(normalized) { tags.append(normalized) }
        draft = ""
    }

    private func commit() {
        CategoryTree.tags(from: draft).forEach(add)
        draft = ""
    }

    private func remove(_ tag: String) {
        tags.removeAll { $0 == tag }
    }
}

/// Edits a recipe's tags on their own, saving only on Done.
struct TagsSheet: View {
    @EnvironmentObject private var library: RecipeLibrary
    @Environment(\.dismiss) private var dismiss
    let recipe: Recipe
    @State private var tags: [String]

    init(recipe: Recipe) {
        self.recipe = recipe
        _tags = State(initialValue: recipe.tags)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TagEditor(tags: $tags)
                } footer: {
                    Text("Use a slash to nest one, like Dinner/Pasta.")
                }
            }
            .formStyle(.grouped)
            .navigationTitle("Tags")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { CancelButton() }
                ToolbarItem(placement: .confirmationAction) {
                    ConfirmButton {
                        if tags != recipe.tags {
                            var changed = library.recipe(id: recipe.id) ?? recipe
                            changed.tags = tags
                            Task { await library.save(changed) }
                        }
                        dismiss()
                    }
                }
            }
        }
        #if os(macOS)
        .frame(minWidth: 380, minHeight: 320)
        #endif
    }
}

/// The capsule a tag sits in: a faint tint in light mode, and a stronger one with lighter text in dark mode so it reads against the page.
struct TagChip: ViewModifier {
    @Environment(\.appAccent) private var accent
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        content
            .padding(.horizontal, 12).padding(.vertical, 6)
            .background(accent.opacity(colorScheme == .dark ? 0.24 : 0.09), in: Capsule())
            .foregroundStyle(colorScheme == .dark ? accent.mix(with: .white, by: 0.35) : accent)
    }
}

extension View {
    func tagChip() -> some View { modifier(TagChip()) }
}

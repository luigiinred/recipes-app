import RecipeKit
import SwiftUI

/// Chips for the current tags, a field that adds one on Return or comma, and every tag in the library to tap.
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
            HStack(spacing: 8) {
                Image(systemName: "plus.circle.fill").foregroundStyle(Theme.accent)
                TextField("Add a new tag", text: $draft)
                    .focused($focused)
                    .onSubmit { commit(); focused = true }
                    .onChange(of: draft) { _, value in
                        if value.contains(",") { commit() }
                    }
                    #if os(iOS)
                    .textInputAutocapitalization(.words)
                    .submitLabel(.done)
                    #endif
                if !CategoryTree.normalized(draft).isEmpty {
                    Button("Add") { commit() }
                        .font(.callout.weight(.semibold))
                        .foregroundStyle(Theme.accent)
                        .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 12).padding(.vertical, 10)
            .background(Color.secondary.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
            .contentShape(RoundedRectangle(cornerRadius: 12))
            .onTapGesture { focused = true }
            if !suggestions.isEmpty {
                Text(libraryTags.isEmpty ? "Suggestions" : "Your tags")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
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

    private var libraryTags: [String] { library.tags }

    /// Every tag already on a recipe; the starter vocabulary only until the library has some.
    private var suggestions: [String] {
        let query = draft.trimmingCharacters(in: .whitespaces)
        var seen = Set<String>()
        return (libraryTags.isEmpty ? RecipeTags.vocabulary : libraryTags).filter { tag in
            !contains(tag) && seen.insert(tag.lowercased()).inserted
                && (query.isEmpty || CategoryTree.displayName(tag).localizedCaseInsensitiveContains(query))
        }
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

/// Edits a recipe's tags on their own, saving whenever the sheet closes.
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
            .scrollDismissesKeyboard(.immediately)
            .navigationTitle("Tags")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { ConfirmButton { dismiss() } }
            }
        }
        .onDisappear(perform: save)
        #if os(macOS)
        .frame(minWidth: 380, minHeight: 320)
        #endif
    }

    private func save() {
        guard tags != recipe.tags else { return }
        var changed = library.recipe(id: recipe.id) ?? recipe
        changed.tags = tags
        Task { await library.save(changed) }
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

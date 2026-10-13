import RecipeKit
import SwiftUI

/// Chips for the current categories, a field that adds one on Return or comma, and your most-used existing ones to tap.
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
                            .padding(.horizontal, 12).padding(.vertical, 6)
                            .background(Theme.accent.opacity(0.14), in: Capsule())
                            .foregroundStyle(Theme.accent)
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
                            Label(CategoryTree.displayName(tag), systemImage: "plus")
                                .font(.callout)
                                .padding(.horizontal, 12).padding(.vertical, 6)
                                .background(Color.secondary.opacity(0.14), in: Capsule())
                                .foregroundStyle(.primary)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }

    private var suggestions: [String] {
        let counts = library.recipes.flatMap(\.tags).reduce(into: [String: Int]()) { $0[$1, default: 0] += 1 }
        let query = draft.trimmingCharacters(in: .whitespaces)
        return counts
            .filter { tag, _ in
                !contains(tag) && (query.isEmpty || CategoryTree.displayName(tag).localizedCaseInsensitiveContains(query))
            }
            .sorted { ($1.value, $0.key) < ($0.value, $1.key) }
            .prefix(8)
            .map(\.key)
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

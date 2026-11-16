import RecipeKit
import SwiftUI

/// Typed words that aren't a recipe yet: a note in Up Next, or a meal planned by name.
enum FreeTextItem: Identifiable, Hashable {
    case note(UpNextNote)
    case entry(MealPlanEntry)

    var id: UUID {
        switch self {
        case .note(let note): note.id
        case .entry(let entry): entry.id
        }
    }

    var title: String {
        switch self {
        case .note(let note): note.title
        case .entry(let entry): entry.title
        }
    }
}

/// Under search results: puts the typed words in Up Next or the planner as they are, to find a recipe for later.
struct FreeTextActions: View {
    @EnvironmentObject private var library: RecipeLibrary
    @Environment(\.appAccent) private var accent
    let text: String
    @State private var planning = false

    private var isQueued: Bool {
        library.upNext.contains { $0.title.localizedCaseInsensitiveCompare(text) == .orderedSame }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: "text.badge.plus").foregroundStyle(accent)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Save “\(text)” for Later").foregroundStyle(.primary)
                    Text("Add it as it is, then find a recipe or make it an idea.").appFont(.caption).foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
            }
            HStack(spacing: 10) {
                Button { Task { await library.queue(text: text) } } label: {
                    Label(isQueued ? "In Up Next" : "Up Next", systemImage: isQueued ? "checkmark" : "text.line.first.and.arrowtriangle.forward")
                        .frame(maxWidth: .infinity)
                }
                .disabled(isQueued)
                .accessibilityIdentifier("freeText.upNext")
                Button { planning = true } label: {
                    Label("Plan", systemImage: "calendar.badge.plus").frame(maxWidth: .infinity)
                }
                .accessibilityIdentifier("freeText.plan")
            }
            .buttonStyle(.bordered)
            .tint(accent)
        }
        .padding(14)
        .background(accent.opacity(0.1), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .panel(isPresented: $planning) { AddToCalendarSheet(text: text) }
    }
}

/// A note in Up Next or a meal planned by name: find a recipe for it, make it an idea, or plan it.
struct FreeTextSheet: View {
    @EnvironmentObject private var library: RecipeLibrary
    @SheetDismiss private var dismiss
    let item: FreeTextItem
    var open: ((UUID) -> Void)?
    @State private var planning: UpNextNote?

    private var matches: [Recipe] { Array(library.recipes.filter { $0.matches(item.title) }.prefix(5)) }

    private var isNote: Bool { if case .note = item { true } else { false } }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(item.title).appFont(.title2, weight: .bold)
                        Text(isNote ? "In Up Next, without a recipe yet." : "On your plan, without a recipe yet.")
                            .appFont(.subheadline).foregroundStyle(.secondary)
                    }
                }
                if !matches.isEmpty {
                    Section("From Your Recipes") {
                        ForEach(matches) { recipe in
                            Button { use(recipe) } label: { RecipeRow(recipe: recipe) }.buttonStyle(.plain)
                        }
                    }
                }
                Section {
                    NavigationLink {
                        DiscoverSearchResults(query: item.title).navigationTitle("“\(item.title)”")
                    } label: {
                        Label("Find a Recipe Online", systemImage: "magnifyingglass")
                    }
                    Button { makeIdea() } label: { Label("Make It an Idea", systemImage: "lightbulb") }
                    if case .note(let note) = item {
                        Button { planning = note } label: { Label("Plan…", systemImage: "calendar.badge.plus") }
                    }
                }
                Section {
                    Button(role: .destructive) { remove() } label: {
                        Label(isNote ? "Remove from Up Next" : "Remove from Plan", systemImage: "trash")
                    }
                }
            }
            .navigationTitle("")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar { ToolbarItem(placement: .cancellationAction) { CancelButton() } }
        }
        .panel(item: $planning, onDismiss: { if !library.upNextNotes.contains(where: { $0.id == item.id }) { dismiss() } }) {
            AddToCalendarSheet(note: $0)
        }
        #if os(macOS)
        .frame(minWidth: 420, minHeight: 480)
        #endif
    }

    private func use(_ recipe: Recipe) {
        Task {
            switch item {
            case .note(let note): await library.use(recipe, for: note)
            case .entry(var entry):
                entry.recipeID = recipe.id
                entry.title = recipe.title
                await library.update(entry)
            }
        }
        finish(opening: recipe.id)
    }

    private func makeIdea() {
        Task {
            let idea = switch item {
            case .note(let note): await library.makeIdea(from: note)
            case .entry(let entry): await library.makeIdea(from: entry)
            }
            finish(opening: idea.id)
        }
    }

    private func remove() {
        Task {
            switch item {
            case .note(let note): await library.remove(note)
            case .entry(let entry): await library.remove(entry)
            }
        }
        dismiss()
    }

    private func finish(opening id: UUID) {
        dismiss()
        open?(id)
    }
}

/// A note laid out like a recipe row, with a plain tile where the photo would be.
struct FreeTextRow: View {
    @Environment(\.appAccent) private var accent
    let title: String

    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(accent.opacity(0.12))
                .frame(width: 64, height: 64)
                .overlay { Image(systemName: "text.quote").appFont(.title3).foregroundStyle(accent) }
            VStack(alignment: .leading, spacing: 3) {
                Text(title).appFont(.headline).lineLimit(2)
                Text("No recipe yet").appFont(.caption).foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 3)
        .contentShape(Rectangle())
    }
}

import RecipeKit
import SwiftUI

/// Where an Add search puts what you pick.
enum PlanDestination: Hashable, Identifiable {
    case upNext
    case day(Date)

    var id: Self { self }
}

/// One search for adding to Up Next or to a day: pick a recipe, or keep the typed words as a meal.
struct AddToPlanSheet: View {
    @EnvironmentObject private var library: RecipeLibrary
    @Environment(\.appAccent) private var accent
    @SheetDismiss private var dismiss
    let destination: PlanDestination
    @State private var meal: Meal
    @State private var search = ""
    /// Opens with the search field ready to type, like a search page.
    @State private var isSearching = false

    init(destination: PlanDestination, meal: Meal = AppSettings.defaultMeal()) {
        self.destination = destination
        _meal = State(initialValue: meal)
    }

    private var typed: String { search.trimmingCharacters(in: .whitespacesAndNewlines) }

    private var day: Date? {
        if case .day(let day) = destination { day } else { nil }
    }

    private var title: String {
        guard let day else { return "Add to Up Next" }
        return "Add to \(day.formatted(.dateTime.weekday(.wide)))"
    }

    private var queuedRecipes: [Recipe] {
        guard day != nil else { return [] }
        return RecipeCollection.wantToCook.filter(library.recipes).filter { $0.matches(search) }
    }

    private var queuedNotes: [UpNextNote] {
        guard day != nil else { return [] }
        return library.upNextNotes.filter { search.isEmpty || $0.title.localizedCaseInsensitiveContains(search) }
            .sorted { $0.queuedAt < $1.queuedAt }
    }

    private var otherRecipes: [Recipe] {
        library.recipes.filter { !$0.wantToCook && $0.matches(search) }
            .sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
    }

    var body: some View {
        NavigationStack {
            List {
                if day != nil {
                    Picker("Meal", selection: $meal) {
                        ForEach(Meal.allCases, id: \.self) { Text($0.title).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .listRowSeparator(.hidden)
                }
                if !typed.isEmpty {
                    Button { addWords() } label: {
                        Label("Add “\(typed)” \(day == nil ? "to Up Next" : "as a Meal")", systemImage: "text.badge.plus")
                            .foregroundStyle(accent)
                    }
                    .accessibilityIdentifier("add.typed")
                }
                if !queuedRecipes.isEmpty || !queuedNotes.isEmpty {
                    Section("From Up Next") {
                        ForEach(queuedNotes) { note in
                            row(title: note.title, subtitle: "Up Next") {
                                Task { await library.plan(note, on: day ?? Date(), meal: meal) }
                            } thumbnail: {
                                Image(systemName: "text.alignleft").font(.title3).foregroundStyle(.secondary)
                                    .frame(maxWidth: .infinity, maxHeight: .infinity).background(.quaternary)
                            }
                        }
                        ForEach(queuedRecipes) { recipe in recipeRow(recipe) }
                    }
                }
                Section(day == nil ? "" : "My Recipes") {
                    ForEach(otherRecipes) { recipe in recipeRow(recipe) }
                }
            }
            .listStyle(.plain)
            .overlay {
                if otherRecipes.isEmpty, queuedRecipes.isEmpty, queuedNotes.isEmpty, typed.isEmpty {
                    ContentUnavailableView.search(text: search)
                }
            }
            .searchable(text: $search, isPresented: $isSearching, prompt: "Search recipes or type a meal")
            .onSubmit(of: .search, submit)
            .task {
                // Focus waits for the presentation to finish, or the keyboard never comes up.
                try? await Task.sleep(for: .milliseconds(400))
                isSearching = true
            }
            .panelTitle(title)
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar { ToolbarItem(placement: .cancellationAction) { CancelButton() } }
        }
        #if os(macOS)
        .sheetFrame(minWidth: 420, minHeight: 520)
        #endif
    }

    private func recipeRow(_ recipe: Recipe) -> some View {
        row(title: recipe.title, recipe: recipe) { add(recipe) } thumbnail: { RecipeImageView(recipe: recipe) }
    }

    private func row(title: String, subtitle: String? = nil, recipe: Recipe? = nil, action: @escaping () -> Void,
                     @ViewBuilder thumbnail: () -> some View) -> some View {
        Button {
            action()
            dismiss()
        } label: {
            ThumbnailRow(title: title, thumbnailSize: 52, thumbnail: thumbnail) {
                if let recipe { RecipeFacts(recipe: recipe) } else if let subtitle { Text(subtitle) }
            } accessory: {
                Text("Add")
                    .appFont(.subheadline, weight: .bold)
                    .padding(.horizontal, 16)
                    .frame(minHeight: 30)
                    .background(accent.opacity(0.15), in: Capsule())
                    .foregroundStyle(accent)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Add \(title)")
        .accessibilityIdentifier("add.row.\(title)")
    }

    private func add(_ recipe: Recipe) {
        if let day {
            Task { await library.plan(recipe, on: day, meal: meal) }
        } else if !recipe.wantToCook {
            Task { await library.setQueued(recipe, true) }
        }
    }

    private func addWords() {
        guard !typed.isEmpty else { return }
        if let day {
            Task { await library.plan(text: typed, on: day, meal: meal) }
        } else {
            Task { await library.queue(text: typed) }
        }
        dismiss()
    }

    /// Return adds the recipe with exactly that name, or else the words as they are.
    private func submit() {
        guard !typed.isEmpty else { return }
        if let exact = library.recipes.first(where: { $0.title.localizedCaseInsensitiveCompare(typed) == .orderedSame }) {
            add(exact)
            dismiss()
        } else {
            addWords()
        }
    }
}

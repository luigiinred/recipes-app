import RecipeKit
import SwiftUI

struct UpNextPickerSheet: View {
    @EnvironmentObject private var library: RecipeLibrary
    @SheetDismiss private var dismiss
    @State private var search = ""
    /// Opens with the search field ready to type, like a search page.
    @State private var isSearching = false

    private var candidates: [Recipe] { library.recipes.filter { !$0.wantToCook && $0.matches(search) } }
    private var typed: String { search.trimmingCharacters(in: .whitespacesAndNewlines) }

    var body: some View {
        NavigationStack {
            List {
                ForEach(candidates) { recipe in
                    Button {
                        Task { await library.setQueued(recipe, true) }
                        dismiss()
                    } label: { RecipeRow(recipe: recipe) }
                    .buttonStyle(.plain)
                }
                if !typed.isEmpty {
                    Button {
                        Task { await library.queue(text: typed) }
                        dismiss()
                    } label: {
                        Label("Add “\(typed)” as It Is", systemImage: "text.badge.plus")
                    }
                }
            }
            .listStyle(.plain)
            .overlay {
                if candidates.isEmpty, typed.isEmpty { ContentUnavailableView.search(text: search) }
            }
            .searchable(text: $search, isPresented: $isSearching, prompt: "Search recipes or type a meal")
            .onSubmit(of: .search, add)
            .task {
                // Focus waits for the presentation to finish, or the keyboard never comes up.
                try? await Task.sleep(for: .milliseconds(400))
                isSearching = true
            }
            .panelTitle("Add to Up Next")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar { ToolbarItem(placement: .cancellationAction) { CancelButton() } }
        }
        #if os(macOS)
        .sheetFrame(minWidth: 420, minHeight: 480)
        #endif
    }

    /// Return queues the recipe with exactly that name, or else the words as they are.
    private func add() {
        guard !typed.isEmpty else { return }
        if let exact = library.recipes.first(where: { $0.title.localizedCaseInsensitiveCompare(typed) == .orderedSame }) {
            if !exact.wantToCook { Task { await library.setQueued(exact, true) } }
        } else {
            Task { await library.queue(text: typed) }
        }
        dismiss()
    }
}

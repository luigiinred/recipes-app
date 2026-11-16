import RecipeKit
import SwiftUI

struct UpNextPickerSheet: View {
    @EnvironmentObject private var library: RecipeLibrary
    @SheetDismiss private var dismiss
    @State private var search = ""

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
            .searchable(text: $search, prompt: "Search My Recipes")
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
}

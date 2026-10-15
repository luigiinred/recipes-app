import RecipeKit
import SwiftUI

/// Jot down something to cook that has no recipe yet, like "Spaghetti" or "Frozen burgers".
struct NewIdeaSheet: View {
    @EnvironmentObject private var library: RecipeLibrary
    @Environment(\.dismiss) private var dismiss
    let onSaved: (Recipe) -> Void

    @State private var title = ""
    @State private var notes = ""

    private var trimmedTitle: String { title.trimmingCharacters(in: .whitespacesAndNewlines) }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Spaghetti, frozen burgers, leftovers…", text: $title)
                }
                Section("Notes") {
                    TextField("Anything to remember", text: $notes, axis: .vertical)
                        .lineLimit(3...8)
                }
            }
            .formStyle(.grouped)
            .navigationTitle("New Idea")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { CancelButton() }
                ToolbarItem(placement: .confirmationAction) {
                    ConfirmButton(title: "Save", isDisabled: trimmedTitle.isEmpty) {
                        Task {
                            let idea = await library.addIdea(title: trimmedTitle, notes: notes.trimmingCharacters(in: .whitespacesAndNewlines))
                            onSaved(idea)
                        }
                        dismiss()
                    }
                }
            }
        }
        #if os(macOS)
        .frame(minWidth: 380, minHeight: 280)
        #endif
    }
}

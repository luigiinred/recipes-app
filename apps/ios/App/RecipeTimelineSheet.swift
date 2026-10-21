import RecipeKit
import SwiftUI

/// Every time a recipe was cooked, newest first, with a place to log another.
struct RecipeTimelineSheet: View {
    @EnvironmentObject private var library: RecipeLibrary
    @Environment(\.dismiss) private var dismiss
    let recipeID: UUID

    @State private var date = Date()
    @State private var note = ""

    private var recipe: Recipe? { library.recipe(id: recipeID) }

    var body: some View {
        NavigationStack {
            List {
                if let recipe {
                    Section("Made it") {
                        DatePicker("Date", selection: $date, in: ...Date(), displayedComponents: .date)
                        TextField("Notes (optional)", text: $note, axis: .vertical)
                        Button("Log It", systemImage: "checkmark.circle.fill") {
                            Task { await library.logMade(recipe, on: date, note: note) }
                            note = ""
                            date = Date()
                        }
                    }
                    Section {
                        ForEach(recipe.timeline.sorted { $0.date > $1.date }) { event in
                            VStack(alignment: .leading, spacing: 3) {
                                Label {
                                    Text(event.date, format: .dateTime.weekday(.wide).month().day().year())
                                } icon: {
                                    Image(systemName: "checkmark.circle.fill").foregroundStyle(Theme.accent)
                                }
                                if !event.note.isEmpty {
                                    Text(event.note).font(.callout).foregroundStyle(.secondary)
                                }
                            }
                            .swipeActions {
                                Button(role: .destructive) { Task { await library.removeEvent(event, from: recipe) } } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                        }
                        Label {
                            Text("Added \(recipe.createdAt.formatted(.dateTime.month().day().year()))")
                        } icon: {
                            Image(systemName: "plus.circle")
                        }
                        .foregroundStyle(.secondary)
                    } header: {
                        Text("Timeline")
                    }
                }
            }
            .animation(.snappy, value: recipe?.timeline)
            .navigationTitle(recipe?.title ?? "Timeline")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar { ToolbarItem(placement: .confirmationAction) { ConfirmButton { dismiss() } } }
        }
        #if os(macOS)
        .frame(minWidth: 420, minHeight: 480)
        #endif
    }
}

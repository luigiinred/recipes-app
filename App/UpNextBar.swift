import RecipeKit
import SwiftUI

/// Recipes you mean to cook soon. A recipe leaves the queue when you put it on a day.
struct UpNextBar: View {
    @EnvironmentObject private var library: RecipeLibrary
    let open: (UUID) -> Void

    @State private var planning: Recipe?
    @State private var adding = false

    private var queue: [Recipe] { RecipeCollection.wantToCook.filter(library.recipes) }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Label("Up Next", systemImage: "text.line.first.and.arrowtriangle.forward")
                    .font(.subheadline.weight(.semibold))
                if !queue.isEmpty {
                    Text("\(queue.count)").font(.subheadline).foregroundStyle(.secondary).contentTransition(.numericText())
                }
                Spacer()
                Button { adding = true } label: { Image(systemName: "plus").foregroundStyle(Theme.accent) }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Add to Up Next")
            }
            .padding(.horizontal, 16)
            if queue.isEmpty {
                Text("Queue recipes you want to cook soon. They leave the queue once you plan them.")
                    .font(.footnote).foregroundStyle(.secondary)
                    .padding(.horizontal, 16)
                    .transition(.opacity)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(queue) { recipe in
                            card(recipe).transition(.scale.combined(with: .opacity))
                        }
                    }
                    .padding(.horizontal, 16)
                }
            }
        }
        .padding(.vertical, 10)
        .animation(.snappy, value: queue.map(\.id))
        .sheet(item: $planning) { AddToCalendarSheet(recipe: $0) }
        .sheet(isPresented: $adding) { UpNextPickerSheet() }
    }

    private func card(_ recipe: Recipe) -> some View {
        HStack(spacing: 8) {
            Button { open(recipe.id) } label: {
                HStack(spacing: 8) {
                    RecipeImageView(recipe: recipe)
                        .frame(width: 44, height: 44)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    Text(recipe.title)
                        .font(.system(.subheadline, design: .serif, weight: .semibold))
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: 130, alignment: .leading)
                }
            }
            .buttonStyle(.plain)
            Button { planning = recipe } label: { Image(systemName: "calendar.badge.plus").foregroundStyle(Theme.accent) }
                .buttonStyle(.plain)
                .accessibilityLabel("Plan \(recipe.title)")
        }
        .padding(8)
        .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 12))
        .draggable(PlannerPayload(kind: .recipe, id: recipe.id))
        .contextMenu {
            Button("Plan…", systemImage: "calendar.badge.plus") { planning = recipe }
            Button("Remove from Up Next", systemImage: "minus.circle", role: .destructive) {
                Task { await library.setQueued(recipe, false) }
            }
        }
    }
}

struct UpNextPickerSheet: View {
    @EnvironmentObject private var library: RecipeLibrary
    @Environment(\.dismiss) private var dismiss
    @State private var search = ""

    private var candidates: [Recipe] { library.recipes.filter { !$0.wantToCook && $0.matches(search) } }

    var body: some View {
        NavigationStack {
            List(candidates) { recipe in
                Button {
                    Task { await library.setQueued(recipe, true) }
                    dismiss()
                } label: { RecipeRow(recipe: recipe) }
                .buttonStyle(.plain)
            }
            .listStyle(.plain)
            .overlay {
                if candidates.isEmpty { ContentUnavailableView.search(text: search) }
            }
            .searchable(text: $search, prompt: "Search recipes")
            .navigationTitle("Add to Up Next")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar { ToolbarItem(placement: .cancellationAction) { CancelButton() } }
        }
        #if os(macOS)
        .frame(minWidth: 420, minHeight: 480)
        #endif
    }
}

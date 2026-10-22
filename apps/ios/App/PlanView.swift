import RecipeKit
import SwiftUI

enum PlanMode: String, CaseIterable {
    case queue, week

    var title: String { self == .queue ? "Up Next" : "My Week" }
}

/// The planner: the queue of recipes to cook soon, and the week they land in.
struct PlanView: View {
    @Binding var mode: PlanMode
    let open: (UUID) -> Void
    var showsSmartPlan = false

    var body: some View {
        VStack(spacing: 0) {
            Picker("Plan", selection: $mode) {
                ForEach(PlanMode.allCases, id: \.self) { Text($0.title).tag($0) }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .padding(.horizontal, 16).padding(.vertical, 8)
            switch mode {
            case .queue: QueueView(open: open)
            case .week: MyWeekView(open: open, showsSmartPlan: showsSmartPlan)
            }
        }
        .navigationTitle("Plan")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }
}

struct QueueView: View {
    @Environment(\.appAccent) private var accent
    @EnvironmentObject private var library: RecipeLibrary
    @EnvironmentObject private var cook: CookSession
    @EnvironmentObject private var router: AppRouter
    let open: (UUID) -> Void

    @State private var planning: Recipe?
    @State private var adding = false
    #if os(iOS)
    @State private var editMode = EditMode.inactive
    #endif

    private var queue: [Recipe] { RecipeCollection.wantToCook.filter(library.recipes) }

    var body: some View {
        List {
            ForEach(queue) { recipe in
                Button { open(recipe.id) } label: { RecipeRow(recipe: recipe) }
                    .buttonStyle(.plain)
                    .themedRow()
                    .swipeActions(edge: .leading) {
                        Button { planning = recipe } label: { Label("Plan", systemImage: "calendar.badge.plus") }
                            .tint(accent)
                    }
                    .swipeActions(edge: .trailing) {
                        Button { madeIt(recipe) } label: { Label("Made It", systemImage: "checkmark.circle") }
                            .tint(.green)
                        Button { remove(recipe) } label: { Label("Remove", systemImage: "minus.circle") }
                            .tint(.orange)
                    }
                    .contextMenu {
                        Button("Made It", systemImage: "checkmark.circle") { madeIt(recipe) }
                        Button("Plan…", systemImage: "calendar.badge.plus") { planning = recipe }
                        Button("Cook", systemImage: "frying.pan") { cook.start(recipe) }
                            .disabled(recipe.steps.isEmpty)
                        Divider()
                        Button("Remove from Up Next", systemImage: "minus.circle", role: .destructive) { remove(recipe) }
                    }
            }
            .onMove { source, destination in Task { await library.moveQueued(from: source, to: destination) } }
        }
        .listStyle(.plain)
        .themedCanvas()
        .animation(.snappy, value: queue.map(\.id))
        .overlay {
            if queue.isEmpty {
                MascotEmptyState(
                    scene: .bookWrite, title: "Nothing in Up Next",
                    message: "Swipe a recipe left in your library, or tap Add, to line up what you want to cook soon."
                ) {
                    Button("Add Recipes") { adding = true }.buttonStyle(PaperButtonStyle()).frame(maxWidth: 240)
                }
            }
        }
        #if os(iOS)
        .environment(\.editMode, $editMode)
        .onChange(of: queue.count) { _, count in if count < 2 { editMode = .inactive } }
        #endif
        .onChange(of: router.add) { _, target in
            guard target == .plan else { return }
            router.add = nil
            adding = true
        }
        .toolbar {
            #if os(iOS)
            if queue.count > 1 {
                ToolbarItem(placement: .navigation) {
                    Button { withAnimation { editMode = editMode.isEditing ? .inactive : .active } } label: {
                        Label(editMode.isEditing ? "Done" : "Reorder", systemImage: editMode.isEditing ? "checkmark" : "arrow.up.arrow.down")
                    }
                    .labelStyle(.iconOnly)
                }
            }
            #endif
            ToolbarItem(placement: .primaryAction) {
                Button { adding = true } label: { Label("Add to Up Next", systemImage: "plus") }
            }
        }
        .sheet(item: $planning) { AddToCalendarSheet(recipe: $0) }
        .sheet(isPresented: $adding) { UpNextPickerSheet() }
    }

    private func remove(_ recipe: Recipe) {
        Task { await library.setQueued(recipe, false) }
    }

    private func madeIt(_ recipe: Recipe) {
        Task { await library.logMade(recipe) }
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

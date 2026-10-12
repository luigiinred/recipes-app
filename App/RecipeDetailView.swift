import ImagePlayground
import RecipeKit
import SwiftUI

struct RecipeDetailView: View {
    @EnvironmentObject private var library: RecipeLibrary
    @EnvironmentObject private var cook: CookSession
    let recipe: Recipe
    var previewSave: (() -> Void)?
    var previewImage: Data?

    @State private var checkedIngredients: Set<Int> = []
    @State private var doneSteps: Set<Int> = []
    @State private var confirmingDelete = false
    @Environment(\.dismiss) private var dismiss
    @State private var editing = false
    @StateObject private var player = YouTubePlayerController()
    @State private var findingTimestamps = false
    @State private var timestampMessage: String?
    @State private var generatingImage = false
    @Environment(\.supportsImagePlayground) private var supportsImagePlayground
    @State private var addingToGroceries = false
    @State private var addingToCalendar = false
    @AppStorage(AppSettings.Key.ratingStyle) private var ratingStyleRaw = RatingStyle.favorites.rawValue
    private var ratingStyle: RatingStyle { RatingStyle(rawValue: ratingStyleRaw) ?? .favorites }

    var body: some View {
        VStack(spacing: 0) {
        if let videoID = recipe.youTubeVideoID {
            YouTubeEmbed(recipe: recipe, videoID: videoID, controller: player)
                .frame(maxWidth: 640)
                .padding(.horizontal, 24)
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity)
                .background(.bar)
        }
        GeometryReader { geometry in
            if geometry.size.width >= 760 {
                twoColumns(width: geometry.size.width)
            } else {
                oneColumn
            }
        }
        }
        .background(.background)
        .onChange(of: cook.isPresented) { _, presented in
            if presented { player.pause() }
        }
        .navigationTitle(recipe.title)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            if let previewSave {
                ToolbarItem { Button("Save Recipe", systemImage: "plus.circle.fill", action: previewSave) }
            } else {
                ToolbarItemGroup {
                    if ratingStyle == .favorites {
                        Button {
                            Task { await library.setFavorite(recipe, !recipe.isFavorite) }
                        } label: {
                            Label("Favorite", systemImage: recipe.isFavorite ? "heart.fill" : "heart")
                        }
                    }
                    Menu {
                        Button(recipe.wantToCook ? "Remove from Up Next" : "Add to Up Next", systemImage: recipe.wantToCook ? "minus.circle" : "text.line.first.and.arrowtriangle.forward") {
                            Task { await library.setQueued(recipe, !recipe.wantToCook) }
                        }
                        if supportsImagePlayground {
                            Button(library.hasImage(recipe.id) ? "Create a New Photo…" : "Create a Photo…", systemImage: "apple.image.playground") {
                                generatingImage = true
                            }
                        }
                        Button("Print…", systemImage: "printer") { RecipePrinter.print(recipe) }
                        ShareLink(item: recipe.markdown)
                        if recipe.youTubeVideoID != nil, !recipe.steps.isEmpty {
                            Button(findingTimestamps ? "Finding Timestamps…" : "Find Step Timestamps", systemImage: "clock.badge.checkmark") {
                                findTimestamps()
                            }
                            .disabled(findingTimestamps)
                        }
                        Divider()
                        Button("Edit", systemImage: "pencil") { editing = true }
                        Menu {
                            Button("Delete Recipe…", role: .destructive) { confirmingDelete = true }
                        } label: { Text("Delete") }
                    } label: { Label("More", systemImage: "ellipsis.circle") }
                }
            }
        }
        .sheet(isPresented: $editing) {
            RecipeEditorView(recipe: recipe) { saved, image, steps in Task { await library.save(saved, image: image, steps: steps) } }
        }
        .alert("Step Timestamps", isPresented: Binding(get: { timestampMessage != nil }, set: { if !$0 { timestampMessage = nil } })) {
            Button("OK") { timestampMessage = nil }
        } message: {
            Text(timestampMessage ?? "")
        }
        .recipeImageGenerator(isPresented: $generatingImage, recipe: recipe) { data in
            Task { await library.save(recipe, image: .set(data)) }
        }
        .sheet(isPresented: $addingToGroceries) { AddToGroceriesSheet(recipe: recipe) }
        .sheet(isPresented: $addingToCalendar) { AddToCalendarSheet(recipe: recipe) }
        .confirmationDialog("Delete “\(recipe.title)”?", isPresented: $confirmingDelete, titleVisibility: .visible) {
            Button("Delete Recipe", role: .destructive) {
                Task {
                    await library.delete(recipe)
                    dismiss()
                }
            }
        } message: {
            Text("This can't be undone. The recipe and its photo are removed from all your devices.")
        }
    }

    private var oneColumn: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                hero
                header
                TwoPaneLayout {
                    ingredients
                    steps
                }
                footer
            }
            .padding(24)
            .frame(maxWidth: 900, alignment: .leading)
            .frame(maxWidth: .infinity)
            .textSelection(.enabled)
        }
    }

    /// With room to spare the recipe and its ingredients scroll on their own, so both stay in view while cooking.
    private func twoColumns(width: CGFloat) -> some View {
        HStack(alignment: .top, spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    header
                    steps
                    footer
                }
                .padding(24)
                .frame(maxWidth: 720, alignment: .leading)
                .frame(maxWidth: .infinity)
            }
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    hero
                    ingredients
                }
                .padding(24)
            }
            .frame(width: min(420, max(320, width * 0.36)))
            .background(.quaternary.opacity(0.25))
        }
        .textSelection(.enabled)
    }

    @ViewBuilder
    private var footer: some View {
        if !recipe.notes.isEmpty {
            section("Notes") { Text(recipe.notes).foregroundStyle(.secondary) }
        }
        if let source = recipe.sourceURL, let url = URL(string: source) {
            Link(destination: url) { Label(url.host ?? source, systemImage: "link") }
        }
    }

    @ViewBuilder
    private var hero: some View {
        if recipe.youTubeVideoID != nil {
            EmptyView()
        } else if previewSave != nil, let data = previewImage, let image = RecipeImageProcessing.thumbnail(from: data, maxPixelSize: RecipeLibrary.thumbnailSize) {
            Image(decorative: image, scale: 1).resizable().scaledToFill()
                .aspectRatio(2, contentMode: .fit)
                .frame(maxWidth: .infinity, maxHeight: 320)
                .clipShape(RoundedRectangle(cornerRadius: 16))
        } else if previewSave == nil, library.hasImage(recipe.id) {
            RecipeImageView(recipe: recipe)
                .aspectRatio(2, contentMode: .fit)
                .frame(maxWidth: .infinity, maxHeight: 320)
                .clipShape(RoundedRectangle(cornerRadius: 16))
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(recipe.title).font(.system(.largeTitle, design: .serif, weight: .bold))
            if !recipe.summary.isEmpty {
                Text(recipe.summary).font(.title3).foregroundStyle(.secondary)
            }
            HStack(spacing: 16) {
                if let servings = recipe.servings { Label("\(servings) servings", systemImage: "person.2") }
                if let prep = recipe.prepMinutes { Label("Prep \(prep) min", systemImage: "knife") }
                if let cook = recipe.cookMinutes { Label("Cook \(cook) min", systemImage: "flame") }
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)
            if ratingStyle == .stars, previewSave == nil {
                StarRatingView(rating: recipe.rating) { value in Task { await library.setRating(recipe, value) } }
            }
            if previewSave == nil {
            HStack(spacing: 10) {
                Button { cook.start(recipe) } label: { Label("Cook", systemImage: "flame") }
                    .buttonStyle(.glassProminent)
                    .disabled(recipe.steps.isEmpty)
                Button { addingToGroceries = true } label: { Label("Groceries", systemImage: "checklist") }
                    .buttonStyle(.glass)
                    .disabled(recipe.ingredients.isEmpty)
                Button { addingToCalendar = true } label: { Label("Plan", systemImage: "calendar.badge.plus") }
                    .buttonStyle(.glass)
            }
            .font(.subheadline.weight(.semibold))
            .tint(Theme.accent)
            }
            if !recipe.tags.isEmpty {
                HStack {
                    ForEach(recipe.tags, id: \.self) { tag in
                        Text(CategoryTree.displayName(tag))
                            .font(.caption.weight(.medium))
                            .padding(.horizontal, 10).padding(.vertical, 4)
                            .background(Theme.accent.opacity(0.12), in: Capsule())
                            .foregroundStyle(Theme.accent)
                    }
                }
            }
        }
    }

    private var ingredients: some View {
        section("Ingredients") {
            VStack(alignment: .leading, spacing: 12) {
                ForEach(Array(recipe.ingredients.enumerated()), id: \.offset) { index, text in
                    HStack(alignment: .firstTextBaseline, spacing: 10) {
                        Image(systemName: checkedIngredients.contains(index) ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(checkedIngredients.contains(index) ? Theme.accent : .secondary)
                            .onTapGesture { toggle(&checkedIngredients, index) }
                            .accessibilityAddTraits(.isButton)
                        IngredientLine(text: text)
                            .strikethrough(checkedIngredients.contains(index))
                            .foregroundStyle(checkedIngredients.contains(index) ? .secondary : .primary)
                            .multilineTextAlignment(.leading)
                    }
                }
            }
        }
    }

    private var steps: some View {
        section("Steps") {
            VStack(alignment: .leading, spacing: 18) {
                ForEach(Array(recipe.steps.enumerated()), id: \.offset) { index, text in
                    VStack(alignment: .leading, spacing: 10) {
                    HStack(alignment: .firstTextBaseline, spacing: 12) {
                        Text("\(index + 1)")
                            .font(.headline)
                            .foregroundStyle(.white)
                            .frame(width: 26, height: 26)
                            .background(doneSteps.contains(index) ? Color.secondary : Theme.accent, in: Circle())
                            .onTapGesture { toggle(&doneSteps, index) }
                            .accessibilityAddTraits(.isButton)
                        Text(text)
                            .font(.system(.body, design: .serif))
                            .foregroundStyle(doneSteps.contains(index) ? .secondary : .primary)
                            .multilineTextAlignment(.leading)
                        Spacer(minLength: 0)
                        if recipe.youTubeVideoID != nil, let seconds = recipe.timestamp(forStep: index) {
                            Button {
                                player.play(from: seconds)
                            } label: {
                                Label(Recipe.clock(seconds), systemImage: "play.fill")
                                    .font(.caption.weight(.semibold).monospacedDigit())
                                    .padding(.horizontal, 9).padding(.vertical, 5)
                                    .background(Theme.accent.opacity(0.12), in: Capsule())
                                    .foregroundStyle(Theme.accent)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Play from \(Recipe.clock(seconds))")
                        }
                    }
                    if let imageID = recipe.stepImage(forStep: index) {
                        StepImageView(id: imageID).padding(.leading, 38)
                    }
                    }
                }
            }
        }
    }

    private func findTimestamps() {
        findingTimestamps = true
        Task {
            let count = await library.findTimestamps(for: recipe)
            findingTimestamps = false
            timestampMessage = count == 0
                ? "Couldn't match the steps to this video's captions."
                : "Found a timestamp for \(count) of \(recipe.steps.count) steps. Tap one to jump to that moment."
        }
    }

    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title.uppercased()).font(.caption.weight(.semibold)).foregroundStyle(.secondary).tracking(1)
            content()
        }
    }

    private func toggle(_ set: inout Set<Int>, _ index: Int) {
        if !set.insert(index).inserted { set.remove(index) }
    }
}

struct AddToCalendarSheet: View {
    @EnvironmentObject private var library: RecipeLibrary
    @Environment(\.dismiss) private var dismiss
    let recipe: Recipe

    @State private var day = Date()
    @State private var meal = AppSettings.defaultMeal()

    var body: some View {
        NavigationStack {
            Form {
                DatePicker("Day", selection: $day, displayedComponents: .date)
                Picker("Meal", selection: $meal) {
                    ForEach(Meal.allCases, id: \.self) { Label($0.title, systemImage: $0.symbol).tag($0) }
                }
            }
            .formStyle(.grouped)
            .navigationTitle("Add to Planner")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { CancelButton() }
                ToolbarItem(placement: .confirmationAction) {
                    ConfirmButton(title: "Add") {
                        Task { await library.plan(recipe, on: day, meal: meal) }
                        dismiss()
                    }
                }
            }
        }
        #if os(macOS)
        .frame(minWidth: 380, minHeight: 240)
        #endif
    }
}

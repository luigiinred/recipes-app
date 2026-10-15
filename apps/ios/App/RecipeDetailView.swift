import ImagePlayground
import RecipeKit
import SwiftUI

struct RecipeDetailView: View {
    @EnvironmentObject private var library: RecipeLibrary
    @EnvironmentObject private var cook: CookSession
    let recipe: Recipe
    var previewSave: (() -> Void)?
    var previewImage: Data?

    @State private var confirmingDelete = false
    @Environment(\.dismiss) private var dismiss
    @State private var editing = false
    @StateObject private var player = YouTubePlayerController()
    @State private var findingTimestamps = false
    @State private var timestampMessage: String?
    @State private var generatingImage = false
    @State private var scrollRequest = 0
    @State private var scrolled: CGFloat = 0
    @State private var topInset: CGFloat = 0
    @State private var headerOffset: CGFloat = 0
    @Environment(\.supportsImagePlayground) private var supportsImagePlayground
    @State private var addingToGroceries = false
    @State private var addingToCalendar = false
    @AppStorage(AppSettings.Key.ratingStyle) private var ratingStyleRaw = RatingStyle.favorites.rawValue
    private var ratingStyle: RatingStyle { RatingStyle(rawValue: ratingStyleRaw) ?? .favorites }

    var body: some View {
        GeometryReader { geometry in
            if geometry.size.width >= 760, !recipe.isIdea {
                twoColumns(width: geometry.size.width)
            } else {
                oneColumn
            }
        }
        .onGeometryChange(for: CGFloat.self) { $0.safeAreaInsets.top } action: { topInset = $0 }
        .background(.background)
        .onChange(of: cook.isPresented) { _, presented in
            if presented { player.pause() }
        }
        .navigationTitle(hasArtwork ? "" : recipe.title)
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
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    if recipe.youTubeVideoID != nil {
                        video.padding([.horizontal, .top], 24)
                    } else if hasArtwork {
                        Color.clear.frame(height: CollapsingRecipeHeader<EmptyView, EmptyView>.photoHeight)
                    }
                    VStack(alignment: .leading, spacing: 24) {
                        header(showsTitle: !hasArtwork)
                        if recipe.isIdea {
                            ideaNote
                        } else {
                            TwoPaneLayout {
                                ingredients
                                steps
                            }
                        }
                        footer
                    }
                    .padding(24)
                    .frame(maxWidth: 900, alignment: .leading)
                    .frame(maxWidth: .infinity)
                }
                .textSelection(.enabled)
            }
            .trackingVideoScroll($scrolled, active: recipe.youTubeVideoID != nil)
            .trackingHeaderScroll($headerOffset, active: hasArtwork)
            .overlay(alignment: .top) {
                if hasArtwork {
                    CollapsingRecipeHeader(title: recipe.title, topInset: topInset, offset: headerOffset) {
                        artwork
                    } actions: {
                        headerActions
                    }
                }
            }
            .onChange(of: scrollRequest) { _, _ in withAnimation { proxy.scrollTo("video", anchor: .top) } }
        }
    }

    @ViewBuilder
    private var headerActions: some View {
        if previewSave == nil {
            if !recipe.isIdea {
                HeaderActionButton(title: "Cook", systemImage: "frying.pan", prominent: true) { cook.start(recipe) }
                    .disabled(recipe.steps.isEmpty)
                HeaderActionButton(title: "Add to Groceries", systemImage: "checklist") { addingToGroceries = true }
                    .disabled(recipe.ingredients.isEmpty)
            }
            HeaderActionButton(title: recipe.wantToCook ? "Remove from Up Next" : "Add to Up Next",
                               systemImage: recipe.wantToCook ? "checkmark.circle.fill" : "text.line.first.and.arrowtriangle.forward") {
                Task { await library.setQueued(recipe, !recipe.wantToCook) }
            }
            HeaderActionButton(title: "Plan", systemImage: "calendar.badge.plus") { addingToCalendar = true }
        }
    }

    /// With room to spare the recipe and its ingredients scroll on their own, so both stay in view while cooking.
    private func twoColumns(width: CGFloat) -> some View {
        HStack(alignment: .top, spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 28) {
                        if recipe.youTubeVideoID != nil { video }
                        header(showsTitle: true)
                        steps
                        footer
                    }
                    .padding(24)
                    .frame(maxWidth: 720, alignment: .leading)
                    .frame(maxWidth: .infinity)
                }
                .trackingVideoScroll($scrolled, active: recipe.youTubeVideoID != nil)
                .onChange(of: scrollRequest) { _, _ in withAnimation { proxy.scrollTo("video", anchor: .top) } }
            }
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    if hasArtwork {
                        Color.clear
                            .frame(height: 280 + topInset)
                            .frame(maxWidth: .infinity)
                            .overlay { artwork }
                            .clipped()
                            .padding(.top, -topInset)
                            .padding(.horizontal, -24)
                    }
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
    private var video: some View {
        if let videoID = recipe.youTubeVideoID {
            YouTubeEmbed(recipe: recipe, videoID: videoID, controller: player, scrolled: scrolled)
                .zIndex(1)
                .id("video")
        }
    }

    private var hasArtwork: Bool {
        guard recipe.youTubeVideoID == nil else { return false }
        return previewSave != nil ? previewImage != nil : library.hasImage(recipe.id)
    }

    @ViewBuilder
    private var artwork: some View {
        if previewSave != nil, let data = previewImage,
           let image = RecipeImageProcessing.thumbnail(from: data, maxPixelSize: RecipeLibrary.thumbnailSize) {
            Image(decorative: image, scale: 1).resizable().scaledToFill()
        } else {
            RecipeImageView(recipe: recipe)
        }
    }

    private func header(showsTitle: Bool) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            if showsTitle {
                Text(recipe.title).font(.system(.largeTitle, design: .serif, weight: .bold))
            }
            statsRow
            if ratingStyle == .stars, previewSave == nil {
                StarRatingView(rating: recipe.rating) { value in Task { await library.setRating(recipe, value) } }
            }
            if previewSave == nil { actionTiles }
            if !recipe.summary.isEmpty {
                Text(recipe.summary).font(.callout).foregroundStyle(.secondary)
            }
            if !recipe.tags.isEmpty {
                ChipFlow(spacing: 8) {
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

    @ViewBuilder
    private var statsRow: some View {
        let stats: [(String, String)] = [
            recipe.totalMinutes.map { ("Total Time", Self.duration($0)) },
            recipe.cookMinutes.map { ("Cook Time", Self.duration($0)) },
            recipe.servings.map { ("Servings", "\($0)") },
        ].compactMap { $0 }
        if !stats.isEmpty {
            HStack(spacing: 0) {
                ForEach(stats.indices, id: \.self) { index in
                    if index > 0 { Divider().frame(height: 34).padding(.horizontal, 14) }
                    VStack(alignment: .leading, spacing: 2) {
                        Text(stats[index].0).font(.caption).foregroundStyle(.secondary)
                        Text(stats[index].1).font(.title3.weight(.medium))
                    }
                }
                Spacer(minLength: 0)
            }
        }
    }

    static func duration(_ minutes: Int) -> String {
        let hours = minutes / 60, rest = minutes % 60
        if hours == 0 { return "\(rest) min" }
        return rest == 0 ? "\(hours) hr" : "\(hours) hr \(rest) min"
    }

    private var actionTiles: some View {
        GlassEffectContainer(spacing: 10) {
            HStack(spacing: 10) {
                if !recipe.isIdea {
                    tile("Cook", systemImage: "frying.pan", prominent: true) { cook.start(recipe) }
                        .disabled(recipe.steps.isEmpty)
                    tile("Groceries", systemImage: "checklist") { addingToGroceries = true }
                        .disabled(recipe.ingredients.isEmpty)
                }
                tile(recipe.wantToCook ? "Queued" : "Up Next", systemImage: recipe.wantToCook ? "checkmark.circle.fill" : "text.line.first.and.arrowtriangle.forward") {
                    Task { await library.setQueued(recipe, !recipe.wantToCook) }
                }
                tile("Plan", systemImage: "calendar.badge.plus") { addingToCalendar = true }
            }
        }
    }

    private func tile(_ title: String, systemImage: String, prominent: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: systemImage).font(.title3)
                Text(title).font(.caption.weight(.medium))
            }
            .frame(maxWidth: .infinity, minHeight: 58)
            .foregroundStyle(prominent ? Color.white : Theme.accent)
            .glassEffect(
                prominent ? .regular.tint(Theme.accent).interactive() : .regular.tint(Theme.accent.opacity(0.1)).interactive(),
                in: RoundedRectangle(cornerRadius: 18)
            )
        }
        .buttonStyle(.plain)
    }

    private var ideaNote: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Just an idea so far", systemImage: "lightbulb").font(.headline)
            Text("Add ingredients and steps when you have a recipe for it, and this becomes a full recipe.")
                .foregroundStyle(.secondary)
            if previewSave == nil {
                Button("Add Ingredients and Steps", systemImage: "pencil") { editing = true }
                    .buttonStyle(.bordered)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 14))
    }

    private var ingredients: some View {
        section("Ingredients") {
            VStack(alignment: .leading, spacing: 8) {
                ForEach(Array(recipe.ingredientGroups.enumerated()), id: \.offset) { _, group in
                    if let title = group.title {
                        Text(title)
                            .font(.subheadline.weight(.semibold))
                            .padding(.top, 6)
                            .accessibilityAddTraits(.isHeader)
                    }
                    ForEach(group.items, id: \.index) { index, text in
                        HStack {
                            IngredientLine(text: text).multilineTextAlignment(.leading)
                            Spacer(minLength: 0)
                        }
                        .padding(12)
                        .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 14))
                    }
                }
            }
        }
    }

    private var steps: some View {
        section("Directions") {
            VStack(alignment: .leading, spacing: 22) {
                ForEach(Array(recipe.steps.enumerated()), id: \.offset) { index, text in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("STEP \(index + 1)")
                                .font(.footnote.weight(.bold))
                                .foregroundStyle(Theme.accent)
                            Spacer(minLength: 0)
                            if recipe.youTubeVideoID != nil, let seconds = recipe.timestamp(forStep: index) {
                                Button {
                                    player.play(from: seconds)
                                    scrollRequest += 1
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
                        Text(text)
                            .font(.system(.body, design: .serif))
                            .multilineTextAlignment(.leading)
                        StepIngredientChips(recipe: recipe, step: index)
                        if let imageID = recipe.stepImage(forStep: index) { StepImageView(id: imageID) }
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

private extension View {
    /// Reports how far a scroll view has moved past its resting position, but only when the recipe has a video.
    func trackingHeaderScroll(_ offset: Binding<CGFloat>, active: Bool) -> some View {
        onScrollGeometryChange(for: CGFloat.self) { [active] geometry in
            active ? geometry.contentOffset.y + geometry.contentInsets.top : 0
        } action: { _, value in
            offset.wrappedValue = value
        }
    }

    func trackingVideoScroll(_ scrolled: Binding<CGFloat>, active: Bool) -> some View {
        onScrollGeometryChange(for: CGFloat.self) { [active] geometry in
            active ? max(0, geometry.contentOffset.y + geometry.contentInsets.top) : 0
        } action: { _, value in
            scrolled.wrappedValue = value
        }
    }
}

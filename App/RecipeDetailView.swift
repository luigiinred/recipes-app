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
    @State private var scrollRequest = 0
    @State private var scrolled: CGFloat = 0
    @State private var topInset: CGFloat = 0
    @State private var contentWidth: CGFloat = 0
    @State private var generatingImage = false
    @Environment(\.supportsImagePlayground) private var supportsImagePlayground
    @State private var addingToGroceries = false
    @State private var addingToCalendar = false

    var body: some View {
        ScrollViewReader { proxy in
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                topSection.id("hero")
                Group {
                    TwoPaneLayout {
                        ingredients
                        steps
                    }
                    if !recipe.notes.isEmpty {
                        section("Notes") { Text(recipe.notes).foregroundStyle(.secondary) }
                    }
                    if let source = recipe.sourceURL, let url = URL(string: source) {
                        Link(destination: url) { Label(url.host ?? source, systemImage: "link") }
                    }
                }
                .padding(.horizontal, 24)
                .frame(maxWidth: 900, alignment: .leading)
                .frame(maxWidth: .infinity)
            }
            .padding(.bottom, 24)
            .textSelection(.enabled)
            .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { contentWidth = $0 }
        }
        .onGeometryChange(for: CGFloat.self) { $0.safeAreaInsets.top } action: { topInset = $0 }
        .onScrollGeometryChange(for: CGFloat.self) { [playing = player.isPlaying] geometry in
            playing ? max(0, geometry.contentOffset.y + geometry.contentInsets.top) : 0
        } action: { _, value in
            scrolled = value
        }
        .onChange(of: scrollRequest) { _, _ in
            withAnimation { proxy.scrollTo("hero", anchor: .top) }
        }
        }
        .background(.background)
        .navigationTitle(hasArtwork ? "" : recipe.title)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            if let previewSave {
                ToolbarItem { Button("Save Recipe", systemImage: "plus.circle.fill", action: previewSave) }
            } else {
                ToolbarItemGroup {
                    Button {
                        Task { await library.setFavorite(recipe, !recipe.isFavorite) }
                    } label: {
                        Label("Favorite", systemImage: recipe.isFavorite ? "heart.fill" : "heart")
                    }
                    Menu {
                        Button(recipe.wantToCook ? "Remove from Want to Cook" : "Want to Cook", systemImage: "arrow.right.circle") {
                            Task { await library.setWantToCook(recipe, !recipe.wantToCook) }
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
            RecipeEditorView(recipe: recipe) { saved, image in Task { await library.save(saved, image: image) } }
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

    private var hasArtwork: Bool {
        guard recipe.youTubeVideoID == nil else { return false }
        return previewSave != nil ? previewImage != nil : library.hasImage(recipe.id)
    }

    private var artworkImage: CGImage? {
        if previewSave != nil {
            return previewImage.flatMap { RecipeImageProcessing.thumbnail(from: $0, maxPixelSize: RecipeLibrary.thumbnailSize) }
        }
        return library.cachedThumbnail(for: recipe.id)
    }

    @ViewBuilder
    private var artwork: some View {
        if previewSave != nil, let image = artworkImage {
            Image(decorative: image, scale: 1).resizable().scaledToFill()
        } else {
            RecipeImageView(recipe: recipe)
        }
    }

    private var panelColor: Color {
        (artworkImage.flatMap(AverageColor.of) ?? Theme.accent).mix(with: .black, by: 0.35)
    }

    @ViewBuilder
    private var topSection: some View {
        if let videoID = recipe.youTubeVideoID {
            VStack(alignment: .leading, spacing: 24) {
                YouTubeEmbed(recipe: recipe, videoID: videoID, controller: player, scrolled: scrolled)
                    .zIndex(1)
                titleBlock(onImage: false)
            }
            .padding(24)
            .frame(maxWidth: 900, alignment: .leading)
            .frame(maxWidth: .infinity)
        } else if hasArtwork {
            Group {
                if contentWidth >= 700 { splitHero } else { compactHero }
            }
            .padding(.top, -topInset)
        } else {
            titleBlock(onImage: false)
                .padding(24)
                .frame(maxWidth: 900, alignment: .leading)
                .frame(maxWidth: .infinity)
        }
    }

    private var splitHero: some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 18) {
                titleBlock(onImage: true)
            }
            .padding(.top, topInset + 16).padding([.horizontal, .bottom], 24)
            .frame(width: contentWidth * 0.44)
            .frame(maxHeight: .infinity, alignment: .bottom)
            .background(LinearGradient(colors: [panelColor, panelColor.mix(with: .black, by: 0.3)], startPoint: .top, endPoint: .bottom))
            .environment(\.colorScheme, .dark)
            Color.clear.frame(maxWidth: .infinity, maxHeight: .infinity)
                .overlay { artwork }
                .clipped()
        }
        .frame(height: max(440, topInset + 400))
    }

    private var compactHero: some View {
        VStack(alignment: .leading, spacing: 18) {
            Color.clear
                .frame(height: 320 + topInset)
                .frame(maxWidth: .infinity)
                .overlay { artwork }
                .clipped()
                .overlay(alignment: .bottomLeading) {
                    LinearGradient(colors: [.clear, .black.opacity(0.6)], startPoint: .center, endPoint: .bottom)
                        .allowsHitTesting(false)
                }
                .overlay(alignment: .bottomLeading) {
                    Text(recipe.title)
                        .font(.system(.largeTitle, design: .serif, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(20)
                }
            titleBlock(onImage: false, showsTitle: false).padding(.horizontal, 24)
        }
    }

    private func titleBlock(onImage: Bool, showsTitle: Bool = true) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            if showsTitle {
                VStack(alignment: .leading, spacing: 6) {
                    Text(recipe.title).font(.system(.largeTitle, design: .serif, weight: .bold))
                    if let host = recipe.sourceURL.flatMap({ URL(string: $0)?.host }) {
                        Text(host).font(.subheadline).foregroundStyle(.secondary)
                    }
                }
            }
            statsRow
            if previewSave == nil { actionTiles(onImage: onImage) }
            if !recipe.summary.isEmpty {
                Text(recipe.summary).font(.callout).foregroundStyle(onImage ? .white.opacity(0.85) : .secondary)
            }
            if !recipe.tags.isEmpty {
                ChipFlow(spacing: 8) {
                    ForEach(recipe.tags, id: \.self) { tag in
                        Text(CategoryTree.displayName(tag))
                            .font(.caption.weight(.medium))
                            .padding(.horizontal, 10).padding(.vertical, 4)
                            .background(onImage ? Color.white.opacity(0.2) : Theme.accent.opacity(0.12), in: Capsule())
                            .foregroundStyle(onImage ? Color.white : Theme.accent)
                    }
                }
            }
        }
        .foregroundStyle(onImage ? Color.white : Color.primary)
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
                        Text(stats[index].0).font(.caption).opacity(0.7)
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

    private func actionTiles(onImage: Bool) -> some View {
        GlassEffectContainer(spacing: 10) {
            HStack(spacing: 10) {
                tile("Cook", systemImage: "frying.pan", onImage: onImage) { cook.start(recipe) }
                    .disabled(recipe.steps.isEmpty)
                tile("Groceries", systemImage: "checklist", onImage: onImage) { addingToGroceries = true }
                    .disabled(recipe.ingredients.isEmpty)
                tile("Calendar", systemImage: "calendar.badge.plus", onImage: onImage) { addingToCalendar = true }
            }
        }
    }

    private func tile(_ title: String, systemImage: String, onImage: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: systemImage).font(.title3)
                Text(title).font(.caption.weight(.medium))
            }
            .frame(maxWidth: .infinity, minHeight: 58)
            .foregroundStyle(onImage ? Color.white : Theme.accent)
            .glassEffect(onImage ? .regular.interactive() : .regular.tint(Theme.accent.opacity(0.1)).interactive(), in: RoundedRectangle(cornerRadius: 18))
        }
        .buttonStyle(.plain)
    }

    private var ingredients: some View {
        section("Ingredients") {
            VStack(alignment: .leading, spacing: 8) {
                ForEach(Array(recipe.ingredients.enumerated()), id: \.offset) { index, text in
                    HStack(alignment: .firstTextBaseline, spacing: 10) {
                        Image(systemName: checkedIngredients.contains(index) ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(checkedIngredients.contains(index) ? Theme.accent : .secondary)
                        Text(text)
                            .strikethrough(checkedIngredients.contains(index))
                            .foregroundStyle(checkedIngredients.contains(index) ? .secondary : .primary)
                            .multilineTextAlignment(.leading)
                        Spacer(minLength: 0)
                    }
                    .padding(12)
                    .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 14))
                    .contentShape(Rectangle())
                    .onTapGesture { toggle(&checkedIngredients, index) }
                    .accessibilityAddTraits(.isButton)
                }
            }
        }
    }

    private var steps: some View {
        section("Directions") {
            VStack(alignment: .leading, spacing: 22) {
                ForEach(Array(recipe.steps.enumerated()), id: \.offset) { index, text in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("STEP \(index + 1)")
                                .font(.footnote.weight(.bold))
                                .foregroundStyle(doneSteps.contains(index) ? Color.secondary : Theme.accent)
                            if doneSteps.contains(index) {
                                Image(systemName: "checkmark").font(.caption.weight(.bold)).foregroundStyle(.secondary)
                            }
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
                            .foregroundStyle(doneSteps.contains(index) ? .secondary : .primary)
                            .multilineTextAlignment(.leading)
                    }
                    .contentShape(Rectangle())
                    .onTapGesture { toggle(&doneSteps, index) }
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
            .navigationTitle("Add to Calendar")
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

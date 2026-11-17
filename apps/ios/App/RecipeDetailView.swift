import ImagePlayground
import PhotosUI
import RecipeKit
import SwiftUI

struct RecipeDetailView: View {
    @Environment(\.appAccent) private var accent
    @Environment(\.appearance) private var appearance
    @EnvironmentObject private var library: RecipeLibrary
    @EnvironmentObject private var cook: CookSession
    #if os(macOS)
    @EnvironmentObject private var router: AppRouter
    #endif
    let recipe: Recipe
    var previewSave: (() -> Void)?
    var previewImage: Data?
    var previewSaveTitle = "Save Recipe"
    var previewSaved = false
    /// Off when the page sits inside a frame that has its own Save.
    var previewSaveInToolbar = true
    var reservesArtwork = false
    /// Starts the video here, so one already playing on the loading page carries on.
    var resumesVideoAt: Int?
    /// The page card rises from the bottom of the screen, over whatever was showing while the recipe loaded.
    var risesFromBelow = false

    @Environment(\.dismiss) private var dismiss
    @State private var editing = false
    @State private var shareThumbnail: CGImage?
    @State private var mealieURL: URL?
    @AppStorage(AppSettings.Key.fontStyle) private var fontStyleRaw = FontStyle.serif.rawValue
    @State private var findingVideoRecipe = false
    @StateObject private var player = YouTubePlayerController()
    @State private var findingTimestamps = false
    @State private var timestampMessage: String?
    @State private var generatingImage = false
    @State private var choosingPhoto = false
    @State private var pickingPhoto = false
    @State private var takingPhoto = false
    @State private var pickedPhoto: PhotosPickerItem?
    @State private var viewportHeight: CGFloat = 0
    @State private var scrolled: CGFloat = 0
    @State private var topInset: CGFloat = 0
    @Environment(\.recipeZoom) private var zoom
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// False for a moment after zooming out of a card, while the page's card rises into place under the photo.
    @State private var settled = false
    /// Until a rising card is in place, the page is see-through so what's under it shows around the card.
    @State private var risen = false
    @State private var sideInsets = EdgeInsets()
    @State private var sidePaneScrolled = false
    @State private var titleScrolledAway = false
    @Environment(\.supportsImagePlayground) private var supportsImagePlayground
    @State private var addingToGroceries = false
    @State private var addingToCalendar = false
    @State private var showingTimeline = false
    @State private var editingTags = false
    @State private var scale = 1.0
    @AppStorage(AppSettings.Key.ratingStyle) private var ratingStyleRaw = RatingStyle.favorites.rawValue
    @AppStorage(AppSettings.Key.suggestCleanups) private var suggestsCleanups = true
    private var ratingStyle: RatingStyle { RatingStyle(rawValue: ratingStyleRaw) ?? .favorites }
    private var scaled: Recipe { recipe.scaled(by: scale) }
    private var pdfStyle: RecipePDF.Style {
        let font = FontStyle(rawValue: fontStyleRaw) ?? .serif
        return RecipePDF.Style(accent: accent, fontFamily: font.family, fontDesign: font.design)
    }

    var body: some View {
        #if os(macOS)
        if editing {
            RecipeEditorView(recipe: recipe, onDelete: { dismiss() }, closeInline: { editing = false }) { saved, image, steps in
                Task { await library.save(saved, image: image, steps: steps) }
            }
            .id(recipe.id)
        } else {
            page
                .onChange(of: router.editRecipeID, initial: true) { _, id in
                    guard id == recipe.id, previewSave == nil else { return }
                    router.editRecipeID = nil
                    editing = true
                }
        }
        #else
        page
        #endif
    }

    private var page: some View {
        GeometryReader { geometry in
            let fold = geometry.verticalFold
            if geometry.size.width >= 760 || fold != nil, !recipe.isIdea {
                twoColumns(width: geometry.size.width, fold: fold, trailingInset: geometry.safeAreaInsets.trailing)
            } else {
                oneColumn
            }
        }
        .collapsesSidebarWhenUnfolded()
        .task { if let resumesVideoAt, recipe.youTubeVideoID != nil { player.play(from: resumesVideoAt) } }
        .onGeometryChange(for: CGFloat.self) { $0.safeAreaInsets.top } action: { topInset = $0 }
        .onGeometryChange(for: EdgeInsets.self) { $0.safeAreaInsets } action: { sideInsets = $0 }
        .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { viewportHeight = $0 }
        .background(risesFromBelow && !risen ? AnyShapeStyle(Color.clear) : pageStyle)
        .themedCanvas(!risesFromBelow || risen)
        .onChange(of: cook.isPresented) { _, presented in
            if presented { player.pause() }
        }
        .recipeZoomDestination(recipe.id)
        .onAppear(perform: settle)
        .navigationTitle(titleScrolledAway ? recipe.title : "")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            if let previewSave {
                if previewSaveInToolbar {
                    ToolbarItem {
                        Button(previewSaved ? "Added" : previewSaveTitle, systemImage: previewSaved ? "checkmark.circle.fill" : "plus.circle.fill", action: previewSave)
                            .disabled(previewSaved)
                    }
                }
            } else {
                ToolbarItem {
                    Menu {
                        Button(recipe.isFavorite ? "Remove Favorite" : "Favorite", systemImage: recipe.isFavorite ? "heart.slash" : "heart") {
                            Task { await library.setFavorite(recipe, !recipe.isFavorite) }
                        }
                        RatingMenu(recipe: recipe)
                        Button(recipe.wantToCook ? "Remove from Up Next" : "Add to Up Next", systemImage: recipe.wantToCook ? "minus.circle" : "text.line.first.and.arrowtriangle.forward") {
                            Task { await library.setQueued(recipe, !recipe.wantToCook) }
                        }
                        Button("Timeline", systemImage: "clock.arrow.circlepath") { showingTimeline = true }
                        Divider()
                        if supportsImagePlayground, !library.hasImage(recipe.id) {
                            Button("Create a Photo…", systemImage: "apple.image.playground") { generatingImage = true }
                        }
                        Button("Print…", systemImage: "printer") { RecipePrinter.print(scaled, photo: shareThumbnail, style: pdfStyle) }
                        Menu {
                            ShareLink(item: RecipePDFDocument(recipe: scaled, photo: shareThumbnail, accent: accent, fontFamily: pdfStyle.fontFamily, fontDesign: pdfStyle.fontDesign),
                                      preview: SharePreview(recipe.title)) { Label("As a PDF", systemImage: "doc.richtext") }
                            ShareLink(item: scaled.markdown, preview: SharePreview(recipe.title)) { Label("As Text", systemImage: "text.alignleft") }
                            if let source = recipe.sourceURL.flatMap(URL.init(string:)), source.scheme?.hasPrefix("http") == true {
                                ShareLink(item: source) { Label("Original Recipe Link", systemImage: "link") }
                            }
                            if let mealieURL {
                                ShareLink(item: mealieURL) { Label("Link in My Mealie", image: "MealieLogo") }
                            }
                        } label: {
                            Label("Share", systemImage: "square.and.arrow.up")
                        }
                        if recipe.youTubeVideoID != nil, !recipe.steps.isEmpty {
                            Button(findingTimestamps ? "Finding Timestamps…" : "Find Step Timestamps", systemImage: "clock.badge.checkmark") {
                                findTimestamps()
                            }
                            .disabled(findingTimestamps)
                        }
                        if !recipe.isIdea {
                            Button("Clean Up", systemImage: "sparkles") { Task { await CleanupAdvisor.shared.checkNow(recipe) } }
                        }
                        Divider()
                        Button("Edit", systemImage: "pencil") { editing = true }
                    } label: { Label("More", systemImage: "ellipsis.circle") }
                }
            }
        }
        #if os(iOS)
        .panel(isPresented: $editing) {
            RecipeEditorView(recipe: recipe, onDelete: { dismiss() }) { saved, image, steps in Task { await library.save(saved, image: image, steps: steps) } }
        }
        #endif
        .panel(isPresented: $showingTimeline) { RecipeTimelineSheet(recipeID: recipe.id) }
        .panel(isPresented: $editingTags) { TagsSheet(recipe: recipe) }
        .alert("Step Timestamps", isPresented: Binding(get: { timestampMessage != nil }, set: { if !$0 { timestampMessage = nil } })) {
            Button("OK") { timestampMessage = nil }
        } message: {
            Text(timestampMessage ?? "")
        }
        .confirmationDialog("Add a Photo", isPresented: $choosingPhoto, titleVisibility: .visible) {
            #if os(iOS)
            if MealCamera.isAvailable { Button("Take Photo", systemImage: "camera") { takingPhoto = true } }
            #endif
            Button("Choose from Library", systemImage: "photo.on.rectangle") { pickingPhoto = true }
            if supportsImagePlayground { Button("Create a Photo…", systemImage: "apple.image.playground") { generatingImage = true } }
        }
        .photosPicker(isPresented: $pickingPhoto, selection: $pickedPhoto, matching: .images)
        .onChange(of: pickedPhoto) { _, item in
            guard let item else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self) { savePhoto(data) }
                pickedPhoto = nil
            }
        }
        #if os(macOS)
        .importsItemProviders(needsPhoto ? [.image] : []) { providers in
            guard let provider = providers.first else { return false }
            _ = provider.loadDataRepresentation(for: .image) { data, _ in
                if let data { Task { @MainActor in savePhoto(data) } }
            }
            return true
        }
        #endif
        #if os(iOS)
        .fullScreenCover(isPresented: $takingPhoto) {
            MealCamera { data in
                takingPhoto = false
                savePhoto(data)
            } onCancel: { takingPhoto = false }
            .ignoresSafeArea()
        }
        #endif
        .recipeImageGenerator(isPresented: $generatingImage, recipe: recipe) { data in
            Task { await library.save(recipe, image: .set(data)) }
        }
        .panel(isPresented: $addingToGroceries) { AddToGroceriesSheet(recipe: scaled) }
        .panel(isPresented: $addingToCalendar) { AddToCalendarSheet(recipe: recipe) }
        .overlay(alignment: .bottom) {
            if previewSave == nil, let cleanup = CleanupAdvisor.shared.suggestion(for: recipe) {
                CleanupSuggestionCard(recipe: recipe, cleanup: cleanup)
            }
        }
        .task(id: recipe.id) {
            guard previewSave == nil else { return }
            shareThumbnail = await library.loadThumbnail(for: recipe.id)
            mealieURL = await MealieRecipeLink.url(for: recipe)
        }
        .task(id: recipe.cleanupFingerprint) {
            guard previewSave == nil, suggestsCleanups else { return }
            try? await Task.sleep(for: .seconds(1))
            guard !Task.isCancelled else { return }
            await CleanupAdvisor.shared.check(recipe)
        }
    }

    private var oneColumn: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                if recipe.youTubeVideoID != nil {
                    video.padding([.horizontal, .top], 24)
                } else if hasArtwork {
                    PhotoBanner(height: Self.bannerHeight + topInset) { artwork }
                        .padding(.bottom, -Self.cardRadius)
                }
                VStack(alignment: .leading, spacing: 24) {
                    header
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
                .padding(.leading, hasArtwork ? sideInsets.leading : 0)
                .padding(.trailing, hasArtwork ? sideInsets.trailing : 0)
                .background(pageStyle, in: UnevenRoundedRectangle(topLeadingRadius: hasArtwork ? Self.cardRadius : 0, topTrailingRadius: hasArtwork ? Self.cardRadius : 0, style: .continuous))
                .offset(y: settled ? 0 : risesFromBelow ? max(viewportHeight, 600) : 32)
            }
            .textSelection(.enabled)
        }
        // The photo and the card's corners reach the screen edges; the text keeps to the safe area above.
        .ignoresSafeArea(edges: hasArtwork ? [.top, .horizontal] : [])
        .scrollEdgeEffectHidden(hasArtwork && !titleScrolledAway, for: .top)
        .trackingVideoScroll($scrolled, active: recipe.youTubeVideoID != nil)
        .onScrollGeometryChange(for: Bool.self) { $0.contentOffset.y + $0.contentInsets.top > (hasArtwork ? Self.bannerHeight : 0) + 60 } action: { _, scrolledAway in
            titleScrolledAway = scrolledAway && recipe.youTubeVideoID == nil
        }
    }

    private func settle() {
        guard !settled else { return }
        guard (zoom?.source(for: recipe.id) != nil && previewSave == nil) || risesFromBelow, !reduceMotion else { settled = true; return }
        withAnimation(.spring(response: 0.55, dampingFraction: 0.86).delay(risesFromBelow ? 0.05 : 0.12)) { settled = true } completion: { risen = true }
    }

    static let bannerHeight: CGFloat = 240
    static let cardRadius: CGFloat = 28

    private var pageStyle: AnyShapeStyle {
        appearance.canvas.map { AnyShapeStyle($0) } ?? AnyShapeStyle(.background)
    }

    /// With room to spare the recipe and its ingredients scroll on their own, so both stay in view while cooking.
    /// On an unfolded Duo the fold divides them, and the ingredients and photo run under the trailing bars.
    private func twoColumns(width: CGFloat, fold: CGRect?, trailingInset: CGFloat) -> some View {
        let sideWidth = fold.map { width - $0.maxX } ?? min(420, max(320, width * 0.36))
        return HStack(alignment: .top, spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    if recipe.youTubeVideoID != nil { video }
                    header
                    steps
                    footer
                }
                .padding(24)
                .frame(maxWidth: 720, alignment: .leading)
                .frame(maxWidth: .infinity)
            }
            .trackingVideoScroll($scrolled, active: recipe.youTubeVideoID != nil)
            .frame(width: fold?.minX)
            if let fold {
                Color.clear.frame(width: fold.width)
            } else {
                Divider()
            }
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    if hasArtwork {
                        Color.clear
                            .frame(height: 280 + topInset)
                            .frame(maxWidth: .infinity)
                            .overlay { artwork }
                            .clipped()
                    }
                    ingredients.padding(24).padding(.trailing, trailingInset)
                }
            }
            .ignoresSafeArea(edges: .top)
            .scrollEdgeEffectHidden(!sidePaneScrolled, for: .top)
            .onScrollGeometryChange(for: Bool.self) { $0.contentOffset.y + $0.contentInsets.top > 1 } action: { _, scrolled in
                sidePaneScrolled = scrolled
            }
            .frame(width: sideWidth + trailingInset)
            .background(.quaternary.opacity(0.25))
        }
        .ignoresSafeArea(edges: .trailing)
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
            YouTubeEmbed(recipe: recipe, videoID: videoID, controller: player, scrolled: scrolled, viewportHeight: viewportHeight)
                .zIndex(1)
        }
    }

    private var hasArtwork: Bool {
        guard recipe.youTubeVideoID == nil else { return false }
        if reservesArtwork { return true }
        // A recipe of yours always has the photo space; without a photo it asks for one.
        return previewSave != nil ? previewImage != nil : true
    }

    private var needsPhoto: Bool { previewSave == nil && !reservesArtwork && !library.hasImage(recipe.id) }

    @ViewBuilder
    private var artwork: some View {
        if previewSave != nil, let data = previewImage,
           let image = RecipeImageProcessing.thumbnail(from: data, maxPixelSize: RecipeLibrary.thumbnailSize) {
            Image(decorative: image, scale: 1).resizable().scaledToFill()
        } else if reservesArtwork {
            Color.secondary.opacity(0.12)
        } else if needsPhoto {
            Button { choosingPhoto = true } label: {
                accent.opacity(0.12)
                    .overlay {
                        Label("Add a Photo", systemImage: "camera")
                            .appFont(.headline)
                            .foregroundStyle(accent)
                            .padding(.top, topInset)
                            .padding(.bottom, Self.cardRadius)
                    }
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("recipe.addPhoto")
        } else {
            RecipeImageView(recipe: recipe)
        }
    }

    private func savePhoto(_ data: Data) {
        guard let jpeg = RecipeImageProcessing.jpegData(from: data) else { return }
        Task { await library.save(recipe, image: .set(jpeg)) }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 12) {
                Text(recipe.title)
                    .appFont(.largeTitle, weight: .bold)
                    .accessibilityAddTraits(.isHeader)
                tagChips
            }
            statsRow
            if previewSave == nil, ratingStyle == .stars || recipe.rating != nil {
                StarRatingView(rating: recipe.rating) { value in Task { await library.setRating(recipe, value) } }
            }
            if previewSave == nil { actionTiles }
            if !recipe.summary.isEmpty {
                Text(recipe.summary).appFont(.callout).foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private var tagChips: some View {
        if previewSave != nil {
            if !recipe.tags.isEmpty {
                ChipFlow { ForEach(recipe.tags, id: \.self) { tagChip($0) } }
            }
        } else {
            ChipFlow {
                ForEach(recipe.tags, id: \.self) { tag in
                    NavigationLink { TagRecipesPage(tag: tag) } label: { tagChip(tag) }
                        .buttonStyle(.plain)
                        .accessibilityHint("Shows recipes with this tag")
                        .contextMenu { Button("Edit Tags…", systemImage: "tag") { editingTags = true } }
                }
                Button { editingTags = true } label: {
                    Label(recipe.tags.isEmpty ? "Add Tags" : "Add", systemImage: "plus")
                        .appFont(.footnote, weight: .medium)
                        .labelStyle(.titleAndIcon)
                        .padding(.horizontal, 12).padding(.vertical, 6)
                        .overlay { Capsule().strokeBorder(Theme.accent.opacity(0.5), style: StrokeStyle(lineWidth: 1, dash: [4, 3])) }
                        .foregroundStyle(Theme.accent)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func tagChip(_ tag: String) -> some View {
        Text(CategoryTree.displayName(tag))
            .appFont(.footnote, weight: .medium)
            .tagChip()
    }

    @ViewBuilder
    private var statsRow: some View {
        let stats: [(String, String)] = [
            recipe.totalMinutes.map { ("Total Time", Self.duration($0)) },
            recipe.cookMinutes.map { ("Cook Time", Self.duration($0)) },
            scaled.servings.map { ("Servings", "\($0)") },
        ].compactMap { $0 }
        if !stats.isEmpty {
            HStack(spacing: 0) {
                ForEach(stats.indices, id: \.self) { index in
                    if index > 0 { Divider().frame(height: 34).padding(.horizontal, 14) }
                    VStack(alignment: .leading, spacing: 2) {
                        Text(stats[index].0).appFont(.caption).foregroundStyle(.secondary)
                        Text(stats[index].1).appFont(.title3, weight: .medium)
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
                    tile("Cook", systemImage: "frying.pan", prominent: true) { cook.start(recipe, scale: scale) }
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
                Image(systemName: systemImage).appFont(.title3)
                Text(title).appFont(.caption, weight: .medium)
            }
            .frame(maxWidth: .infinity, minHeight: 58)
            .foregroundStyle(prominent ? AnyShapeStyle(Color.white) : AnyShapeStyle(Theme.accent))
            .glassEffect(
                prominent ? .regular.tint(accent).interactive() : .regular.tint(accent.opacity(0.1)).interactive(),
                in: RoundedRectangle(cornerRadius: 18)
            )
        }
        .buttonStyle(.plain)
    }

    private var ideaNote: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Just an idea so far", systemImage: "lightbulb").appFont(.headline)
            Text("Add ingredients and steps when you have a recipe for it, and this becomes a full recipe.")
                .foregroundStyle(.secondary)
            if previewSave == nil {
                if recipe.youTubeVideoID != nil {
                    Button(findingVideoRecipe ? "Looking…" : "Find the Recipe in This Video", systemImage: "sparkles") {
                        findingVideoRecipe = true
                        Task {
                            await VideoRecipeFinder.findRecipe(for: recipe, in: library)
                            findingVideoRecipe = false
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(findingVideoRecipe)
                }
                Button("Add Ingredients and Steps", systemImage: "pencil") { editing = true }
                    .buttonStyle(.bordered)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 14))
    }

    private var ingredients: some View {
        section("Ingredients", trailing: { if previewSave == nil, !recipe.ingredients.isEmpty { ScaleMenu(scale: $scale) } }) {
            VStack(alignment: .leading, spacing: 8) {
                ForEach(Array(scaled.ingredientGroups.enumerated()), id: \.offset) { _, group in
                    if let title = group.title {
                        Text(title)
                            .appFont(.subheadline, weight: .semibold)
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
                        .contentShape(RoundedRectangle(cornerRadius: 14))
                        .textSelection(.disabled)
                        .conversionMenu(for: text)
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
                                .appFont(.footnote, weight: .bold)
                                .foregroundStyle(Theme.accent)
                            Spacer(minLength: 0)
                            if recipe.youTubeVideoID != nil, let seconds = recipe.timestamp(forStep: index) {
                                Button {
                                    player.play(from: seconds)
                                } label: {
                                    Label(Recipe.clock(seconds), systemImage: "play.fill")
                                        .appFont(.caption, weight: .semibold).monospacedDigit()
                                        .padding(.horizontal, 9).padding(.vertical, 5)
                                        .background(Theme.accent.opacity(0.12), in: Capsule())
                                        .foregroundStyle(Theme.accent)
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel("Play from \(Recipe.clock(seconds))")
                            }
                        }
                        Text(text)
                            .appFont(.body)
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
        section(title, trailing: { EmptyView() }, content: content)
    }

    private func section<Trailing: View, Content: View>(
        _ title: String, @ViewBuilder trailing: () -> Trailing, @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(title.uppercased()).appFont(.caption, weight: .semibold).foregroundStyle(.secondary).tracking(1)
                Spacer()
                trailing()
            }
            content()
        }
    }
}

struct AddToCalendarSheet: View {
    @EnvironmentObject private var library: RecipeLibrary
    @SheetDismiss private var dismiss
    private let title: String
    private let add: @MainActor (RecipeLibrary, Date, Meal) async -> Void

    init(recipe: Recipe) {
        title = "Add to Planner"
        add = { await $0.plan(recipe, on: $1, meal: $2) }
    }

    init(text: String) {
        title = "Plan “\(text)”"
        add = { await $0.plan(text: text, on: $1, meal: $2) }
    }

    init(note: UpNextNote) {
        title = "Plan “\(note.title)”"
        add = { await $0.plan(note, on: $1, meal: $2) }
    }

    @State private var day = Date()
    @State private var meal = AppSettings.defaultMeal()

    var body: some View {
        NavigationStack {
            ThemedForm {
                DatePicker("Day", selection: $day, displayedComponents: .date)
                Picker("Meal", selection: $meal) {
                    ForEach(Meal.allCases, id: \.self) { Label($0.title, systemImage: $0.symbol).tag($0) }
                }
            }
            .formStyle(.grouped)
            .panelTitle(title)
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { CancelButton() }
                ToolbarItem(placement: .confirmationAction) {
                    ConfirmButton(title: "Add") {
                        Task { await add(library, day, meal) }
                        dismiss()
                    }
                }
            }
        }
        #if os(macOS)
        .sheetFrame(minWidth: 380, minHeight: 240)
        #endif
    }
}

private extension View {
    func trackingVideoScroll(_ scrolled: Binding<CGFloat>, active: Bool) -> some View {
        onScrollGeometryChange(for: CGFloat.self) { [active] geometry in
            active ? max(0, geometry.contentOffset.y + geometry.contentInsets.top) : 0
        } action: { _, value in
            scrolled.wrappedValue = value
        }
    }
}

/// The photo at the top of the page, which runs up behind the navigation bar.
/// Scrolling moves it at half speed, so what's left in view stays centered as the page covers it;
/// pulling past the top grows it from its bottom edge, cropping the sides, so no gap opens above.
/// It reads its place in the scroll view as it's drawn, so it keeps up with a bounce frame by frame.
private struct PhotoBanner<Artwork: View>: View {
    let height: CGFloat
    @ViewBuilder let artwork: Artwork

    var body: some View {
        Color.clear
            .frame(maxWidth: .infinity)
            .frame(height: height)
            .overlay {
                artwork
                    .visualEffect { content, proxy in
                        let pulled = proxy.frame(in: .scrollView(axis: .vertical)).minY
                        return content
                            .scaleEffect(pulled > 0 ? 1 + pulled / proxy.size.height : 1, anchor: .bottom)
                            .offset(y: pulled < 0 ? -pulled / 2 : 0)
                    }
            }
            .mask(alignment: .bottom) { Rectangle().frame(height: 10_000) }
    }
}

/// Every recipe with a tag, opened from a tag on a recipe page; a recipe tapped here opens on top.
struct TagRecipesPage: View {
    @EnvironmentObject private var library: RecipeLibrary
    let tag: String
    @State private var collection: RecipeCollection
    @State private var selection: Recipe.ID?

    init(tag: String) {
        self.tag = tag
        _collection = State(initialValue: .category(tag))
    }

    var body: some View {
        RecipeListView(collection: $collection, selection: $selection)
            .navigationDestination(item: $selection) { id in
                if let recipe = library.recipe(id: id) { RecipeDetailView(recipe: recipe).id(id) }
            }
    }
}

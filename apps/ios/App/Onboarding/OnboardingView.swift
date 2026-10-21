import RecipeKit
import SwiftUI

struct OnboardingView: View {
    @Environment(\.appAccent) private var accent
    enum Step: Int, CaseIterable {
        case welcome, share, organize, cook, add, tryIt, discover
    }

    @EnvironmentObject private var library: RecipeLibrary
    let onFinish: () -> Void
    private let loadsPreviews: Bool

    @State private var step: Step
    @State private var reviewing: ScanDraft?
    @State private var importing: OnboardingSource?
    @State private var importTask: Task<Void, Never>?
    @State private var failures: [OnboardingSource.ID: String] = [:]
    @State private var previews: [OnboardingSource.ID: ImportResult] = [:]
    @State private var covers: [OnboardingSource.ID: CGImage] = [:]
    @State private var isLoadingPreviews = false
    @StateObject private var progress = ImportProgressModel()

    init(step: Step = .welcome, loadsPreviews: Bool = true, onFinish: @escaping () -> Void) {
        _step = State(initialValue: step)
        self.loadsPreviews = loadsPreviews
        self.onFinish = onFinish
    }

    private func savedRecipe(for source: OnboardingSource) -> Recipe? {
        library.recipes.first(where: source.matches)
    }

    private var addedRecipes: [Recipe] {
        OnboardingSources.all.compactMap(savedRecipe)
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                page
                    .frame(maxWidth: 560)
                    .padding(.horizontal, 24)
                    .padding(.top, 32)
                    .padding(.bottom, 16)
                    .frame(maxWidth: .infinity)
                    .id(step)
                    .transition(.opacity)
            }
            .scrollBounceBehavior(.basedOnSize)
            footer
        }
        .paperBackground()
        .animation(.snappy, value: step)
        .task { await loadPreviews() }
        #if os(macOS)
        .frame(width: 560, height: 700)
        #endif
        .overlay { if let importing { importCard(importing) } }
        .sheet(item: $reviewing) { draft in
            RecipeEditorView(
                recipe: draft.recipe, scannedText: draft.text, scannedTextTitle: draft.textTitle, notice: draft.notice,
                initialImage: draft.imageData, initialStepImages: draft.stepImages
            ) { saved, image, steps in
                Task { await library.save(saved, image: image, steps: steps) }
            }
        }
    }

    @ViewBuilder
    private var page: some View {
        switch step {
        case .welcome: welcome
        case .share: share
        case .organize: organize
        case .cook: cook
        case .add: add
        case .tryIt: tryIt
        case .discover: discover
        }
    }

    // MARK: Pages

    private var welcome: some View {
        VStack(spacing: 24) {
            VStack(spacing: 12) {
                (Text("Good food happens ") + Text("here.").foregroundStyle(Theme.accent))
                    .font(.system(size: 40, weight: .bold))
                    .multilineTextAlignment(.center)
                    .accessibilityAddTraits(.isHeader)
                Text("Save, organize, and cook the recipes you love.")
                    .font(.body).foregroundStyle(.secondary).multilineTextAlignment(.center)
            }
            stage(decorations: [.basil, .garlic, .broccoli]) { MascotCluster(height: 220) }
            VStack(alignment: .leading, spacing: 18) {
                feature("globe", "Import from anywhere", "Paste a link from a recipe site or a YouTube video, or share one straight from Safari.")
                feature("doc.viewfinder", "Scan a cookbook page", "Read a page with the camera, or import a photo or PDF.")
                feature("square.and.pencil", "Write your own", "Ingredients and steps are kept in one tidy format, however a recipe arrives.")
            }
        }
    }

    private var share: some View {
        VStack(spacing: 22) {
            header(mascot: .tomatoTablet, title: "Save any recipe",
                   subtitle: "Found a recipe in Safari or a video on YouTube? Share it with Recipes to import it.")
            ShareSheetMock(cover: OnboardingSources.all.first.flatMap { covers[$0.id] })
            VStack(alignment: .leading, spacing: 18) {
                shareStep(1, "Open the recipe", "A recipe page in Safari, or a video in YouTube.")
                shareStep(2, "Tap Share", "The square with an arrow, in the toolbar. On a Mac it's in Safari's toolbar too.")
                shareStep(3, "Choose Save to Recipes", "Swipe along the row of apps. If you don't see it, tap More and turn it on.")
                shareStep(4, "Check it over", "Recipes opens the editor with everything filled in. Tap the checkmark to save.")
            }
            Text("You can also paste a link from the Recipes toolbar.")
                .font(.footnote).foregroundStyle(.secondary).multilineTextAlignment(.center)
        }
    }

    private var organize: some View {
        VStack(spacing: 24) {
            header(title: "Keep it organized", subtitle: "Find your recipes anytime with favorites, categories and a plan for the week.")
            stage(decorations: [.carrot, .basil, .peaPod]) {
                HStack(alignment: .center, spacing: 6) {
                    MascotView(mascot: .potato, height: 190)
                    CollectionStack()
                }
            }
            VStack(alignment: .leading, spacing: 18) {
                feature("heart", "Favorites or stars", "Mark what you love, or rate recipes from one to five stars.")
                feature("tag", "Categories", "File recipes in nested categories like Dinner/Pasta.")
                feature("text.line.first.and.arrowtriangle.forward", "Up Next", "Queue what you want to cook soon, and plan it on a day when you're ready.")
            }
        }
    }

    private var cook: some View {
        VStack(spacing: 24) {
            header(title: "Cook with confidence", subtitle: "Big step-by-step text, timers found for you, and the screen stays awake.")
            stage(decorations: [.garlic, .redPepper, .basil]) {
                VStack(spacing: -14) {
                    CookStepCard()
                    HStack(alignment: .bottom, spacing: 18) {
                        MascotView(mascot: .lemon, height: 130)
                        MascotView(mascot: .chili, height: 150)
                    }
                    .zIndex(1)
                }
            }
            VStack(alignment: .leading, spacing: 18) {
                feature("timer", "Timers in the steps", "Tap a time like “10 minutes” to start a timer.")
                feature("checklist.checked", "Ingredients close by", "A floating button keeps the ingredient list one tap away.")
                feature("arrow.left.arrow.right", "Unit conversions", "Press and hold an ingredient to see it in other units.")
            }
        }
    }

    private var add: some View {
        VStack(spacing: 24) {
            header(mascot: .tomatoLaptop, title: "Let's add your first recipe!",
                   subtitle: "Tap a recipe to import it the same way, check it over, then tap the checkmark to save it.")
            VStack(spacing: 16) {
                ForEach(OnboardingSources.all) { source in sourceCard(source) }
            }
        }
    }

    private var tryIt: some View {
        VStack(spacing: 24) {
            header(mascot: .tomatoGroceries, title: "Make it yours",
                   subtitle: addedRecipes.first.map { "Try two things on \($0.title). You can undo both from the app any time." }
                       ?? "Try two things on a recipe. You can undo both from the app any time.")
            if let recipe = addedRecipes.first {
                RecipeCard(recipe: recipe).frame(maxWidth: 320)
                VStack(spacing: 14) {
                    TryCard(
                        symbol: "text.line.first.and.arrowtriangle.forward", title: "Up Next",
                        detail: "Queue what you want to cook soon. A recipe leaves the queue once you plan it on a day.",
                        action: recipe.wantToCook ? "In Up Next" : "Add to Up Next", isDone: recipe.wantToCook
                    ) { Task { await library.setQueued(recipe, !recipe.wantToCook) } }
                    TryCard(
                        symbol: "checklist", title: "Groceries",
                        detail: "Send a recipe's ingredients to your shopping list, which stays in sync with the Reminders app.",
                        action: inGroceries(recipe) ? "Added to Groceries" : "Add the ingredients", isDone: inGroceries(recipe)
                    ) {
                        guard !inGroceries(recipe) else { return }
                        Task { await library.addGroceries(recipe.ingredients.map { GroceryItem(parsing: $0, recipeID: recipe.id) }) }
                    }
                }
            } else {
                ContentUnavailableView("No recipe yet", systemImage: "fork.knife", description: Text("Go back and add one to try these out."))
            }
        }
    }

    private var discover: some View {
        VStack(spacing: 28) {
            VStack(spacing: 12) {
                MascotCluster(height: 150)
                Text("You're all set!")
                    .font(.system(.largeTitle, weight: .bold))
                    .multilineTextAlignment(.center)
                    .accessibilityAddTraits(.isHeader)
                Text("A few things worth knowing about as you settle in.")
                    .font(.body).foregroundStyle(.secondary).multilineTextAlignment(.center)
            }
            VStack(alignment: .leading, spacing: 22) {
                feature("frying.pan", "Cook mode", "Tap Cook on a recipe for big step-by-step text. Timers in the steps are found for you, and the screen stays awake.")
                feature("calendar", "The planner", "Drag recipes into meals for the week, or tap Plan on a recipe.")
                feature("sparkles", "Apple Intelligence", "Group a long ingredient list into sections, turn a video's captions into a recipe, and create photos. Settings shows what's ready on this device.")
                feature("mic", "Siri and Shortcuts", "Save a recipe from a link, start cooking, or add ingredients to your groceries by voice.")
            }
        }
    }

    // MARK: Pieces

    private func header(mascot: Mascot? = nil, title: String, subtitle: String) -> some View {
        VStack(spacing: 12) {
            if let mascot { MascotView(mascot: mascot, height: 150) }
            Text(title)
                .font(.system(.largeTitle, weight: .bold))
                .multilineTextAlignment(.center)
                .accessibilityAddTraits(.isHeader)
            Text(subtitle)
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
    }

    /// A soft rounded panel behind the illustration, with a few ingredients sitting around its edges.
    private func stage<Content: View>(decorations: [Mascot], @ViewBuilder content: () -> Content) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .fill(LinearGradient(colors: [accent.opacity(0.14), accent.opacity(0.04)], startPoint: .top, endPoint: .bottom))
            GeometryReader { geometry in
                ForEach(Array(decorations.enumerated()), id: \.offset) { index, mascot in
                    MascotView(mascot: mascot, height: 36)
                        .rotationEffect(.degrees(Double(index) * 37 - 30))
                        .opacity(0.9)
                        .position(
                            x: [geometry.size.width * 0.1, geometry.size.width * 0.9, geometry.size.width * 0.14][index % 3],
                            y: [geometry.size.height * 0.14, geometry.size.height * 0.22, geometry.size.height * 0.88][index % 3]
                        )
                }
            }
            content().padding(.vertical, 24).padding(.horizontal, 12)
        }
        .frame(maxWidth: .infinity)
    }

    private func feature(_ symbol: String, _ title: String, _ detail: String) -> some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: symbol)
                .font(.title2)
                .foregroundStyle(Theme.accent)
                .frame(width: 34)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.headline)
                Text(detail).font(.subheadline).foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
    }

    private func shareStep(_ number: Int, _ title: String, _ detail: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Text("\(number)")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(.white)
                .frame(width: 26, height: 26)
                .background(Theme.accent, in: Circle())
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.headline)
                Text(detail).font(.subheadline).foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
    }

    private func sourceCard(_ source: OnboardingSource) -> some View {
        let saved = savedRecipe(for: source)
        return Button { startImport(source) } label: {
            VStack(alignment: .leading, spacing: 10) {
                ZStack(alignment: .topTrailing) {
                    Color.clear
                        .aspectRatio(2, contentMode: .fit)
                        .overlay { sourceImage(source, saved: saved) }
                        .clipShape(RoundedRectangle(cornerRadius: 18))
                    Image(systemName: saved != nil ? "checkmark.circle.fill" : "arrow.down.circle.fill")
                        .font(.title)
                        .symbolRenderingMode(.palette)
                        .foregroundStyle(Color.white, saved != nil ? accent : Color.black.opacity(0.45))
                        .symbolEffect(.bounce, value: saved != nil)
                        .padding(10)
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text(source.title).font(.system(.title3, weight: .semibold)).foregroundStyle(.primary)
                    Text(source.site).font(.caption.weight(.medium)).foregroundStyle(Theme.accent)
                    if let failure = failures[source.id] {
                        Text(failure).font(.caption).foregroundStyle(.red).lineLimit(2)
                    } else {
                        Text(source.detail).font(.subheadline).foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal, 4)
            }
            .multilineTextAlignment(.leading)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(10)
            .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .allowsHitTesting(saved == nil && importing == nil)
        .accessibilityLabel(saved != nil ? "\(source.title), added" : "Import \(source.title) from \(source.site)")
    }

    @ViewBuilder
    private func sourceImage(_ source: OnboardingSource, saved: Recipe?) -> some View {
        if let saved {
            RecipeImageView(recipe: saved)
        } else {
            ZStack {
                LinearGradient(colors: [accent.opacity(0.22), accent.opacity(0.08)], startPoint: .topLeading, endPoint: .bottomTrailing)
                if let cover = covers[source.id] {
                    Image(decorative: cover, scale: 1).resizable().scaledToFill().transition(.opacity)
                } else if isLoadingPreviews, previews[source.id] == nil {
                    ProgressView()
                } else {
                    Image(systemName: source.kind == .video ? "play.rectangle.fill" : "fork.knife")
                        .font(.largeTitle).foregroundStyle(Theme.accent.opacity(0.45))
                }
                if source.kind == .video, covers[source.id] != nil {
                    Image(systemName: "play.circle.fill").font(.system(size: 44)).foregroundStyle(.white.opacity(0.9)).shadow(radius: 4)
                }
            }
            .animation(.easeOut, value: covers[source.id] != nil)
        }
    }

    private func loadPreviews() async {
        guard loadsPreviews else { return }
        isLoadingPreviews = true
        defer { isLoadingPreviews = false }
        let pending = OnboardingSources.all.filter { previews[$0.id] == nil }
        await withTaskGroup(of: (OnboardingSource.ID, ImportResult?).self) { group in
            for source in pending {
                group.addTask { (source.id, try? await RecipeImporter.importResult(from: source.url)) }
            }
            for await (id, result) in group {
                guard let result else { continue }
                previews[id] = result
                covers[id] = result.imageData.flatMap { RecipeImageProcessing.thumbnail(from: $0, maxPixelSize: 900) }
            }
        }
    }

    private func importCard(_ source: OnboardingSource) -> some View {
        ScrollView {
            ImportLoadingView(title: "Importing recipe…", subtitle: source.title, model: progress, cancel: cancelImport)
                .frame(maxWidth: .infinity)
                .padding(.top, 40)
        }
        .scrollBounceBehavior(.basedOnSize)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .paperBackground()
        .transition(.opacity)
    }

    private func cancelImport() {
        importTask?.cancel()
        importTask = nil
        importing = nil
    }

    private func startImport(_ source: OnboardingSource) {
        guard importing == nil else { return }
        if let result = previews[source.id] {
            reviewing = draft(from: result)
            return
        }
        importing = source
        failures[source.id] = nil
        progress.reset()
        importTask = Task {
            do {
                let result = try await RecipeImporter.importResult(from: source.url, progress: progress.report)
                guard !Task.isCancelled else { return }
                reviewing = draft(from: result)
            } catch {
                if !Task.isCancelled { failures[source.id] = error.localizedDescription }
            }
            if !Task.isCancelled { importing = nil }
        }
    }

    private func draft(from result: ImportResult) -> ScanDraft {
        ScanDraft(
            recipe: result.recipe, text: result.sourceText, textTitle: result.sourceTitle,
            notice: result.message, imageData: result.imageData, stepImages: result.stepImageData
        )
    }

    private func inGroceries(_ recipe: Recipe) -> Bool {
        library.groceries.contains { $0.recipeID == recipe.id }
    }

    private var footer: some View {
        VStack(spacing: 12) {
            HStack(spacing: 8) {
                ForEach(Step.allCases, id: \.self) { item in
                    Capsule()
                        .fill(item == step ? AnyShapeStyle(Theme.accent) : AnyShapeStyle(Color.secondary.opacity(0.3)))
                        .frame(width: item == step ? 22 : 8, height: 8)
                }
            }
            .accessibilityHidden(true)
            Button(action: advance) { Text(primaryTitle) }
                .buttonStyle(PaperButtonStyle())
                .frame(maxWidth: 400)
                .disabled(step == .add && addedRecipes.isEmpty)
            if step == .add && addedRecipes.isEmpty {
                Text("Add at least one recipe to continue.").font(.footnote).foregroundStyle(.secondary)
            }
            Button("Skip Tour", action: onFinish)
                .buttonStyle(.plain)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .opacity(step == .discover ? 0 : 1)
                .disabled(step == .discover)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity)
        .animation(.snappy, value: step)
    }

    private var primaryTitle: String {
        switch step {
        case .welcome: "Get Started"
        case .share, .organize, .cook: "Next"
        case .add, .tryIt: "Continue"
        case .discover: "Start Cooking"
        }
    }

    private func advance() {
        if let next = Step(rawValue: step.rawValue + 1) { step = next } else { onFinish() }
    }
}

private struct TryCard: View {
    let symbol: String
    let title: String
    let detail: String
    let action: String
    let isDone: Bool
    let perform: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(title, systemImage: symbol).font(.headline).foregroundStyle(Theme.accent)
            Text(detail).font(.subheadline).foregroundStyle(.secondary)
            Button(action: perform) {
                Label(action, systemImage: isDone ? "checkmark.circle.fill" : "plus.circle.fill").frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
            .sensoryFeedback(.success, trigger: isDone)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 16))
    }
}

/// Collections as a tilted stack of cards.
private struct CollectionStack: View {
    private static let items: [(name: String, symbol: String, color: Color)] = [
        ("Favorites", "heart.fill", Color(red: 0.93, green: 0.36, blue: 0.33)),
        ("Weeknight", "fork.knife", Color(red: 0.36, green: 0.55, blue: 0.86)),
        ("Breakfast", "sun.max.fill", Color(red: 0.93, green: 0.72, blue: 0.20)),
        ("Desserts", "birthday.cake.fill", Color(red: 0.84, green: 0.45, blue: 0.68)),
    ]

    var body: some View {
        VStack(spacing: 6) {
            ForEach(Array(Self.items.enumerated()), id: \.offset) { index, item in
                HStack(spacing: 8) {
                    Image(systemName: item.symbol)
                    Text(item.name).font(.system(.subheadline, weight: .semibold))
                    Spacer(minLength: 0)
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 12).padding(.vertical, 9)
                .frame(width: 150)
                .background(item.color.gradient, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .rotationEffect(.degrees(index.isMultiple(of: 2) ? -2.5 : 2))
                .shadow(color: .black.opacity(0.12), radius: 3, y: 2)
            }
        }
        .accessibilityHidden(true)
    }
}

/// A small copy of cook mode's step with its timer.
private struct CookStepCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Step 3 of 5").font(.caption).foregroundStyle(.secondary)
            (Text("Simmer for ") + Text("\u{23F2}\u{FE0E} 10 minutes").foregroundStyle(Theme.accent) + Text(" until thickened."))
                .font(.system(.title3, weight: .medium))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(.background, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: .black.opacity(0.1), radius: 6, y: 3)
        .padding(.horizontal, 8)
        .accessibilityElement(children: .combine)
    }
}

/// A stand-in for Safari's share sheet with Save to Recipes highlighted.
private struct ShareSheetMock: View {
    @Environment(\.appAccent) private var accent
    let cover: CGImage?

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                ZStack {
                    LinearGradient(colors: [accent.opacity(0.22), accent.opacity(0.08)], startPoint: .topLeading, endPoint: .bottomTrailing)
                    if let cover { Image(decorative: cover, scale: 1).resizable().scaledToFill() }
                }
                .frame(width: 56, height: 56)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                VStack(alignment: .leading, spacing: 2) {
                    Text("World's Best Lasagna").font(.subheadline.weight(.semibold))
                    Text("allrecipes.com").font(.caption).foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
                Image(systemName: "xmark.circle.fill").foregroundStyle(.tertiary)
            }
            .padding(14)
            Divider()
            HStack(alignment: .top, spacing: 18) {
                appIcon("message.fill", "Messages", .green)
                appIcon("envelope.fill", "Mail", .blue)
                appIcon("note.text", "Notes", .yellow)
                appIcon("fork.knife", "Save to Recipes", accent, highlighted: true)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 16)
        }
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20))
        .overlay(RoundedRectangle(cornerRadius: 20).strokeBorder(.quaternary))
        .frame(maxWidth: 360)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Example share sheet with Save to Recipes in the row of apps")
    }

    private func appIcon(_ symbol: String, _ name: String, _ color: Color, highlighted: Bool = false) -> some View {
        VStack(spacing: 6) {
            Image(systemName: symbol)
                .font(.title3)
                .foregroundStyle(.white)
                .frame(width: 52, height: 52)
                .background(color.gradient, in: RoundedRectangle(cornerRadius: 12))
                .overlay {
                    if highlighted { RoundedRectangle(cornerRadius: 16).strokeBorder(Theme.accent, lineWidth: 2.5).padding(-5) }
                }
            Text(name)
                .font(.caption2.weight(highlighted ? .semibold : .regular))
                .foregroundStyle(highlighted ? AnyShapeStyle(Theme.accent) : AnyShapeStyle(.secondary))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }
}

/// Shows the tour once, on the first launch with an empty library.
private struct OnboardingGate: ViewModifier {
    @EnvironmentObject private var library: RecipeLibrary
    @AppStorage(AppSettings.Key.onboardingCompleted) private var completed = false
    @State private var isPresented = false

    func body(content: Content) -> some View {
        content
            .onChange(of: library.isLoaded, initial: true) { _, loaded in
                guard loaded, !completed else { return }
                if library.recipes.isEmpty { isPresented = true } else { completed = true }
            }
            #if os(iOS)
            .fullScreenCover(isPresented: $isPresented) { tour }
            #else
            .sheet(isPresented: $isPresented) { tour }
            #endif
    }

    private var tour: some View {
        OnboardingView { completed = true; isPresented = false }
            .interactiveDismissDisabled()
    }
}

extension View {
    func onboardingTour() -> some View { modifier(OnboardingGate()) }
}

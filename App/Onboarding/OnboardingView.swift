import RecipeKit
import SwiftUI

struct OnboardingView: View {
    enum Step: Int, CaseIterable {
        case welcome, share, add, tryIt, discover
    }

    @EnvironmentObject private var library: RecipeLibrary
    let onFinish: () -> Void
    private let loadsPreviews: Bool

    @State private var step: Step
    @State private var reviewing: ScanDraft?
    @State private var importing: OnboardingSource?
    @State private var failures: [OnboardingSource.ID: String] = [:]
    @State private var previews: [OnboardingSource.ID: ImportResult] = [:]
    @State private var covers: [OnboardingSource.ID: CGImage] = [:]
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
        .background(.background)
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
        case .add: add
        case .tryIt: tryIt
        case .discover: discover
        }
    }

    // MARK: Pages

    private var welcome: some View {
        VStack(spacing: 28) {
            header(symbol: "book.closed.fill", title: "Welcome to Recipes",
                   subtitle: "Collect recipes from anywhere, plan your week, and cook without losing your place.")
            VStack(alignment: .leading, spacing: 22) {
                feature("globe", "Import from anywhere", "Paste a link from a recipe site or a YouTube video, or share one straight from Safari.")
                feature("doc.viewfinder", "Scan a cookbook page", "Read a page with the camera, or import a photo or PDF.")
                feature("square.and.pencil", "Write your own", "Ingredients and steps are kept in one tidy format, however a recipe arrives.")
            }
        }
    }

    private var share: some View {
        VStack(spacing: 24) {
            header(symbol: "square.and.arrow.up", title: "Share to add recipes",
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

    private var add: some View {
        VStack(spacing: 24) {
            header(symbol: "plus.circle.fill", title: "Try it on a real recipe",
                   subtitle: "Tap a recipe to import it the same way, check it over, then tap the checkmark to save it.")
            VStack(spacing: 16) {
                ForEach(OnboardingSources.all) { source in sourceCard(source) }
            }
        }
    }

    private var tryIt: some View {
        VStack(spacing: 24) {
            header(symbol: "sparkles", title: "Make it yours",
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
            header(symbol: "wand.and.stars", title: "There's more to find",
                   subtitle: "A few things worth knowing about as you settle in.")
            VStack(alignment: .leading, spacing: 22) {
                feature("frying.pan", "Cook mode", "Tap Cook on a recipe for big step-by-step text. Timers in the steps are found for you, and the screen stays awake.")
                feature("calendar", "The planner", "Drag recipes into meals for the week, or tap Plan on a recipe.")
                feature("sparkles", "Apple Intelligence", "Group a long ingredient list into sections, turn a video's captions into a recipe, and create photos. Settings shows what's ready on this device.")
                feature("mic", "Siri and Shortcuts", "Save a recipe from a link, start cooking, or add ingredients to your groceries by voice.")
            }
        }
    }

    // MARK: Pieces

    private func header(symbol: String, title: String, subtitle: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: symbol)
                .font(.system(size: 52))
                .foregroundStyle(Theme.accent)
                .accessibilityHidden(true)
            Text(title)
                .font(.system(.largeTitle, design: .serif, weight: .bold))
                .multilineTextAlignment(.center)
                .accessibilityAddTraits(.isHeader)
            Text(subtitle)
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
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
                        .foregroundStyle(saved != nil ? Color.white : Color.white, saved != nil ? Theme.accent : Color.black.opacity(0.45))
                        .symbolEffect(.bounce, value: saved != nil)
                        .padding(10)
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text(source.title).font(.system(.title3, design: .serif, weight: .semibold)).foregroundStyle(.primary)
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
                LinearGradient(colors: [Theme.accent.opacity(0.22), Theme.accent.opacity(0.08)], startPoint: .topLeading, endPoint: .bottomTrailing)
                if let cover = covers[source.id] {
                    Image(decorative: cover, scale: 1).resizable().scaledToFill().transition(.opacity)
                } else if previews[source.id] == nil, failures[source.id] == nil {
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
        VStack(alignment: .leading, spacing: 12) {
            Text("Importing \(source.title)").font(.headline)
            ImportProgressView(model: progress)
        }
        .padding(20)
        .frame(maxWidth: 360, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20))
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.black.opacity(0.15))
        .transition(.opacity)
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
        Task {
            do {
                let result = try await RecipeImporter.importResult(from: source.url, progress: progress.report)
                reviewing = draft(from: result)
            } catch {
                failures[source.id] = error.localizedDescription
            }
            importing = nil
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
                    Circle()
                        .fill(item == step ? Theme.accent : Color.secondary.opacity(0.3))
                        .frame(width: 8, height: 8)
                }
            }
            .accessibilityHidden(true)
            Button(action: advance) {
                Text(primaryTitle).frame(maxWidth: 400)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
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
        .background(.bar)
    }

    private var primaryTitle: String {
        switch step {
        case .welcome: "Get Started"
        case .share, .add, .tryIt: "Continue"
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

/// A stand-in for Safari's share sheet with Save to Recipes highlighted.
private struct ShareSheetMock: View {
    let cover: CGImage?

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                ZStack {
                    LinearGradient(colors: [Theme.accent.opacity(0.22), Theme.accent.opacity(0.08)], startPoint: .topLeading, endPoint: .bottomTrailing)
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
                appIcon("fork.knife", "Save to Recipes", Theme.accent, highlighted: true)
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
                .foregroundStyle(highlighted ? Theme.accent : .secondary)
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

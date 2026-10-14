import RecipeKit
import SwiftUI

struct OnboardingView: View {
    enum Step: Int, CaseIterable {
        case welcome, add, tryIt, discover
    }

    @EnvironmentObject private var library: RecipeLibrary
    let onFinish: () -> Void

    @State private var step: Step
    @State private var reviewing: ScanDraft?
    @State private var importing: OnboardingSource?
    @State private var failures: [OnboardingSource.ID: String] = [:]
    @StateObject private var progress = ImportProgressModel()

    init(step: Step = .welcome, onFinish: @escaping () -> Void) {
        _step = State(initialValue: step)
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
        .animation(.snappy, value: step)
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

    private var add: some View {
        VStack(spacing: 24) {
            header(symbol: "plus.circle.fill", title: "Add your first recipes",
                   subtitle: "These are real recipes from around the web. Tap one to import it, check it over, then tap the checkmark to save it.")
            VStack(spacing: 12) {
                ForEach(OnboardingSources.all) { source in sourceRow(source) }
            }
        }
    }

    private var tryIt: some View {
        VStack(spacing: 24) {
            header(symbol: "sparkles", title: "Make it yours",
                   subtitle: addedRecipes.first.map { "Try two things on \($0.title). You can undo both from the app any time." }
                       ?? "Try two things on a recipe. You can undo both from the app any time.")
            if let recipe = addedRecipes.first {
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

    private func sourceRow(_ source: OnboardingSource) -> some View {
        let isAdded = savedRecipe(for: source) != nil
        return Button { startImport(source) } label: {
            HStack(spacing: 12) {
                Image(systemName: source.kind == .video ? "play.rectangle.fill" : "globe")
                    .font(.title2)
                    .foregroundStyle(Theme.accent)
                    .frame(width: 56, height: 56)
                    .background(Theme.accent.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 3) {
                    Text(source.title).font(.system(.headline, design: .serif)).foregroundStyle(.primary)
                    Text(source.site).font(.caption.weight(.medium)).foregroundStyle(Theme.accent)
                    if let failure = failures[source.id] {
                        Text(failure).font(.caption).foregroundStyle(.red).lineLimit(2)
                    } else {
                        Text(source.detail).font(.caption).foregroundStyle(.secondary)
                    }
                }
                Spacer(minLength: 8)
                Image(systemName: isAdded ? "checkmark.circle.fill" : "arrow.down.circle")
                    .font(.title2)
                    .foregroundStyle(isAdded ? Theme.accent : Color.secondary)
                    .symbolEffect(.bounce, value: isAdded)
            }
            .multilineTextAlignment(.leading)
            .padding(10)
            .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 16))
            .contentShape(RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
        .allowsHitTesting(!isAdded && importing == nil)
        .accessibilityLabel(isAdded ? "\(source.title), added" : "Import \(source.title) from \(source.site)")
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
        importing = source
        failures[source.id] = nil
        progress.reset()
        Task {
            do {
                let result = try await RecipeImporter.importResult(from: source.url, progress: progress.report)
                reviewing = ScanDraft(
                    recipe: result.recipe, text: result.sourceText, textTitle: result.sourceTitle,
                    notice: result.message, imageData: result.imageData, stepImages: result.stepImageData
                )
            } catch {
                failures[source.id] = error.localizedDescription
            }
            importing = nil
        }
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

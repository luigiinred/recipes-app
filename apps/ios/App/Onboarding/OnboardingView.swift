import RecipeKit
import SwiftUI

struct OnboardingView: View {
    @Environment(\.appAccent) private var accent
    enum Step: Int, CaseIterable {
        case welcome, add, home, tabs, feeds, discover, look, reminders, done
    }

    @EnvironmentObject private var library: RecipeLibrary
    @AppStorage(AppSettings.Key.hiddenTabs) private var hiddenTabsRaw = ""
    #if os(iOS)
    @AppStorage(AppSettings.Key.homeSections) private var homeOrderRaw = ""
    @AppStorage(AppSettings.Key.hiddenHomeSections) private var hiddenHomeRaw = ""
    #endif
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

    /// The steps this device offers, leaving out Feeds once nothing would show them.
    private var steps: [Step] {
        Step.allCases.filter { step in
            switch step {
            #if os(iOS)
            case .feeds:
                !AppSettings.hiddenTabs(hiddenTabsRaw).contains(.feeds)
                    || !HomeSection.hidden(hiddenHomeRaw, order: homeOrderRaw).contains(.feeds)
            #else
            case .home: false
            case .feeds: !AppSettings.hiddenTabs(hiddenTabsRaw).contains(.feeds)
            #endif
            default: true
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()
                Button("Skip", action: onFinish)
                    .buttonStyle(.plain)
                    .appFont(.body, weight: .semibold)
                    .foregroundStyle(Theme.accent)
                    .opacity(step == .done ? 0 : 1)
                    .disabled(step == .done)
                    .accessibilityHint("Finishes setup and opens Home.")
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            ScrollView {
                page
                    .frame(maxWidth: 560)
                    .padding(.horizontal, 24)
                    .padding(.top, 8)
                    .padding(.bottom, 16)
                    .frame(maxWidth: .infinity)
                    .id(step)
                    .transition(.opacity)
            }
            .scrollBounceBehavior(.basedOnSize)
            .scrollDismissesKeyboard(.interactively)
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
        case .add: add
        case .home:
            #if os(iOS)
            OnboardingHomePage()
            #endif
        case .tabs: OnboardingTabsPage()
        case .feeds: OnboardingFeedsPage()
        case .discover: OnboardingDiscoverPage()
        case .look: OnboardingLookPage()
        case .reminders: OnboardingRemindersPage()
        case .done: OnboardingSummaryPage()
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
                Text("Save, organize, and cook the recipes you love. Let's set Recipes up your way.")
                    .appFont(.body).foregroundStyle(.secondary).multilineTextAlignment(.center)
            }
            stage(decorations: [.basil, .garlic, .broccoli]) { MascotCluster(height: 220) }
            VStack(alignment: .leading, spacing: 18) {
                OnboardingFeature(symbol: "square.grid.2x2", title: "Pick what you see", detail: "Choose your Home sections and tabs.")
                OnboardingFeature(symbol: "dot.radiowaves.up.forward", title: "Bring in recipes", detail: "Follow recipe sites, or browse a friend's Mealie server.")
                OnboardingFeature(symbol: "paintpalette", title: "Make it yours", detail: "Pick a look and any reminders you'd like.")
            }
            Text("Tap Skip any time to go straight to Home. All of this can be changed in Settings later.")
                .appFont(.footnote).foregroundStyle(.secondary).multilineTextAlignment(.center)
        }
    }

    private var add: some View {
        VStack(spacing: 24) {
            OnboardingHeader(character: .potato, scene: .bookPages, title: "Add your first recipe",
                             subtitle: "Tap one to import it, check it over, then tap the checkmark to save it.")
            VStack(spacing: 16) {
                ForEach(OnboardingSources.all) { source in sourceCard(source) }
            }
            OnboardingFeature(
                symbol: "square.and.arrow.up", title: "From Safari or YouTube",
                detail: "Tap Share, then Save to Recipes. If it isn't in the row of apps, tap More and turn it on. You can also paste a link from the Recipes toolbar."
            )
        }
    }

    // MARK: Pieces

    /// A soft rounded panel behind the illustration, with a few ingredients sitting around its edges.
    private func stage<Content: View>(decorations: [Produce], @ViewBuilder content: () -> Content) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .fill(LinearGradient(colors: [accent.opacity(0.14), accent.opacity(0.04)], startPoint: .top, endPoint: .bottom))
            GeometryReader { geometry in
                ForEach(Array(decorations.enumerated()), id: \.offset) { index, ingredient in
                    ProduceView(produce: ingredient, height: 36, phase: Double(index) * 0.33)
                        .rotationEffect(.degrees(Double(index) * 37 - 30))
                        .opacity(0.9)
                        .position(
                            x: [geometry.size.width * 0.09, geometry.size.width * 0.91, geometry.size.width * 0.5][index % 3],
                            y: [geometry.size.height * 0.13, geometry.size.height * 0.09, geometry.size.height * 0.07][index % 3]
                        )
                }
            }
            content().padding(.vertical, 24).padding(.horizontal, 12)
        }
        .frame(maxWidth: .infinity)
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
                        .appFont(.title)
                        .symbolRenderingMode(.palette)
                        .foregroundStyle(Color.white, saved != nil ? accent : Color.black.opacity(0.45))
                        .symbolEffect(.bounce, value: saved != nil)
                        .padding(10)
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text(source.title).appFont(.title3, weight: .semibold).foregroundStyle(.primary)
                    Text(source.site).appFont(.caption, weight: .medium).foregroundStyle(Theme.accent)
                    if let failure = failures[source.id] {
                        Text(failure).appFont(.caption).foregroundStyle(.red).lineLimit(2)
                    } else {
                        Text(source.detail).appFont(.subheadline).foregroundStyle(.secondary)
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
                        .appFont(.largeTitle).foregroundStyle(Theme.accent.opacity(0.45))
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

    private var footer: some View {
        VStack(spacing: 12) {
            HStack(spacing: 8) {
                ForEach(steps, id: \.self) { item in
                    Capsule()
                        .fill(item == step ? AnyShapeStyle(Theme.accent) : AnyShapeStyle(Color.secondary.opacity(0.3)))
                        .frame(width: item == step ? 22 : 8, height: 8)
                }
            }
            .accessibilityHidden(true)
            Button(action: advance) { Text(primaryTitle) }
                .buttonStyle(PaperButtonStyle())
                .frame(maxWidth: 400)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity)
        .animation(.snappy, value: step)
    }

    private var primaryTitle: String {
        switch step {
        case .welcome: "Get Started"
        case .done: "Start Cooking"
        default: "Continue"
        }
    }

    private func advance() {
        let steps = steps
        if let index = steps.firstIndex(of: step), index + 1 < steps.count { step = steps[index + 1] } else { onFinish() }
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

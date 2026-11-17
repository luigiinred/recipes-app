import RecipeKit
import SwiftUI

struct OnboardingView: View {
    @Environment(\.appAccent) private var accent
    enum Step: Int, CaseIterable {
        case welcome, add, look
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

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()
                Button("Skip", action: onFinish)
                    .buttonStyle(.plain)
                    .appFont(.body, weight: .semibold)
                    .foregroundStyle(Theme.accent)
                    .opacity(step == .look ? 0 : 1)
                    .disabled(step == .look)
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
        .themedCanvas()
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
        case .add: add
        case .look: OnboardingLookPage()
        }
    }

    // MARK: Pages

    private var welcome: some View {
        VStack(alignment: .leading, spacing: 28) {
            welcomeCards
            OnboardingHeader(title: "Your recipes, all in one place",
                             subtitle: "Free, with no account and no ads. Your recipes are plain files that belong to you.")
            VStack(alignment: .leading, spacing: 20) {
                OnboardingFeature(symbol: "square.and.arrow.down", title: "Save from anywhere",
                                  detail: "Paste a link, share from Safari or YouTube, or scan a cookbook page.")
                OnboardingFeature(symbol: "calendar", title: "Plan your week",
                                  detail: "Drag recipes onto days. Up Next keeps what you want to cook soon.")
                OnboardingFeature(symbol: "checklist", title: "One shopping list",
                                  detail: "Add a recipe's ingredients in a tap, sorted by aisle.")
            }
        }
    }

    /// The sample recipes' photos, fanned out like a stack of cards.
    private var welcomeCards: some View {
        HStack(spacing: -36) {
            ForEach(Array(OnboardingSources.all.prefix(3).enumerated()), id: \.element.id) { index, source in
                Color.clear
                    .aspectRatio(3 / 4, contentMode: .fit)
                    .overlay { sourceImage(source, saved: nil) }
                    .clipShape(RoundedRectangle(cornerRadius: PhotoCard<EmptyView, EmptyView>.cornerRadius, style: .continuous))
                    .shadow(color: .black.opacity(0.18), radius: 12, y: 6)
                    .rotationEffect(.degrees(Double(index - 1) * 7))
                    .offset(y: index == 1 ? -8 : 6)
                    .zIndex(index == 1 ? 1 : 0)
            }
        }
        .frame(maxWidth: 300)
        .frame(maxWidth: .infinity)
        .padding(.top, 20)
        .accessibilityHidden(true)
    }

    private var add: some View {
        VStack(alignment: .leading, spacing: 24) {
            OnboardingHeader(title: "Add your first recipe",
                             subtitle: "Tap one to bring it in, check it over, and save it. Or skip ahead and add your own.")
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                ForEach(OnboardingSources.all) { source in sourceCard(source) }
            }
            OnboardingFeature(
                symbol: "square.and.arrow.up", title: "From Safari or YouTube",
                detail: "Tap Share, then Save to Recipes. If it isn't in the row of apps, tap More and turn it on."
            )
        }
    }

    // MARK: Pieces

    private func sourceCard(_ source: OnboardingSource) -> some View {
        let saved = savedRecipe(for: source)
        return Button { startImport(source) } label: {
            PhotoCard(title: source.title, aspectRatio: 3 / 4) {
                sourceImage(source, saved: saved)
            } detail: {
                if let failure = failures[source.id] {
                    Text(failure).appFont(.caption).foregroundStyle(.red).lineLimit(2)
                } else {
                    Text(source.site).appFont(.caption, weight: .medium).lineLimit(1)
                }
            }
            .overlay(alignment: .topTrailing) {
                Image(systemName: saved != nil ? "checkmark.circle.fill" : "plus.circle.fill")
                    .appFont(.title)
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(Color.white, saved != nil ? accent : Color.black.opacity(0.45))
                    .symbolEffect(.bounce, value: saved != nil)
                    .padding(10)
            }
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
        .themedCanvas()
        .background(.background)
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
                ForEach(Step.allCases, id: \.self) { item in
                    Capsule()
                        .fill(item == step ? AnyShapeStyle(Theme.accent) : AnyShapeStyle(Color.secondary.opacity(0.3)))
                        .frame(width: item == step ? 22 : 8, height: 8)
                }
            }
            .accessibilityHidden(true)
            Button(action: advance) {
                Text(primaryTitle).appFont(.headline).frame(maxWidth: .infinity, minHeight: 34)
            }
            .buttonStyle(.glassProminent)
            .controlSize(.large)
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
        case .add: library.recipes.isEmpty ? "Not Now" : "Continue"
        case .look: "Start Cooking"
        }
    }

    private func advance() {
        if let next = Step(rawValue: step.rawValue + 1) { step = next } else { onFinish() }
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

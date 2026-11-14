import RecipeKit
import SwiftUI

@MainActor
final class ShareModel: ObservableObject {
    enum State { case loading, follow(url: URL, title: String, following: Bool), followed(String), preview, review, saving, saved(Recipe, note: String?), failed(String) }

    struct Source {
        let url: URL
        let title: String
        var following: Bool
    }

    @Published var state = State.loading
    @Published private(set) var host: String?
    /// The blog or channel behind a shared post or video, offered to follow beside the recipe.
    @Published private(set) var source: Source?
    let progress = ImportProgressModel()

    private(set) var result: ImportResult?
    private(set) var recipeLibrary = RecipeLibrary(recipes: [])
    private var library: Library?

    func load(url: URL?) async {
        guard let url else {
            state = .failed("No web page to import.")
            return
        }
        host = url.host?.replacingOccurrences(of: "www.", with: "")
        let library = await Task.detached { RecipeLocation.resolveForApp().library }.value
        self.library = library
        if let feed = await FeedService.followable(url) {
            state = .follow(url: feed.url, title: feed.title, following: await isFollowing(feed.url))
            return
        }
        Task {
            guard let feed = await FeedService.sourceFeed(for: url) else { return }
            source = Source(url: feed.url, title: feed.title, following: await isFollowing(feed.url))
        }
        await importRecipe(from: url)
    }

    private func isFollowing(_ url: URL) async -> Bool {
        guard let library else { return false }
        let feeds = await Task.detached { (try? library.feeds.list()) ?? [] }.value
        return feeds.contains { $0.url == url.absoluteString }
    }

    func followSource() async {
        guard let library, let source, !source.following else { return }
        let feed = Feed(url: source.url.absoluteString, title: source.title)
        if case .success = await Task.detached(operation: { Result { try library.feeds.save(feed) } }).value {
            self.source?.following = true
        }
    }

    func follow(_ url: URL, title: String) async {
        guard let library else { return }
        let feed = Feed(url: url.absoluteString, title: title)
        let outcome = await Task.detached { Result { try library.feeds.save(feed) } }.value
        switch outcome {
        case .success: state = .followed(title)
        case .failure(let error): state = .failed(error.localizedDescription)
        }
    }

    private func importRecipe(from url: URL) async {
        do {
            let result = try await RecipeImporter.importResult(from: url, progress: progress.report)
            guard let library else { return }
            let recipes = await Task.detached { (try? library.recipes.list()) ?? [] }.value
            self.result = result
            recipeLibrary = RecipeLibrary(recipes: recipes)
            if let existing = recipes.first(where: { $0.sourceURL != nil && $0.sourceURL == result.recipe.sourceURL }) {
                state = .saved(existing, note: "It was already in your cookbook.")
            } else {
                state = .preview
            }
        } catch {
            state = .failed(error.localizedDescription)
        }
    }

    /// A complete recipe goes straight in; the app's recipe page offers a cleanup if it needs one.
    private func saveDirectly(_ result: ImportResult) async {
        guard let library else { return }
        state = .saving
        switch await Task.detached(operation: { Result { try library.add(result) } }).value {
        case .success(let saved): state = .saved(saved, note: nil)
        case .failure(let error): state = .failed(error.localizedDescription)
        }
    }

    func saveImported() async {
        if let result { await saveDirectly(result) }
    }

    var notice: String? {
        guard let result, !result.isComplete else { return nil }
        return result.message ?? "No full recipe was found. Check the details below."
    }

    func save(_ recipe: Recipe, image: ImageChange, steps: StepImageChanges) async {
        guard let library else { return }
        state = .saving
        let outcome = await Task.detached {
            Result { () -> Recipe in
                for (id, data) in steps.added { try library.stepImages.save(data, for: id) }
                let saved = try library.recipes.save(recipe)
                switch image {
                case .unchanged: break
                case .set(let data): try library.images.save(data, for: saved.id)
                case .remove: try library.images.delete(for: saved.id)
                }
                for id in steps.removed { try library.stepImages.delete(for: id) }
                return saved
            }
        }.value
        switch outcome {
        case .success(let saved): state = .saved(saved, note: notice)
        case .failure(let error): state = .failed(error.localizedDescription)
        }
    }
}

struct ShareView: View {
    @StateObject private var model = ShareModel()
    let loadURL: () async -> URL?
    let finish: () -> Void
    let cancel: () -> Void
    let openApp: (URL) -> Void

    var body: some View {
        Group {
            switch model.state {
            case .loading:
                ScrollView {
                    ImportLoadingView(title: "Reading recipe…", subtitle: model.host, model: model.progress, cancel: cancel)
                        .frame(maxWidth: .infinity)
                }
                .scrollBounceBehavior(.basedOnSize)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            case .follow(let url, let title, let following):
                VStack(spacing: 14) {
                    StateSymbol(name: "dot.radiowaves.up.forward")
                    Text(following ? "Already following" : "Follow \(title)?").appFont(.title3, weight: .bold).multilineTextAlignment(.center)
                    Text(following ? "\(title) is already in your Feeds." : "Its newest recipes and videos will show up in your Feeds tab.")
                        .appFont(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center)
                    VStack(spacing: 10) {
                        if !following {
                            Button { Task { await model.follow(url, title: title) } } label: { Label("Follow", systemImage: "dot.radiowaves.up.forward") }
                                .buttonStyle(PaperButtonStyle())
                                .keyboardShortcut(.defaultAction)
                        }
                        Button(following ? "Done" : "Cancel", action: following ? finish : cancel)
                            .buttonStyle(PaperButtonStyle(prominent: false))
                    }
                    .frame(maxWidth: 320)
                    .padding(.top, 6)
                }
                .padding(24)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            case .followed(let title):
                VStack(spacing: 14) {
                    StateSymbol(name: "checkmark.circle.fill")
                    Text("Following \(title)").appFont(.title3, weight: .bold).multilineTextAlignment(.center)
                    Text("New posts will show up in your Feeds tab.").appFont(.subheadline).foregroundStyle(.secondary)
                    Button("Done", action: finish)
                        .buttonStyle(PaperButtonStyle())
                        .keyboardShortcut(.defaultAction)
                        .frame(maxWidth: 320)
                        .padding(.top, 6)
                }
                .padding(24)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .sensoryFeedback(.success, trigger: title)
            case .preview:
                if let result = model.result {
                    NavigationStack {
                        RecipePreviewContent(recipe: result.recipe, imageData: result.imageData)
                            .importPreviewChrome(notice: model.notice, isSaving: false, cancel: cancel,
                                                 edit: { model.state = .review }, save: { Task { await model.saveImported() } })
                    }
                    .transition(.opacity)
                }
            case .review:
                if let result = model.result {
                    NavigationStack {
                        RecipeEditorView(
                            recipe: result.recipe, notice: model.notice, initialImage: result.imageData,
                            initialStepImages: result.stepImageData, onCancel: cancel
                        ) { recipe, image, steps in
                            Task { await model.save(recipe, image: image, steps: steps) }
                        }
                    }
                    .environmentObject(model.recipeLibrary)
                    .transition(.opacity)
                }
            case .saving:
                VStack(spacing: 8) {
                    ProgressView().controlSize(.large)
                    Text("Saving…").appFont(.title3, weight: .bold)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            case .saved(let recipe, let note):
                VStack(spacing: 14) {
                    StateSymbol(name: "checkmark.circle.fill")
                    Text("Recipe added!").appFont(.title, weight: .bold)
                    Text("\(recipe.title) has been added to your cookbook.")
                        .appFont(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center)
                    Text(note ?? "It will sync to your other devices through iCloud.")
                        .appFont(.caption).foregroundStyle(note == nil ? Color.secondary : Color.orange).multilineTextAlignment(.center)
                    VStack(spacing: 10) {
                        Button { openApp(RecipeLink.url(for: recipe.id)) } label: { Label("Open in Recipes", systemImage: "arrow.up.forward.app") }
                            .buttonStyle(PaperButtonStyle())
                            .keyboardShortcut(.defaultAction)
                        followSourceButton
                        Button("Done", action: finish)
                            .buttonStyle(PaperButtonStyle(prominent: false))
                    }
                    .frame(maxWidth: 320)
                    .padding(.top, 6)
                }
                .padding(24)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .sensoryFeedback(.success, trigger: recipe.id)
            case .failed(let message):
                VStack(spacing: 12) {
                    StateSymbol(name: "exclamationmark.triangle.fill")
                    Text("Couldn't import that").appFont(.title3, weight: .bold)
                    Text(message).appFont(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center)
                    VStack(spacing: 10) {
                        followSourceButton
                        Button("Done", action: cancel)
                            .buttonStyle(PaperButtonStyle())
                            .keyboardShortcut(.defaultAction)
                    }
                    .frame(maxWidth: 320)
                    .padding(.top, 6)
                }
                .padding(24)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .paperBackground()
        .animation(.snappy, value: model.state.tag)
        .tint(Theme.defaultAccent)
        .task { await model.load(url: await loadURL()) }
    }

    @ViewBuilder
    private var followSourceButton: some View {
        if let source = model.source {
            Button { Task { await model.followSource() } } label: {
                Label(source.following ? "Following \(source.title)" : "Follow \(source.title)",
                      systemImage: source.following ? "checkmark.circle.fill" : "dot.radiowaves.up.forward")
                    .lineLimit(1)
            }
            .buttonStyle(PaperButtonStyle(prominent: false))
            .disabled(source.following)
            .transition(.opacity)
        }
    }
}

extension ShareModel.State {
    var tag: Int {
        switch self {
        case .loading: 0
        case .review: 1
        case .saving: 2
        case .saved: 3
        case .failed: 4
        case .follow: 5
        case .followed: 6
        case .preview: 7
        }
    }
}

import RecipeKit
import SwiftUI

@MainActor
final class ShareModel: ObservableObject {
    enum State { case loading, follow(url: URL, title: String, following: Bool), followed(String), review, saving, saved(Recipe, note: String?), failed(String) }

    @Published var state = State.loading
    @Published private(set) var host: String?
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
        if let feed = await FeedService.followable(url) {
            let library = await Task.detached { RecipeLocation.resolveForApp().library }.value
            let feeds = await Task.detached { (try? library.feeds.list()) ?? [] }.value
            self.library = library
            state = .follow(url: feed.url, title: feed.title, following: feeds.contains { $0.url == feed.url.absoluteString })
            return
        }
        await importRecipe(from: url)
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
            let library = await Task.detached { RecipeLocation.resolveForApp().library }.value
            let recipes = await Task.detached { (try? library.recipes.list()) ?? [] }.value
            self.result = result
            self.library = library
            recipeLibrary = RecipeLibrary(recipes: recipes)
            state = .review
        } catch {
            state = .failed(error.localizedDescription)
        }
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
                    MascotView(character: .tomato, scene: .wave, height: 130)
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
                    MascotCluster(height: 150)
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
                    MascotLoader(height: 150)
                    Text("Saving…").appFont(.title3, weight: .bold)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            case .saved(let recipe, let note):
                VStack(spacing: 14) {
                    MascotCluster(height: 150)
                    Text("Recipe added!").appFont(.title, weight: .bold)
                    Text("\(recipe.title) has been added to your cookbook.")
                        .appFont(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center)
                    Text(note ?? "It will sync to your other devices through iCloud.")
                        .appFont(.caption).foregroundStyle(note == nil ? Color.secondary : Color.orange).multilineTextAlignment(.center)
                    VStack(spacing: 10) {
                        Button { openApp(RecipeLink.url(for: recipe.id)) } label: { Label("Open in Recipes", systemImage: "arrow.up.forward.app") }
                            .buttonStyle(PaperButtonStyle())
                            .keyboardShortcut(.defaultAction)
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
                    MascotView(character: .lemon, scene: .sour, height: 130)
                    Text("Couldn't import that").appFont(.title3, weight: .bold)
                    Text(message).appFont(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center)
                    Button("Done", action: cancel)
                        .buttonStyle(PaperButtonStyle())
                        .keyboardShortcut(.defaultAction)
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
        }
    }
}

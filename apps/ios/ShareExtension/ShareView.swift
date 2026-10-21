import RecipeKit
import SwiftUI

@MainActor
final class ShareModel: ObservableObject {
    enum State { case loading, review, saving, saved(Recipe, note: String?), failed(String) }

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
                    Text("Saving…").font(.system(.title3, weight: .bold))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            case .saved(let recipe, let note):
                VStack(spacing: 14) {
                    MascotCluster(height: 150)
                    Text("Recipe added!").font(.system(.title, weight: .bold))
                    Text("\(recipe.title) has been added to your cookbook.")
                        .font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center)
                    Text(note ?? "It will sync to your other devices through iCloud.")
                        .font(.caption).foregroundStyle(note == nil ? Color.secondary : Color.orange).multilineTextAlignment(.center)
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
                    Text("Couldn't import that").font(.system(.title3, weight: .bold))
                    Text(message).font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center)
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
        }
    }
}

import RecipeKit
import SwiftUI

@MainActor
final class ShareModel: ObservableObject {
    enum State { case loading, review, saving, saved(Recipe, note: String?), failed(String) }

    @Published var state = State.loading
    let progress = ImportProgressModel()

    private(set) var result: ImportResult?
    private(set) var recipeLibrary = RecipeLibrary(recipes: [])
    private var library: Library?

    func load(url: URL?) async {
        guard let url else {
            state = .failed("No web page to import.")
            return
        }
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
                VStack(alignment: .leading, spacing: 12) {
                    Text("Reading recipe…").font(.headline)
                    ImportProgressView(model: model.progress)
                }
                .frame(maxWidth: 320)
                .padding(20)
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
                VStack(spacing: 12) { ProgressView(); Text("Saving…") }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            case .saved(let recipe, let note):
                VStack(spacing: 14) {
                    Image(systemName: "checkmark.circle.fill").font(.system(size: 44)).foregroundStyle(.green)
                        .symbolEffect(.bounce, value: recipe.id)
                    Text("Saved \"\(recipe.title)\"").multilineTextAlignment(.center).font(.headline)
                    Text(note ?? "It will sync to your other devices through iCloud.")
                        .font(.caption).foregroundStyle(note == nil ? Color.secondary : Color.orange).multilineTextAlignment(.center)
                    HStack(spacing: 12) {
                        Button { openApp(RecipeLink.url(for: recipe.id)) } label: { Label("Open in Recipes", systemImage: "arrow.up.forward.app") }
                            .buttonStyle(.borderedProminent)
                            .keyboardShortcut(.defaultAction)
                        Button("Done", action: finish)
                            .buttonStyle(.bordered)
                    }
                }
                .padding(20)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .sensoryFeedback(.success, trigger: recipe.id)
            case .failed(let message):
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle.fill").font(.system(size: 44)).foregroundStyle(.orange)
                    Text(message).multilineTextAlignment(.center)
                    Button("Done", action: cancel).buttonStyle(.borderedProminent).keyboardShortcut(.defaultAction)
                }
                .padding(20)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
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

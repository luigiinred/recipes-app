import Foundation
import RecipeKit

@MainActor
final class RecipeLibrary: ObservableObject {
    @Published private(set) var recipes: [Recipe] = []
    @Published private(set) var isICloud = false
    @Published private(set) var errorMessage: String?

    private var store: RecipeStore?

    var tags: [String] {
        Array(Set(recipes.flatMap(\.tags))).sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
    }

    func run() async {
        let resolved = await Task.detached { RecipeLocation.resolveForApp() }.value
        store = RecipeStore(directory: resolved.directory)
        isICloud = resolved.isICloud
        while !Task.isCancelled {
            await reload()
            try? await Task.sleep(for: .seconds(2))
        }
    }

    func reload() async {
        guard let store else { return }
        let result = await Task.detached { Result { try store.list() } }.value
        switch result {
        case .success(let loaded):
            if loaded != recipes { recipes = loaded }
            errorMessage = nil
        case .failure(let error):
            errorMessage = error.localizedDescription
        }
    }

    func save(_ recipe: Recipe) async {
        guard let store else { return }
        let result = await Task.detached { Result { try store.save(recipe) } }.value
        if case .failure(let error) = result { errorMessage = error.localizedDescription }
        await reload()
    }

    func delete(_ recipe: Recipe) async {
        guard let store else { return }
        let result = await Task.detached { Result { try store.delete(recipe) } }.value
        if case .failure(let error) = result { errorMessage = error.localizedDescription }
        await reload()
    }
}

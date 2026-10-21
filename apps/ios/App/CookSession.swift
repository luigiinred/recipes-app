import Foundation
import RecipeKit

@MainActor
final class CookSession: ObservableObject {
    @Published var current: UUID?
    @Published var isPresented = false
    @Published var stepIndex: [UUID: Int] = [:]

    init(current: UUID? = nil, stepIndex: [UUID: Int] = [:]) {
        self.current = current
        self.stepIndex = stepIndex
    }

    func start(_ recipe: Recipe) {
        current = recipe.id
        isPresented = true
    }
}

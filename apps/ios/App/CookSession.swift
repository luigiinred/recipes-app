import Foundation
import RecipeKit

@MainActor
final class CookSession: ObservableObject {
    @Published var current: UUID?
    @Published var isPresented = false
    @Published var stepIndex: [UUID: Int] = [:]
    /// How many times the written recipe is being made; ingredient amounts follow it.
    @Published var scale = 1.0

    init(current: UUID? = nil, stepIndex: [UUID: Int] = [:]) {
        self.current = current
        self.stepIndex = stepIndex
    }

    func start(_ recipe: Recipe, scale: Double = 1) {
        if current != recipe.id || !isPresented { self.scale = scale }
        current = recipe.id
        isPresented = true
    }
}

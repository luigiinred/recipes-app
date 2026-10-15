import Foundation
import RecipeKit

@MainActor
final class CookSession: ObservableObject {
    @Published var queue: [UUID] = []
    @Published var current: UUID?
    @Published var isPresented = false
    @Published var stepIndex: [UUID: Int] = [:]

    init(queue: [UUID] = [], current: UUID? = nil, stepIndex: [UUID: Int] = [:]) {
        self.queue = queue
        self.current = current ?? queue.first
        self.stepIndex = stepIndex
    }

    func start(_ recipe: Recipe) {
        if !queue.contains(recipe.id) { queue.append(recipe.id) }
        current = recipe.id
        isPresented = true
    }

    func remove(_ id: UUID) {
        queue.removeAll { $0 == id }
        stepIndex[id] = nil
        if current == id { current = queue.first }
        if queue.isEmpty { isPresented = false }
    }
}

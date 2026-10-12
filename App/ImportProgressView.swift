import RecipeKit
import SwiftUI

@MainActor
final class ImportProgressModel: ObservableObject {
    enum State { case waiting, running, done, skipped }

    struct Step: Identifiable {
        let id: Int
        let title: String
        var state = State.waiting
    }

    @Published private(set) var steps: [Step] = []

    var fraction: Double {
        guard !steps.isEmpty else { return 0 }
        let finished = steps.filter { $0.state == .done || $0.state == .skipped }.count
        let running = steps.filter { $0.state == .running }.count
        return (Double(finished) + Double(running) * 0.5) / Double(steps.count)
    }

    func reset() {
        steps = []
    }

    /// Safe to call from any thread; events apply in order on the main actor.
    nonisolated var report: ImportProgress {
        { [weak self] event in
            DispatchQueue.main.async { MainActor.assumeIsolated { self?.apply(event) } }
        }
    }

    func apply(_ event: ImportEvent) {
        withAnimation(.snappy) {
            switch event {
            case .plan(let titles): steps = titles.enumerated().map { Step(id: $0.offset, title: $0.element) }
            case .began(let index): set(index, .running)
            case .finished(let index): set(index, .done)
            case .skipped(let index): set(index, .skipped)
            }
        }
    }

    private func set(_ index: Int, _ state: State) {
        guard steps.indices.contains(index) else { return }
        steps[index].state = state
    }
}

struct ImportProgressView: View {
    @ObservedObject var model: ImportProgressModel

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            ProgressView(value: model.fraction)
                .animation(.smooth, value: model.fraction)
            ForEach(model.steps) { step in
                HStack(spacing: 10) {
                    icon(for: step.state)
                        .frame(width: 22, height: 22)
                    Text(step.title)
                        .foregroundStyle(step.state == .waiting || step.state == .skipped ? Color.secondary : Color.primary)
                    Spacer(minLength: 0)
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .sensoryFeedback(.success, trigger: model.fraction >= 1)
        .accessibilityElement(children: .combine)
        .accessibilityValue("\(Int(model.fraction * 100)) percent")
    }

    @ViewBuilder
    private func icon(for state: ImportProgressModel.State) -> some View {
        switch state {
        case .waiting: Image(systemName: "circle").foregroundStyle(.tertiary)
        case .running: ProgressView().controlSize(.small)
        case .done: Image(systemName: "checkmark.circle.fill").foregroundStyle(Color.accentColor).symbolEffect(.bounce, value: state)
        case .skipped: Image(systemName: "minus.circle").foregroundStyle(.tertiary)
        }
    }
}

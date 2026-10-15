import RecipeKit
import SwiftUI

/// Lays views out in rows, wrapping to a new row when one fills up.
struct FlowLayout: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = layout(width: proposal.width ?? .infinity, subviews: subviews)
        return CGSize(width: rows.map(\.width).max() ?? 0, height: rows.last.map { $0.y + $0.height } ?? 0)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        for row in layout(width: bounds.width, subviews: subviews) {
            var x = bounds.minX
            for index in row.indices {
                let size = subviews[index].sizeThatFits(.unspecified)
                subviews[index].place(at: CGPoint(x: x, y: bounds.minY + row.y), proposal: ProposedViewSize(size))
                x += size.width + spacing
            }
        }
    }

    private struct Row {
        var indices: [Int] = []
        var width: CGFloat = 0
        var height: CGFloat = 0
        var y: CGFloat = 0
    }

    private func layout(width: CGFloat, subviews: Subviews) -> [Row] {
        var rows: [Row] = []
        var current = Row()
        var y: CGFloat = 0
        for index in subviews.indices {
            let size = subviews[index].sizeThatFits(.unspecified)
            let needed = current.indices.isEmpty ? size.width : current.width + spacing + size.width
            if needed > width, !current.indices.isEmpty {
                current.y = y
                rows.append(current)
                y += current.height + spacing
                current = Row()
            }
            current.width = current.indices.isEmpty ? size.width : current.width + spacing + size.width
            current.height = max(current.height, size.height)
            current.indices.append(index)
        }
        if !current.indices.isEmpty {
            current.y = y
            rows.append(current)
        }
        return rows
    }
}

/// A section with a heading only when there is one.
struct TitledSection<Content: View>: View {
    let title: String?
    @ViewBuilder let content: () -> Content

    var body: some View {
        if let title {
            Section(title) { content() }
        } else {
            Section { content() }
        }
    }
}

/// The ingredients a step uses, as small chips.
struct StepIngredientChips: View {
    let recipe: Recipe
    let step: Int

    var body: some View {
        let used = IngredientMatcher.indices(in: recipe.steps[step], ingredients: recipe.ingredients)
        if !used.isEmpty {
            FlowLayout(spacing: 6) {
                ForEach(used, id: \.self) { index in
                    Text(IngredientLine.chipText(recipe.ingredients[index]))
                        .font(.caption.weight(.medium))
                        .lineLimit(1)
                        .padding(.horizontal, 9).padding(.vertical, 4)
                        .background(Theme.accent.opacity(0.12), in: Capsule())
                        .foregroundStyle(Theme.accent)
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Uses " + used.map { IngredientLine.chipText(recipe.ingredients[$0]) }.joined(separator: ", "))
        }
    }
}

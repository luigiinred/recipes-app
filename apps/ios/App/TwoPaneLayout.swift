import SwiftUI

/// Puts two views side by side when there is room for both, and stacks them otherwise.
struct TwoPaneLayout: Layout {
    var threshold: CGFloat = 640
    var spacing: CGFloat = 40
    var stackedSpacing: CGFloat = 28
    var leadingFraction: CGFloat = 0.38
    var leadingMax: CGFloat = 340

    private func isSideBySide(_ width: CGFloat) -> Bool { width >= threshold }

    private func widths(_ total: CGFloat) -> (CGFloat, CGFloat) {
        let leading = min(leadingMax, total * leadingFraction)
        return (leading, total - leading - spacing)
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? threshold
        guard subviews.count == 2 else { return CGSize(width: width, height: 0) }
        if isSideBySide(width) {
            let (leading, trailing) = widths(width)
            let first = subviews[0].sizeThatFits(ProposedViewSize(width: leading, height: nil))
            let second = subviews[1].sizeThatFits(ProposedViewSize(width: trailing, height: nil))
            return CGSize(width: width, height: max(first.height, second.height))
        }
        let first = subviews[0].sizeThatFits(ProposedViewSize(width: width, height: nil))
        let second = subviews[1].sizeThatFits(ProposedViewSize(width: width, height: nil))
        return CGSize(width: width, height: first.height + stackedSpacing + second.height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        guard subviews.count == 2 else { return }
        if isSideBySide(bounds.width) {
            let (leading, trailing) = widths(bounds.width)
            subviews[0].place(at: bounds.origin, anchor: .topLeading, proposal: ProposedViewSize(width: leading, height: nil))
            subviews[1].place(
                at: CGPoint(x: bounds.minX + leading + spacing, y: bounds.minY), anchor: .topLeading,
                proposal: ProposedViewSize(width: trailing, height: nil)
            )
        } else {
            let first = subviews[0].sizeThatFits(ProposedViewSize(width: bounds.width, height: nil))
            subviews[0].place(at: bounds.origin, anchor: .topLeading, proposal: ProposedViewSize(width: bounds.width, height: nil))
            subviews[1].place(
                at: CGPoint(x: bounds.minX, y: bounds.minY + first.height + stackedSpacing), anchor: .topLeading,
                proposal: ProposedViewSize(width: bounds.width, height: nil)
            )
        }
    }
}

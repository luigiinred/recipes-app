import RecipeKit
import SwiftUI

extension View {
    /// Mark as Viewed or New, save the recipe, and open or share the post: from a long press, and on iPhone and iPad from a sideways swipe.
    func feedPostActions(_ entry: FeedEntry, swipes: Bool = true) -> some View {
        modifier(FeedPostActions(entry: entry, swipes: swipes))
    }
}

private struct FeedPostActions: ViewModifier {
    @EnvironmentObject private var library: RecipeLibrary
    @EnvironmentObject private var loader: FeedLoader
    @Environment(\.appAccent) private var accent
    let entry: FeedEntry
    let swipes: Bool

    #if os(iOS)
    @State private var offset: CGFloat = 0
    private let threshold: CGFloat = 90
    #endif

    func body(content: Content) -> some View {
        let viewed = loader.isViewed(entry)
        content
            #if os(iOS)
            .offset(x: offset)
            .background { if swipes, offset != 0 { swipeBackground(viewed: viewed) } }
            .gesture(HorizontalPan(isEnabled: swipes) { offset = $0 } ended: { ended($0) })
            .sensoryFeedback(.impact(weight: .light), trigger: abs(offset) > threshold)
            #endif
            .contextMenu {
                Button { toggleViewed() } label: {
                    if viewed { Label("Mark as New", systemImage: "circle") } else { Label("Mark as Viewed", systemImage: "checkmark.circle") }
                }
                Button { save() } label: { Label("Add to My Recipes", systemImage: "plus") }
                Link(destination: entry.link) { Label("Open in Browser", systemImage: "safari") }
                ShareLink(item: entry.link) { Label("Share", systemImage: "square.and.arrow.up") }
            }
    }

    private func toggleViewed() {
        if loader.isViewed(entry) {
            loader.markNew([entry.id])
        } else {
            loader.markViewed([entry.id])
            ToastCenter.shared.show("Marked as viewed") { loader.markNew([entry.id]) }
        }
    }

    private func save() {
        Task {
            do {
                try await loader.loadRecipe(for: entry)
                guard let result = loader.results[entry.id], let saved = await library.add(result) else { return }
                ToastCenter.shared.show("Added \(saved.title) to My Recipes") { await library.delete(saved) }
            } catch {
                ToastCenter.shared.show("No recipe found in this post", symbol: "exclamationmark.circle.fill")
            }
        }
    }

    #if os(iOS)
    private func ended(_ translation: CGFloat) {
        if translation < -threshold { toggleViewed() } else if translation > threshold { save() }
        withAnimation(.snappy) { offset = 0 }
    }

    private func swipeBackground(viewed: Bool) -> some View {
        HStack {
            if offset > 0 {
                Label("Save", systemImage: "plus").padding(.leading, 24)
                Spacer()
            } else {
                Spacer()
                Label(viewed ? "New" : "Viewed", systemImage: viewed ? "circle" : "checkmark").padding(.trailing, 24)
            }
        }
        .labelStyle(.iconOnly)
        .appFont(.title2, weight: .semibold)
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(offset > 0 ? AnyShapeStyle(accent) : AnyShapeStyle(.green), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .opacity(min(1, abs(offset) / threshold))
    }
    #endif
}

#if os(iOS)
/// A pan that only starts when the finger moves sideways, so vertical scrolling stays with the scroll view.
private struct HorizontalPan: UIGestureRecognizerRepresentable {
    let isEnabled: Bool
    let changed: (CGFloat) -> Void
    let ended: (CGFloat) -> Void

    init(isEnabled: Bool, changed: @escaping (CGFloat) -> Void, ended: @escaping (CGFloat) -> Void) {
        self.isEnabled = isEnabled
        self.changed = changed
        self.ended = ended
    }

    func makeUIGestureRecognizer(context: Context) -> UIPanGestureRecognizer {
        let pan = UIPanGestureRecognizer()
        pan.isEnabled = isEnabled
        pan.delegate = context.coordinator
        return pan
    }

    func makeCoordinator(converter: CoordinateSpaceConverter) -> Coordinator { Coordinator() }

    func handleUIGestureRecognizerAction(_ recognizer: UIPanGestureRecognizer, context: Context) {
        let x = recognizer.translation(in: recognizer.view).x
        switch recognizer.state {
        case .changed: changed(x)
        case .ended, .cancelled, .failed: ended(x)
        default: break
        }
    }

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        func gestureRecognizerShouldBegin(_ recognizer: UIGestureRecognizer) -> Bool {
            guard let pan = recognizer as? UIPanGestureRecognizer else { return false }
            let velocity = pan.velocity(in: pan.view)
            return abs(velocity.x) > abs(velocity.y) * 1.5
        }
    }
}
#endif

import CryptoKit
import RecipeKit
import SwiftUI

extension FeedEntry {
    /// A post's place in the zoom registry, the same for every card that links to its page.
    static func zoomID(for link: URL) -> UUID {
        let bytes = Array(Insecure.MD5.hash(data: Data(link.absoluteString.utf8)))
        return UUID(uuid: (bytes[0], bytes[1], bytes[2], bytes[3], bytes[4], bytes[5], bytes[6], bytes[7],
                           bytes[8], bytes[9], bytes[10], bytes[11], bytes[12], bytes[13], bytes[14], bytes[15]))
    }

    var zoomID: UUID { Self.zoomID(for: link) }
}

/// A navigation stack's zoom space. Each card reports where it sits, so a recipe's page zooms out of the copy showing on screen.
struct RecipeZoom {
    let namespace: Namespace.ID
    let cards: RecipeZoomCards

    /// The on-screen card for the recipe with the most of it showing; none means an ordinary push.
    @MainActor
    func source(for recipe: UUID) -> String? {
        cards.mostVisible(of: recipe)
    }
}

/// Where each card is, kept outside SwiftUI's observation so scrolling never redraws anything.
@MainActor
final class RecipeZoomCards {
    private var frames: [UUID: [String: CGRect]] = [:]
    var screen: CGRect = .zero

    func place(_ recipe: UUID, key: String, at frame: CGRect?) {
        frames[recipe, default: [:]][key] = frame
    }

    func mostVisible(of recipe: UUID) -> String? {
        let shown = (frames[recipe] ?? [:]).compactMap { key, frame -> (String, CGFloat)? in
            let visible = frame.intersection(screen)
            return visible.isNull || visible.isEmpty ? nil : (key, visible.width * visible.height)
        }
        return shown.max { $0.1 < $1.1 }?.0
    }
}

extension EnvironmentValues {
    @Entry var recipeZoom: RecipeZoom?
    /// True while a Mac window's search lists results in a column at its trailing edge.
    @Entry var windowSearchIsShowing = false
}

extension View {
    /// Gives this navigation stack its own zoom space, so a recipe shown in two tabs zooms from the one in view.
    func recipeZoomScope() -> some View { modifier(RecipeZoomScope()) }

    /// The photo a recipe's page zooms out of, and back into when it closes. `place` tells apart copies of one recipe on a screen.
    func recipeZoomSource(_ id: UUID, in place: String, cornerRadius: CGFloat) -> some View {
        modifier(RecipeZoomSource(id: id, key: "\(place)/\(id)", cornerRadius: cornerRadius))
    }

    func recipeZoomDestination(_ id: UUID) -> some View { modifier(RecipeZoomDestination(id: id)) }
}

private struct RecipeZoomScope: ViewModifier {
    @Namespace private var namespace
    @State private var cards = RecipeZoomCards()

    func body(content: Content) -> some View {
        content
            .environment(\.recipeZoom, RecipeZoom(namespace: namespace, cards: cards))
            .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { cards.screen = $0 }
    }
}

private struct RecipeZoomSource: ViewModifier {
    @Environment(\.recipeZoom) private var zoom
    let id: UUID
    let key: String
    let cornerRadius: CGFloat
    /// Kept so a card coming back into view, after its page closes, says where it is again without having moved.
    @State private var frame: CGRect?

    func body(content: Content) -> some View {
        #if os(iOS)
        if let zoom {
            content
                .matchedTransitionSource(id: key, in: zoom.namespace) { source in
                    source.clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                }
                .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: {
                    frame = $0
                    zoom.cards.place(id, key: key, at: $0)
                }
                .onAppear { if let frame { zoom.cards.place(id, key: key, at: frame) } }
                .onDisappear { zoom.cards.place(id, key: key, at: nil) }
        } else {
            content
        }
        #else
        content
        #endif
    }
}

/// Zooms only when a card for the recipe is on screen; from a link or a menu it's an ordinary push.
private struct RecipeZoomDestination: ViewModifier {
    @Environment(\.recipeZoom) private var zoom
    let id: UUID
    @State private var source: String?
    @State private var looked = false

    func body(content: Content) -> some View {
        #if os(iOS)
        if let zoom, let key = looked ? source : zoom.source(for: id) {
            content
                .navigationTransition(.zoom(sourceID: key, in: zoom.namespace))
                .onAppear { if !looked { source = key; looked = true } }
        } else {
            content
        }
        #else
        content
        #endif
    }
}

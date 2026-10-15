import SwiftUI

/// A photo header that shrinks as the page scrolls and settles into a slim bar with a small thumbnail, the title and quick actions.
struct CollapsingRecipeHeader<Artwork: View, Actions: View>: View {
    let title: String
    let topInset: CGFloat
    /// How far the page has scrolled past its resting position; negative while pulling down.
    let offset: CGFloat
    @ViewBuilder let artwork: () -> Artwork
    @ViewBuilder let actions: () -> Actions

    static var photoHeight: CGFloat { 320 }
    static var barHeight: CGFloat { 56 }

    private var expandedHeight: CGFloat { Self.photoHeight + topInset }
    private var collapsedHeight: CGFloat { Self.barHeight + topInset }
    private var height: CGFloat { max(collapsedHeight, expandedHeight - offset) }
    private var progress: Double { min(1, max(0, Double(offset / (expandedHeight - collapsedHeight)))) }
    private var parallax: CGFloat { -0.3 * min(max(offset, 0), expandedHeight - collapsedHeight) }

    var body: some View {
        Color.clear
            .frame(height: height)
            .frame(maxWidth: .infinity)
            .overlay(alignment: .top) {
                artwork()
                    .frame(maxWidth: .infinity)
                    .frame(height: max(height, expandedHeight), alignment: .top)
                    .clipped()
                    .offset(y: parallax)
                    .allowsHitTesting(false)
            }
            .overlay {
                LinearGradient(colors: [.clear, .black.opacity(0.6)], startPoint: .center, endPoint: .bottom)
                    .opacity(1 - progress)
                    .allowsHitTesting(false)
            }
            .overlay { Rectangle().fill(.regularMaterial).opacity(progress).allowsHitTesting(false) }
            .overlay(alignment: .bottomLeading) {
                Text(title)
                    .font(.system(.largeTitle, design: .serif, weight: .bold))
                    .foregroundStyle(.white)
                    .lineLimit(3)
                    .padding(20)
                    .opacity(max(0, 1 - progress * 2.4))
                    .allowsHitTesting(false)
            }
            .overlay(alignment: .bottom) { bar }
            .overlay(alignment: .bottom) { Divider().opacity(progress).allowsHitTesting(false) }
            .clipped()
            .ignoresSafeArea(edges: .top)
    }

    private var bar: some View {
        HStack(spacing: 10) {
            artwork()
                .frame(width: 34, height: 34)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            Text(title)
                .font(.system(.headline, design: .serif))
                .lineLimit(1)
            Spacer(minLength: 4)
            HStack(spacing: 8) { actions() }
        }
        .padding(.horizontal, 16)
        .frame(height: Self.barHeight)
        .opacity(min(1, max(0, (progress - 0.65) / 0.3)))
        .allowsHitTesting(progress > 0.85)
    }
}

/// A small round glass button for the collapsed header.
struct HeaderActionButton: View {
    let title: String
    let systemImage: String
    var prominent = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.subheadline.weight(.semibold))
                .frame(width: 34, height: 34)
                .foregroundStyle(prominent ? Color.white : Theme.accent)
                .glassEffect(prominent ? .regular.tint(Theme.accent).interactive() : .regular.interactive(), in: Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
    }
}

import SwiftUI

extension View {
    /// Redacts the content to its shape and sweeps a highlight across it while it loads.
    func loadingPlaceholder() -> some View {
        redacted(reason: .placeholder).modifier(Shimmer()).accessibilityLabel("Loading")
    }
}

private struct Shimmer: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var sweeping = false

    func body(content: Content) -> some View {
        content
            .overlay {
                GeometryReader { geometry in
                    LinearGradient(colors: [.clear, .white.opacity(0.5), .clear], startPoint: .leading, endPoint: .trailing)
                        .frame(width: geometry.size.width * 0.5)
                        .offset(x: sweeping ? geometry.size.width * 1.25 : -geometry.size.width * 0.75)
                }
                .mask(content)
                .allowsHitTesting(false)
            }
            .onAppear {
                guard !reduceMotion else { return }
                withAnimation(.linear(duration: 1.2).repeatForever(autoreverses: false)) { sweeping = true }
            }
    }
}

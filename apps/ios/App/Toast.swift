import SwiftUI

/// A short message at the bottom of the window, with an optional Undo, that clears itself after a few seconds.
@MainActor
@Observable
final class ToastCenter {
    static let shared = ToastCenter()
    static let duration: Duration = .seconds(3)

    struct Toast: Identifiable {
        let id = UUID()
        let message: String
        let symbol: String
        let undo: (() async -> Void)?
    }

    private(set) var current: Toast?
    private var dismissal: Task<Void, Never>?

    func show(_ message: String, symbol: String = "checkmark.circle.fill", undo: (() async -> Void)? = nil) {
        let toast = Toast(message: message, symbol: symbol, undo: undo)
        withAnimation(.snappy) { current = toast }
        dismissal?.cancel()
        dismissal = Task {
            try? await Task.sleep(for: Self.duration)
            guard !Task.isCancelled else { return }
            dismiss(toast.id)
        }
    }

    func dismiss(_ id: UUID? = nil) {
        guard id == nil || current?.id == id else { return }
        withAnimation(.snappy) { current = nil }
    }

    func undo() {
        guard let undo = current?.undo else { return }
        dismiss()
        Task { await undo() }
    }
}

extension View {
    func toastHost() -> some View { modifier(ToastHost()) }
}

private struct ToastHost: ViewModifier {
    @Environment(\.appAccent) private var accent
    private let center = ToastCenter.shared

    func body(content: Content) -> some View {
        content.overlay(alignment: .bottom) {
            if let toast = center.current {
                HStack(spacing: 12) {
                    Image(systemName: toast.symbol).foregroundStyle(accent)
                    Text(toast.message).appFont(.subheadline, weight: .medium).lineLimit(2)
                    Spacer(minLength: 8)
                    if toast.undo != nil {
                        Button("Undo") { center.undo() }
                            .appFont(.subheadline, weight: .semibold)
                            .foregroundStyle(accent)
                            .buttonStyle(.borderless)
                    }
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 14)
                .glassEffect(.regular, in: Capsule())
                .padding(.horizontal, 20)
                #if os(iOS)
                .padding(.bottom, 64)
                #else
                .padding(.bottom, 20)
                #endif
                .frame(maxWidth: 520)
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .id(toast.id)
                .accessibilityElement(children: .combine)
                .accessibilityAction(named: "Undo") { center.undo() }
                .onTapGesture { center.dismiss() }
            }
        }
    }
}

import SwiftUI

/// A tinted note in the page: an icon, a heading, a line of text, an optional link, and an × that folds it away.
/// Without a link title, a tap anywhere on it runs the action.
struct InlineAlert: View {
    @Environment(\.appAccent) private var accent
    let symbol: String
    let title: String
    let message: String
    var linkTitle: String?
    var action: (() -> Void)?
    let onDismiss: () -> Void
    @State private var dismissing = false

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            if let action, linkTitle == nil {
                Button(action: action) { content }.buttonStyle(.plain)
            } else {
                content
            }
            Button(action: dismiss) {
                Image(systemName: "xmark")
                    .appFont(.body, weight: .semibold)
                    .foregroundStyle(.secondary)
                    .frame(width: 32, height: 32)
                    .contentShape(Circle())
            }
            .buttonStyle(.borderless)
            .accessibilityLabel("Dismiss")
        }
        .padding(.vertical, 14)
        .padding(.leading, 16)
        .padding(.trailing, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(accent.opacity(0.1), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .scaleEffect(dismissing ? 0.94 : 1, anchor: .top)
        .opacity(dismissing ? 0 : 1)
        .blur(radius: dismissing ? 3 : 0)
        .transition(.asymmetric(insertion: .opacity.combined(with: .scale(scale: 0.96, anchor: .top)), removal: .opacity))
    }

    private var content: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: symbol).appFont(.title3).foregroundStyle(accent).frame(width: 28)
            VStack(alignment: .leading, spacing: 4) {
                Text(title).appFont(.headline)
                Text(message).appFont(.subheadline).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                if let linkTitle, let action {
                    Button(action: action) {
                        HStack(spacing: 4) {
                            Text(linkTitle)
                            Image(systemName: "chevron.right").appFont(.caption, weight: .semibold)
                        }
                        .appFont(.subheadline, weight: .medium)
                        .foregroundStyle(accent)
                    }
                    .buttonStyle(.borderless)
                    .padding(.top, 2)
                }
            }
            Spacer(minLength: 0)
        }
        .contentShape(Rectangle())
    }

    /// Fades and shrinks first, then folds away, so what's below slides up rather than jumping.
    private func dismiss() {
        withAnimation(.snappy(duration: 0.22)) { dismissing = true }
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(180))
            withAnimation(.snappy) { onDismiss() }
        }
    }
}

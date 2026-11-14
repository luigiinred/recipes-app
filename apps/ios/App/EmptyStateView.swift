import SwiftUI

/// A screen with nothing on it yet: an accent symbol, a title, a line of help and optional buttons.
struct EmptyStateView<Actions: View>: View {
    let symbol: String
    let title: String
    var message: String?
    @ViewBuilder var actions: Actions

    init(symbol: String, title: String, message: String? = nil, @ViewBuilder actions: () -> Actions) {
        self.symbol = symbol
        self.title = title
        self.message = message
        self.actions = actions()
    }

    var body: some View {
        VStack(spacing: 12) {
            StateSymbol(name: symbol)
            Text(title).appFont(.title3, weight: .bold).multilineTextAlignment(.center)
            if let message {
                Text(message).appFont(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center)
            }
            actions.padding(.top, 6)
        }
        .padding(28)
        .frame(maxWidth: 360)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .contain)
    }
}

extension EmptyStateView where Actions == EmptyView {
    init(symbol: String, title: String, message: String? = nil) {
        self.init(symbol: symbol, title: title, message: message) { EmptyView() }
    }
}

/// The symbol at the top of an empty or status screen, in the accent on a soft accent circle.
struct StateSymbol: View {
    @Environment(\.appAccent) private var accent
    let name: String

    var body: some View {
        Image(systemName: name)
            .font(.system(size: 30, weight: .semibold))
            .foregroundStyle(accent)
            .frame(width: 72, height: 72)
            .background(accent.opacity(0.12), in: Circle())
            .accessibilityHidden(true)
    }
}

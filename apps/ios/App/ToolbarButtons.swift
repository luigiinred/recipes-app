import SwiftUI

struct CancelButton: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Button { dismiss() } label: { Label("Cancel", systemImage: "xmark") }
            .labelStyle(.iconOnly)
    }
}

struct ConfirmButton: View {
    var title = "Done"
    var isDisabled = false
    let action: () -> Void

    var body: some View {
        #if os(iOS)
        Button(action: action) { Image(systemName: "checkmark").fontWeight(.semibold).foregroundStyle(.white) }
            .buttonStyle(.glassProminent)
            .accessibilityLabel(title)
            .disabled(isDisabled)
        #else
        Button(action: action) { Label(title, systemImage: "checkmark") }
            .labelStyle(.iconOnly)
            .disabled(isDisabled)
        #endif
    }
}

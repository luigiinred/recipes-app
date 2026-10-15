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
        Button(action: action) { Label(title, systemImage: "checkmark") }
            .labelStyle(.iconOnly)
            .disabled(isDisabled)
    }
}

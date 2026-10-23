import RecipeKit
import SwiftUI

private struct MealiePairingPrompt: ViewModifier {
    @EnvironmentObject private var router: AppRouter
    @EnvironmentObject private var mealie: MealieSyncController
    @State private var failure: String?

    func body(content: Content) -> some View {
        content
            .confirmationDialog(title, isPresented: isAsking, titleVisibility: .visible, presenting: router.mealieLink) { link in
                Button("Connect") { Task { await connect(link) } }
                Button("Cancel", role: .cancel) {}
            } message: { link in
                Text(message(for: link))
            }
            .alert("Couldn't Connect to Mealie", isPresented: isFailed) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(failure ?? "")
            }
    }

    private var title: String { mealie.isConnected ? "Switch Mealie Server?" : "Connect to Mealie?" }

    private var isAsking: Binding<Bool> {
        Binding { router.mealieLink != nil } set: { if !$0 { router.mealieLink = nil } }
    }

    private var isFailed: Binding<Bool> {
        Binding { failure != nil } set: { if !$0 { failure = nil } }
    }

    private func message(for link: MealieLink) -> String {
        let host = link.server.host() ?? link.server.absoluteString
        let replaced = mealie.isConnected ? " This replaces your current connection on every device signed in to your iCloud account." : ""
        return "A link wants to sync your recipes, planned meals and groceries with \(host). Only continue if you trust whoever sent it.\(replaced)"
    }

    private func connect(_ link: MealieLink) async {
        do {
            try await mealie.connect(address: link.server.absoluteString, token: link.token)
        } catch {
            failure = error.localizedDescription
        }
    }
}

extension View {
    /// Asks before pairing with the server a `recipes://mealie` link points to.
    func mealiePairingPrompt() -> some View { modifier(MealiePairingPrompt()) }
}

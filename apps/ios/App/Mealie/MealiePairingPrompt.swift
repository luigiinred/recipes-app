import RecipeKit
import SwiftUI

private struct MealiePairingPrompt: ViewModifier {
    @EnvironmentObject private var router: AppRouter
    @EnvironmentObject private var mealie: MealieSyncController
    @EnvironmentObject private var discover: DiscoverController
    @State private var failure: String?

    func body(content: Content) -> some View {
        content
            .confirmationDialog(title(for: router.mealieLink), isPresented: isAsking, titleVisibility: .visible, presenting: router.mealieLink) { link in
                Button(link.kind == .discover ? "Add to Discover" : "Connect") { Task { await connect(link) } }
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

    private func title(for link: MealieLink?) -> String {
        if link?.kind == .discover { return "Add to Discover?" }
        return mealie.isConnected ? "Switch Mealie Server?" : "Connect to Mealie?"
    }

    private var isAsking: Binding<Bool> {
        Binding { router.mealieLink != nil } set: { if !$0 { router.mealieLink = nil } }
    }

    private var isFailed: Binding<Bool> {
        Binding { failure != nil } set: { if !$0 { failure = nil } }
    }

    private func message(for link: MealieLink) -> String {
        let host = link.server.host() ?? link.server.absoluteString
        if link.kind == .discover {
            return "A link shares the recipes on \(host) with you. You can browse them under Discover on the Recipes tab and add the ones you like to your own recipes."
        }
        let replaced = mealie.isConnected ? " This replaces your current connection on every device signed in to your iCloud account." : ""
        return "A link wants to sync your recipes, planned meals and groceries with \(host). Only continue if you trust whoever sent it.\(replaced)"
    }

    private func connect(_ link: MealieLink) async {
        do {
            switch link.kind {
            case .sync: try await mealie.connect(address: link.server.absoluteString, token: link.token)
            case .discover: try await discover.add(address: link.server.absoluteString, token: link.token)
            }
        } catch {
            failure = error.localizedDescription
        }
    }
}

extension View {
    /// Asks before pairing with the server a `recipes://mealie` link points to, or adding a `recipes://discover` one to Discover.
    func mealiePairingPrompt() -> some View { modifier(MealiePairingPrompt()) }
}

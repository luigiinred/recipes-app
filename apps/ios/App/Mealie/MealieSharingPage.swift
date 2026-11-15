import RecipeKit
import SwiftUI

/// Shares your Mealie server three ways, and lists the servers you browse in Discover.
struct MealieSharingPage: View {
    @EnvironmentObject private var mealie: MealieSyncController
    @EnvironmentObject private var discover: DiscoverController
    @State private var making: MealieLink.Kind?
    @State private var failure: String?
    @State private var shareLink: MealieLink?
    @State private var addingServer = false
    @State private var renaming: DiscoverSource?
    @State private var newName = ""

    var body: some View {
        Form {
            shareSection
            serversSection
        }
        .formStyle(.grouped)
        .settingsSpacing()
        .themedCanvas()
        .navigationTitle("Mealie Sharing")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .sheet(item: $shareLink) { MealieShareLinkSheet(link: $0) }
        .sheet(isPresented: $addingServer) { AddDiscoverSheet() }
        .alert("Rename Server", isPresented: Binding(get: { renaming != nil }, set: { if !$0 { renaming = nil } })) {
            TextField("Name", text: $newName)
            Button("Save") { if let renaming { discover.rename(renaming, to: newName) } }
            Button("Cancel", role: .cancel) {}
        }
    }

    // MARK: - Share

    @ViewBuilder
    private var shareSection: some View {
        Section {
            if mealie.canShareAccess {
                ForEach(MealieLink.Kind.shareable, id: \.self) { kind in
                    Button { Task { await make(kind) } } label: {
                        HStack {
                            Label {
                                Text(kind.shareTitle)
                                Text(kind.shareDetail)
                            } icon: {
                                Image(systemName: kind.symbol)
                            }
                            Spacer()
                            if making == kind { ProgressView() }
                        }
                    }
                    .foregroundStyle(.primary)
                }
            } else {
                NavigationLink { MealieSettingsPage() } label: { Label("Connect to Mealie First", image: "MealieLogo") }
            }
        } header: {
            Text("Share Your Server")
        } footer: {
            if let failure {
                Text(failure).foregroundStyle(.red)
            } else {
                Text("Each makes a link that opens Recipes and sets everything up. Send it, or open it on this device to try it. Delete the token under API Tokens in Mealie to revoke an account or read-only link; an invitation works once.")
            }
        }
        .disabled(making != nil)
    }

    private func make(_ kind: MealieLink.Kind) async {
        making = kind
        failure = nil
        defer { making = nil }
        do {
            shareLink = try await mealie.makeShareLink(kind: kind)
        } catch {
            failure = error.localizedDescription
        }
    }

    // MARK: - Browse

    private var serversSection: some View {
        Section {
            ForEach(discover.sources) { source in
                LabeledContent {
                    Text(source.username ?? "")
                } label: {
                    Text(source.name)
                    if source.label != nil { Text(source.host) }
                }
                .contextMenu { menu(for: source) }
                .swipeActions {
                    Button("Remove", role: .destructive) { discover.remove(source) }
                    Button("Rename") { rename(source) }
                }
            }
            .onMove { discover.move(from: $0, to: $1) }
            Button { addingServer = true } label: { Label("Add Server", systemImage: "plus") }
        } header: {
            Text("Browse in Discover")
        } footer: {
            Text("These show on the Discover tab, read-only, with Add to My Recipes on every recipe. Add the same server as often as you like, including the one you sync with.")
        }
    }

    @ViewBuilder
    private func menu(for source: DiscoverSource) -> some View {
        Button("Rename", systemImage: "pencil") { rename(source) }
        if let link = source.link {
            Button("Copy Read-Only Link", systemImage: "link") { Pasteboard.copy(link.url.absoluteString) }
        }
        Button("Remove", systemImage: "trash", role: .destructive) { discover.remove(source) }
    }

    private func rename(_ source: DiscoverSource) {
        newName = source.label ?? ""
        renaming = source
    }
}

extension MealieLink.Kind {
    static let shareable: [Self] = [.invite, .sync, .discover]

    var shareTitle: String {
        switch self {
        case .invite: "Add a New User"
        case .sync: "Share This Account"
        case .discover: "Share Read-Only"
        }
    }

    var shareDetail: String {
        switch self {
        case .invite: "They make their own account on your server and sync its recipes."
        case .sync: "Signs them in as you, to sync your recipes, plan and groceries."
        case .discover: "They browse your recipes in Discover and copy the ones they like."
        }
    }

    var symbol: String {
        switch self {
        case .invite: "person.badge.plus"
        case .sync: "key.horizontal"
        case .discover: "binoculars"
        }
    }

    var warning: String {
        switch self {
        case .invite: "This invitation lets one person make an account on your server, in your household, so they see and can change the same recipes."
        case .sync: "A new token was made for this link. Anyone who opens it can read and change your Mealie recipes as you, so send it only to people you trust."
        case .discover: "A new token was made for this link. Whoever opens it can browse your recipes in Recipes and copy them. The token could also change them outside the app, so send it only to people you trust."
        }
    }

    var message: String {
        switch self {
        case .invite: "Open this on a phone with Recipes to make an account on my Mealie server."
        case .sync: "Open this on a phone with Recipes to sync with my Mealie server."
        case .discover: "Open this on a phone with Recipes to browse my recipes."
        }
    }
}

extension MealieLink: Identifiable {
    public var id: String { url.absoluteString }
}

/// The link just made: send it, copy it, or open it here to try it.
struct MealieShareLinkSheet: View {
    @Environment(\.dismiss) private var dismiss
    let link: MealieLink
    @State private var copied = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Label { Text(link.kind.warning) } icon: { Image(systemName: link.kind.symbol).foregroundStyle(.tint) }
                }
                Section("Link") {
                    Text(link.url.absoluteString)
                        .appFont(.footnote)
                        .monospaced()
                        .textSelection(.enabled)
                        .lineLimit(4)
                    ShareLink(item: link.url, message: Text(link.kind.message)) { Label("Send Link", systemImage: "square.and.arrow.up") }
                    Button {
                        Pasteboard.copy(link.url.absoluteString)
                        copied = true
                    } label: {
                        Label(copied ? "Copied" : "Copy Link", systemImage: copied ? "checkmark" : "doc.on.doc")
                    }
                    Button {
                        dismiss()
                        AppRouter.shared.mealieLink = link
                    } label: {
                        Label("Open Link Here", systemImage: "arrow.up.forward.app")
                    }
                }
            }
            .formStyle(.grouped)
            .navigationTitle(link.kind.shareTitle)
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar { ToolbarItem(placement: .confirmationAction) { ConfirmButton { dismiss() } } }
        }
        .presentationDetents([.medium, .large])
        #if os(macOS)
        .frame(minWidth: 460, minHeight: 360)
        #endif
    }
}

/// Opened from an invite link: makes a new user on the server, then syncs with it as them.
struct JoinMealieSheet: View {
    @EnvironmentObject private var mealie: MealieSyncController
    @Environment(\.dismiss) private var dismiss
    let link: MealieLink
    @State private var fullName = ""
    @State private var email = ""
    @State private var username = ""
    @State private var password = ""
    @State private var isJoining = false
    @State private var failure: String?

    private var host: String { link.server.host() ?? link.server.absoluteString }

    private var isComplete: Bool {
        [fullName, email, username].allSatisfy { !$0.trimmingCharacters(in: .whitespaces).isEmpty } && password.count >= 8
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Name", text: $fullName)
                        #if os(iOS)
                        .textContentType(.name)
                        #endif
                    TextField("Email", text: $email)
                        .autocorrectionDisabled()
                        #if os(iOS)
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        #endif
                    TextField("Username", text: $username)
                        .autocorrectionDisabled()
                        #if os(iOS)
                        .textContentType(.username)
                        .textInputAutocapitalization(.never)
                        #endif
                    SecureField("Password", text: $password)
                        #if os(iOS)
                        .textContentType(.newPassword)
                        #endif
                } header: {
                    Text("Your Account on \(host)")
                } footer: {
                    if let failure {
                        Text(failure).foregroundStyle(.red)
                    } else {
                        Text(footer)
                    }
                }
            }
            .formStyle(.grouped)
            .navigationTitle("Join Mealie")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { CancelButton() }
                ToolbarItem(placement: .confirmationAction) {
                    if isJoining {
                        ProgressView()
                    } else {
                        ConfirmButton(title: "Join", isDisabled: !isComplete) { Task { await join() } }
                    }
                }
            }
        }
        .interactiveDismissDisabled(isJoining)
        #if os(macOS)
        .frame(minWidth: 420, minHeight: 360)
        #endif
    }

    private var footer: String {
        let replaced = mealie.isConnected ? " This replaces your current Mealie connection on every device signed in to your iCloud account." : ""
        return "Someone invited you to their Mealie server. Recipes makes your account, then syncs your recipes with theirs. Passwords need at least 8 characters.\(replaced)"
    }

    private func join() async {
        isJoining = true
        failure = nil
        defer { isJoining = false }
        let registration = MealieClient.Registration(
            fullName: fullName.trimmingCharacters(in: .whitespaces), email: email.trimmingCharacters(in: .whitespaces),
            username: username.trimmingCharacters(in: .whitespaces), password: password
        )
        do {
            try await mealie.join(link, as: registration)
            dismiss()
        } catch {
            failure = error.localizedDescription
        }
    }
}

enum Pasteboard {
    static func copy(_ text: String) {
        #if os(iOS)
        UIPasteboard.general.string = text
        #else
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        #endif
    }
}

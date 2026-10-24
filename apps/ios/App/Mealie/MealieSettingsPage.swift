import RecipeKit
import SwiftUI

struct MealieSettingsPage: View {
    @EnvironmentObject private var mealie: MealieSyncController
    @EnvironmentObject private var discover: DiscoverController
    @AppStorage(AppSettings.Key.mealieSyncPlan) private var syncPlan = true
    @AppStorage(AppSettings.Key.mealieSyncGroceries) private var syncGroceries = true
    @AppStorage(AppSettings.Key.mealieList) private var listName = "Recipes"

    @State private var address = ""
    @State private var token = ""
    @State private var isConnecting = false
    @State private var connectError: String?
    @State private var isConfirmingDisconnect = false
    @State private var shareError: String?
    @State private var shareLink: MealieLink?
    @State private var sharingKind: MealieLink.Kind?
    @State private var addingDiscover = false

    var body: some View {
        Form {
            if mealie.isConnected { connected } else { signIn }
            discoverSection
        }
        .formStyle(.grouped)
        .themedCanvas()
        .navigationTitle("Mealie")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .confirmationDialog("Disconnect from Mealie?", isPresented: $isConfirmingDisconnect, titleVisibility: .visible) {
            Button("Disconnect", role: .destructive) { mealie.disconnect() }
        }
        .sheet(item: $shareLink) { link in
            ShareAccessSheet(link: link)
                .presentationDetents([.medium])
        }
        .sheet(isPresented: $addingDiscover) { AddDiscoverSheet() }
    }

    private func share(_ kind: MealieLink.Kind) async {
        sharingKind = kind
        shareError = nil
        defer { sharingKind = nil }
        do {
            shareLink = try await mealie.makeShareLink(kind: kind)
        } catch {
            shareError = error.localizedDescription
        }
    }

    // MARK: - Discover

    private var discoverSection: some View {
        Section {
            ForEach(discover.sources) { source in
                LabeledContent(source.name, value: source.username ?? "")
                    .swipeActions { Button("Remove", role: .destructive) { discover.remove(source) } }
                    .contextMenu { Button("Remove", systemImage: "trash", role: .destructive) { discover.remove(source) } }
            }
            Button {
                addingDiscover = true
            } label: {
                Label("Add Discover Server", systemImage: "plus")
            }
        } header: {
            Text("Discover")
        } footer: {
            Text("Browse someone else's Mealie recipes under Discover on the Recipes tab, and add the ones you like to your own. Recipes only reads from these servers.")
        }
    }

    // MARK: - Not connected

    @ViewBuilder
    private var signIn: some View {
        Section {
            TextField("Server address", text: $address, prompt: Text(verbatim: "https://mealie.example.com"))
                .autocorrectionDisabled()
                #if os(iOS)
                .textInputAutocapitalization(.never)
                .keyboardType(.URL)
                .textContentType(.URL)
                #endif
            SecureField("API token", text: $token)
                .autocorrectionDisabled()
                #if os(iOS)
                .textInputAutocapitalization(.never)
                #endif
        } header: {
            Text("Connect")
        } footer: {
            Text("Sync your recipes, photos, timelines, planned meals and groceries with your own Mealie server. In Mealie, open your profile, choose API Tokens, and create one. Use https:// unless the server is on your home network.")
        }
        Section {
            Button {
                Task { await connect() }
            } label: {
                if isConnecting { ProgressView() } else { Text("Connect") }
            }
            .disabled(isConnecting || address.trimmingCharacters(in: .whitespaces).isEmpty || token.trimmingCharacters(in: .whitespaces).isEmpty)
        } footer: {
            if let connectError {
                Text(connectError).foregroundStyle(.red)
            } else {
                Text("Everything is copied both ways, and when the same recipe was edited in both places the later edit is kept. Nothing is deleted without a matching deletion on the other side.")
            }
        }
    }

    private func connect() async {
        isConnecting = true
        connectError = nil
        defer { isConnecting = false }
        do {
            try await mealie.connect(address: address, token: token)
            token = ""
        } catch {
            connectError = error.localizedDescription
        }
    }

    // MARK: - Connected

    @ViewBuilder
    private var connected: some View {
        Section {
            LabeledContent("Server", value: mealie.address ?? "")
            if let username = mealie.username, !username.isEmpty { LabeledContent("Signed in as", value: username) }
            statusRow
            if case .failed(_, let canForce) = mealie.status, canForce {
                Button("Sync Anyway") { Task { await mealie.syncNow(allowMassDeletion: true) } }
            }
            Button {
                Task { await mealie.syncNow() }
            } label: {
                Label("Sync Now", systemImage: "arrow.triangle.2.circlepath")
            }
            .disabled(mealie.status == .syncing)
        } header: {
            Text("Mealie")
        } footer: {
            if case .synced(_, let problems) = mealie.status, !problems.isEmpty {
                Text(problems.prefix(3).joined(separator: "\n"))
            } else {
                Text("Recipes, photos and timelines always sync. Edits made in Mealie appear here within a couple of minutes.")
            }
        }
        Section {
            Toggle("Planned meals", isOn: $syncPlan)
            Toggle("Groceries", isOn: $syncGroceries)
            if syncGroceries {
                TextField("Shopping list", text: $listName, prompt: Text("Recipes"))
            }
        } header: {
            Text("Also sync")
        } footer: {
            Text("Groceries go to one Mealie shopping list, made for you if it doesn't exist. Grocery items can also sync with Reminders.")
        }
        if mealie.canShareAccess {
            Section {
                Button {
                    Task { await share(.sync) }
                } label: {
                    if sharingKind == .sync { ProgressView() } else { Label("Share Access", systemImage: "square.and.arrow.up") }
                }
                Button {
                    Task { await share(.discover) }
                } label: {
                    if sharingKind == .discover { ProgressView() } else { Label("Share as Discover", systemImage: "binoculars") }
                }
            } footer: {
                if let shareError {
                    Text(shareError).foregroundStyle(.red)
                } else {
                    Text("Each makes a new API token and a link for it. Share Access connects Recipes on another device to this server to sync. Share as Discover lets someone browse your recipes and copy the ones they like; Recipes never changes anything with it, but the token itself could, so send either only to people you trust. Delete the token under API Tokens in Mealie to revoke it.")
                }
            }
            .disabled(sharingKind != nil)
        }
        Section {
            Button("Disconnect", role: .destructive) { isConfirmingDisconnect = true }
        } footer: {
            Text("Stops syncing and forgets the token. Your recipes stay here and in Mealie.")
        }
    }

    @ViewBuilder
    private var statusRow: some View {
        switch mealie.status {
        case .disconnected, .idle:
            LabeledContent("Status", value: "Waiting to sync")
        case .syncing:
            LabeledContent("Status") { ProgressView().controlSize(.small) }
        case .synced(let date, let problems):
            LabeledContent("Status") {
                if problems.isEmpty {
                    Text("Synced \(date.formatted(.relative(presentation: .named)))")
                } else {
                    Text("Synced with \(problems.count) \(problems.count == 1 ? "problem" : "problems")").foregroundStyle(.orange)
                }
            }
        case .failed(let message, _):
            LabeledContent("Status") { Text(message).foregroundStyle(.red).multilineTextAlignment(.trailing) }
        }
    }
}

private struct ShareAccessSheet: View {
    @Environment(\.dismiss) private var dismiss
    let link: MealieLink

    private var isDiscover: Bool { link.kind == .discover }

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Image(systemName: isDiscover ? "binoculars" : "key.horizontal").font(.largeTitle).foregroundStyle(.tint)
                Text(isDiscover
                     ? "A new token was made for this link. Whoever opens it can browse your Mealie recipes in Recipes and copy them. The token could also change them outside the app, so send it only to people you trust."
                     : "A new token was made for this link. Anyone who opens it can read and change your Mealie recipes, so send it only to people you trust.")
                    .multilineTextAlignment(.center)
                ShareLink(item: link.url, message: Text(isDiscover ? "Open this on a phone with Recipes to browse my recipes." : "Open this on a phone with Recipes to sync with my Mealie server.")) {
                    Label("Send Link", systemImage: "square.and.arrow.up")
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()
            .navigationTitle(isDiscover ? "Share as Discover" : "Share Access")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar { ToolbarItem(placement: .confirmationAction) { ConfirmButton { dismiss() } } }
        }
    }
}

extension MealieLink: Identifiable {
    public var id: String { token }
}

private struct AddDiscoverSheet: View {
    @EnvironmentObject private var discover: DiscoverController
    @Environment(\.dismiss) private var dismiss
    @State private var address = ""
    @State private var token = ""
    @State private var isAdding = false
    @State private var failure: String?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Server address", text: $address, prompt: Text(verbatim: "https://mealie.example.com"))
                        .autocorrectionDisabled()
                        #if os(iOS)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.URL)
                        .textContentType(.URL)
                        #endif
                    SecureField("API token", text: $token)
                        .autocorrectionDisabled()
                        #if os(iOS)
                        .textInputAutocapitalization(.never)
                        #endif
                } footer: {
                    if let failure {
                        Text(failure).foregroundStyle(.red)
                    } else {
                        Text("Ask whoever runs the server for an API token, or for a Share as Discover link, which fills this in for you.")
                    }
                }
            }
            .formStyle(.grouped)
            .navigationTitle("Add Discover Server")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { CancelButton() }
                ToolbarItem(placement: .confirmationAction) {
                    if isAdding {
                        ProgressView()
                    } else {
                        ConfirmButton(title: "Add", isDisabled: address.trimmingCharacters(in: .whitespaces).isEmpty || token.trimmingCharacters(in: .whitespaces).isEmpty) {
                            Task { await add() }
                        }
                    }
                }
            }
        }
        #if os(macOS)
        .frame(minWidth: 420, minHeight: 260)
        #endif
    }

    private func add() async {
        isAdding = true
        failure = nil
        defer { isAdding = false }
        do {
            try await discover.add(address: address, token: token)
            dismiss()
        } catch {
            failure = error.localizedDescription
        }
    }
}

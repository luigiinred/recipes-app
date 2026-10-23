import RecipeKit
import SwiftUI

struct MealieSettingsPage: View {
    @EnvironmentObject private var mealie: MealieSyncController
    @AppStorage(AppSettings.Key.mealieSyncPlan) private var syncPlan = true
    @AppStorage(AppSettings.Key.mealieSyncGroceries) private var syncGroceries = true
    @AppStorage(AppSettings.Key.mealieList) private var listName = "Recipes"

    @State private var address = ""
    @State private var token = ""
    @State private var isConnecting = false
    @State private var connectError: String?
    @State private var isConfirmingDisconnect = false
    @State private var isSharing = false
    @State private var shareError: String?
    @State private var shareLink: MealieLink?

    var body: some View {
        Form {
            if mealie.isConnected { connected } else { signIn }
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
    }

    private func share() async {
        isSharing = true
        shareError = nil
        defer { isSharing = false }
        do {
            shareLink = try await mealie.makeShareLink()
        } catch {
            shareError = error.localizedDescription
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
                    Task { await share() }
                } label: {
                    if isSharing { ProgressView() } else { Label("Share Access", systemImage: "square.and.arrow.up") }
                }
                .disabled(isSharing)
            } footer: {
                if let shareError {
                    Text(shareError).foregroundStyle(.red)
                } else {
                    Text("Makes a new API token and a link that connects Recipes on another device to this server. Anyone who opens it can read and change your Mealie recipes, so send it only to people you trust. Delete the token under API Tokens in Mealie to revoke it.")
                }
            }
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

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Image(systemName: "key.horizontal").font(.largeTitle).foregroundStyle(.tint)
                Text("A new token was made for this link. Anyone who opens it can read and change your Mealie recipes, so send it only to people you trust.")
                    .multilineTextAlignment(.center)
                ShareLink(item: link.url, message: Text("Open this on a phone with Recipes to sync with my Mealie server.")) {
                    Label("Send Link", systemImage: "square.and.arrow.up")
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()
            .navigationTitle("Share Access")
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

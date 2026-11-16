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

    var body: some View {
        Form {
            if mealie.isConnected { connected } else { signIn }
            discoverSection
        }
        .formStyle(.grouped)
        .settingsSpacing()
        .themedCanvas()
        .navigationTitle("Mealie")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .confirmationDialog("Disconnect from Mealie?", isPresented: $isConfirmingDisconnect, titleVisibility: .visible) {
            Button("Disconnect", role: .destructive) { mealie.disconnect() }
        }
    }

    // MARK: - Discover

    private var discoverSection: some View {
        Section {
            NavigationLink { MealieSharingPage() } label: {
                LabeledContent {
                    if !discover.sources.isEmpty { Text("\(discover.sources.count)") }
                } label: {
                    Label("Sharing and Discover Servers", systemImage: "person.2")
                }
            }
        } footer: {
            Text("Invite someone, share this account or a read-only link, and choose the servers you browse on the Discover tab.")
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

struct AddDiscoverSheet: View {
    @EnvironmentObject private var discover: DiscoverController
    @EnvironmentObject private var mealie: MealieSyncController
    @SheetDismiss private var dismiss
    @State private var address = ""
    @State private var token = ""
    @State private var label = ""
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
                    TextField("Name (optional)", text: $label)
                } footer: {
                    if let failure {
                        Text(failure).foregroundStyle(.red)
                    } else {
                        Text("No account needed: Recipes shows the server's public recipes. Paste a group's page (…/g/name) to browse that group. A name tells apart servers added more than once.")
                    }
                }
                Section {
                    SecureField("API token (optional)", text: $token)
                        .autocorrectionDisabled()
                        #if os(iOS)
                        .textInputAutocapitalization(.never)
                        #endif
                } header: {
                    Text("Private Recipes")
                } footer: {
                    Text("With a token, or a Share Read-Only link that fills it in, you see everything that user can see, not only public recipes.")
                }
                if let connection = mealie.connection {
                    Section {
                        Button {
                            address = connection.server
                            token = connection.token
                            if label.isEmpty { label = "My Mealie" }
                        } label: {
                            Label("Use the Server I Sync With", systemImage: "arrow.triangle.2.circlepath")
                        }
                    } footer: {
                        Text("Browses your own server read-only, the way someone you share it with would see it.")
                    }
                }
            }
            .formStyle(.grouped)
            .panelTitle("Add Discover Server")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { CancelButton() }
                ToolbarItem(placement: .confirmationAction) {
                    if isAdding {
                        ProgressView()
                    } else {
                        ConfirmButton(title: "Add", isDisabled: address.trimmingCharacters(in: .whitespaces).isEmpty) {
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
            try await discover.add(address: address, token: token, label: label)
            dismiss()
        } catch {
            failure = error.localizedDescription
        }
    }
}

import Foundation
import RecipeKit

/// Runs the Mealie sync for the app: connects with an address and token, then syncs on a timer and soon after anything changes.
@MainActor
final class MealieSyncController: ObservableObject {
    enum Status: Equatable {
        case disconnected
        case idle
        case syncing
        case synced(Date, problems: [String])
        case failed(String, canForce: Bool)
    }

    @Published private(set) var status: Status
    @Published private(set) var connection: MealieCredentials.Connection?

    private let defaults: UserDefaults
    private var pokeRequested = false
    private var isRunning = false
    private static let interval = 120
    private static let settleSeconds = 5

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        previewAddress = nil
        previewUsername = nil
        status = .disconnected
        connection = MealieCredentials.load()
            ?? MealieCredentials.migrateLegacy(
                server: defaults.string(forKey: AppSettings.Key.mealieServer),
                username: defaults.string(forKey: AppSettings.Key.mealieUser)
            )
        defaults.removeObject(forKey: AppSettings.Key.mealieServer)
        defaults.removeObject(forKey: AppSettings.Key.mealieUser)
        if connection != nil { status = .idle }
    }

    /// For previews and snapshots, which show a fixed state without touching the network or Keychain.
    init(previewing status: Status, address: String? = nil, username: String? = nil) {
        defaults = .standard
        previewAddress = address
        previewUsername = username
        self.status = status
    }

    private let previewAddress: String?
    private let previewUsername: String?

    var address: String? { previewAddress ?? connection?.server }
    var username: String? { previewUsername ?? connection?.username }
    var isConnected: Bool { previewAddress != nil || connection != nil }

    // MARK: - Connecting

    /// Checks the address and token against the server, then keeps them in the iCloud Keychain and starts syncing.
    func connect(address: String, token: String) async throws {
        guard let url = MealieClient.normalizedServer(address) else { throw MealieError.notMealie }
        let token = token.trimmingCharacters(in: .whitespacesAndNewlines)
        let user = try await MealieClient(server: url, token: token).currentUser()
        let paired = MealieCredentials.Connection(server: url.absoluteString, username: user.username, token: token)
        MealieCredentials.save(paired)
        connection = paired
        status = .idle
        request()
    }

    /// Stops syncing and forgets the token on every device. Recipes already copied either way stay where they are.
    func disconnect() {
        MealieCredentials.clear()
        connection = nil
        status = .disconnected
    }

    /// Picks up a pairing made or removed on another device.
    func refresh() {
        guard previewAddress == nil else { return }
        let stored = MealieCredentials.load()
        guard stored != connection else { return }
        connection = stored
        if stored == nil {
            status = .disconnected
        } else {
            if status == .disconnected { status = .idle }
            request()
        }
    }

    // MARK: - Syncing

    /// Asks for a pass soon; the loop folds several requests into one.
    func request() {
        guard isConnected else { return }
        pokeRequested = true
    }

    func run() async {
        guard !isRunning else { return }
        isRunning = true
        defer { isRunning = false }
        var waited = Self.interval
        while !Task.isCancelled {
            if !isConnected || waited >= Self.interval { refresh() }
            if isConnected, pokeRequested || waited >= Self.interval {
                pokeRequested = false
                await syncNow()
                try? await Task.sleep(for: .seconds(Self.settleSeconds))
                waited = Self.settleSeconds
            }
            let step = isConnected ? 1 : 5
            try? await Task.sleep(for: .seconds(step))
            waited += step
        }
    }

    func syncNow(allowMassDeletion: Bool = false) async {
        guard let connection, let url = MealieClient.normalizedServer(connection.server) else {
            status = .disconnected
            return
        }
        let token = connection.token
        if status == .syncing { return }
        status = .syncing
        let resolved = await Task.detached { RecipeLocation.resolveForApp() }.value
        let options = MealieSync.Options(
            shoppingListName: defaults.string(forKey: AppSettings.Key.mealieList)?.nonEmpty ?? "Recipes",
            syncMealPlan: defaults.object(forKey: AppSettings.Key.mealieSyncPlan) as? Bool ?? true,
            syncGroceries: defaults.object(forKey: AppSettings.Key.mealieSyncGroceries) as? Bool ?? true,
            allowMassDeletion: allowMassDeletion
        )
        let sync = MealieSync(
            library: Library(root: resolved.root), server: url, api: MealieClient(server: url, token: token),
            stateURL: MealieSync.defaultStateURL(library: resolved.root, server: url), options: options
        )
        do {
            let report = try await sync.sync()
            status = .synced(Date(), problems: report.problems)
        } catch let error as MealieError {
            if case .tooManyDeletions = error { status = .failed(error.localizedDescription, canForce: true) } else { status = .failed(error.localizedDescription, canForce: false) }
        } catch {
            status = .failed(error.localizedDescription, canForce: false)
        }
    }
}

private extension String {
    var nonEmpty: String? { isEmpty ? nil : self }
}

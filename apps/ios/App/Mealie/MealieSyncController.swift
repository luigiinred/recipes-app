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
    @Published private(set) var username: String?

    private let defaults: UserDefaults
    private var pokeRequested = false
    private var isRunning = false
    private static let interval = 120
    private static let settleSeconds = 5

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        previewAddress = nil
        status = .disconnected
        username = defaults.string(forKey: AppSettings.Key.mealieUser)
        if isConnected { status = .idle }
    }

    /// For previews and snapshots, which show a fixed state without touching the network or Keychain.
    init(previewing status: Status, address: String? = nil, username: String? = nil) {
        defaults = .standard
        previewAddress = address
        self.status = status
        self.username = username
    }

    private let previewAddress: String?

    var address: String? { previewAddress ?? defaults.string(forKey: AppSettings.Key.mealieServer) }

    var isConnected: Bool {
        guard let address else { return false }
        return previewAddress != nil || MealieCredentials.token(for: address) != nil
    }

    // MARK: - Connecting

    /// Checks the address and token against the server, then keeps them and starts syncing.
    func connect(address: String, token: String) async throws {
        guard let url = MealieClient.normalizedServer(address) else { throw MealieError.notMealie }
        let token = token.trimmingCharacters(in: .whitespacesAndNewlines)
        let user = try await MealieClient(server: url, token: token).currentUser()
        MealieCredentials.setToken(token, for: url.absoluteString)
        defaults.set(url.absoluteString, forKey: AppSettings.Key.mealieServer)
        defaults.set(user.username, forKey: AppSettings.Key.mealieUser)
        username = user.username
        status = .idle
        request()
    }

    /// Stops syncing and forgets the token. Recipes already copied either way stay where they are.
    func disconnect() {
        if let address { MealieCredentials.setToken(nil, for: address) }
        defaults.removeObject(forKey: AppSettings.Key.mealieServer)
        defaults.removeObject(forKey: AppSettings.Key.mealieUser)
        username = nil
        status = .disconnected
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
        guard let address, let url = MealieClient.normalizedServer(address), let token = MealieCredentials.token(for: address) else {
            status = .disconnected
            return
        }
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

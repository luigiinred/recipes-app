import Foundation
import RecipeKit

/// A Mealie server someone shared to browse. The app only ever reads from it.
struct DiscoverSource: Codable, Identifiable, Hashable {
    var id = UUID()
    var server: String
    var token: String
    var username: String?
    var label: String?
    /// Set for a public group, browsed without a token.
    var group: String?

    var host: String { URL(string: server)?.host() ?? server }
    var name: String { label?.trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty ?? host }
    var link: MealieLink? { MealieClient.normalizedServer(server).map { MealieLink(server: $0, token: token, kind: .discover, group: group) } }
    var browser: MealieBrowser? { MealieClient.normalizedServer(server).map { MealieBrowser(server: $0, token: token, group: group) } }
}

/// The servers shown in Discover on the Recipes tab, each with the recipes read from it so far.
@MainActor
final class DiscoverController: ObservableObject {
    @Published private(set) var sources: [DiscoverSource]
    private var catalogs: [UUID: DiscoverCatalog] = [:]
    private let isPreview: Bool

    init() {
        isPreview = false
        sources = MealieCredentials.discoverSources()
    }

    /// For previews and snapshots, which show fixed recipes without touching the network or Keychain.
    init(previewing catalogs: [DiscoverCatalog]) {
        isPreview = true
        sources = catalogs.map(\.source)
        self.catalogs = Dictionary(uniqueKeysWithValues: catalogs.map { ($0.source.id, $0) })
    }

    func catalog(for id: UUID) -> DiscoverCatalog? {
        if let catalog = catalogs[id] { return catalog }
        guard let source = sources.first(where: { $0.id == id }) else { return nil }
        let catalog = DiscoverCatalog(source: source)
        catalogs[id] = catalog
        return catalog
    }

    /// Checks the token against the server first. A server can be added more than once, even the one you sync with,
    /// so each entry is its own way in.
    @discardableResult
    /// With no token, reads the public recipes of the group the address names (`…/g/<group>`), or the server's default group.
    func add(address: String, token: String, label: String? = nil) async throws -> DiscoverSource {
        let token = token.trimmingCharacters(in: .whitespacesAndNewlines)
        let server: URL
        var group: String?
        if token.isEmpty {
            if let page = MealieClient.publicPage(address) {
                (server, group) = (page.server, page.group)
            } else {
                guard let url = MealieClient.normalizedServer(address) else { throw MealieError.notMealie }
                server = url
                group = await MealieClient(server: url, token: "").defaultGroup()
            }
        } else {
            guard let url = MealieClient.normalizedServer(address) else { throw MealieError.notMealie }
            server = url
        }
        var source = DiscoverSource(
            server: server.absoluteString, token: token, label: label?.trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty, group: group
        )
        source.username = try await source.browser?.check()
        sources.append(source)
        save()
        return source
    }

    func rename(_ source: DiscoverSource, to label: String) {
        guard let index = sources.firstIndex(where: { $0.id == source.id }) else { return }
        sources[index].label = label.trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty
        save()
    }

    func move(from offsets: IndexSet, to destination: Int) {
        sources.move(fromOffsets: offsets, toOffset: destination)
        save()
    }

    func remove(_ source: DiscoverSource) {
        sources.removeAll { $0.id == source.id }
        catalogs[source.id] = nil
        save()
    }

    /// Picks up servers added or removed on another device.
    func refresh() {
        guard !isPreview else { return }
        let stored = MealieCredentials.discoverSources()
        guard stored != sources else { return }
        for source in sources where !stored.contains(source) { catalogs[source.id] = nil }
        sources = stored
    }

    private func save() {
        guard !isPreview else { return }
        MealieCredentials.saveDiscoverSources(sources)
    }
}

/// One server's recipes, read into an in-memory library so the Recipes tab's own views can show them.
@MainActor
final class DiscoverCatalog: ObservableObject {
    enum State: Equatable {
        case loading
        case loaded
        case failed(String)
    }

    let source: DiscoverSource
    let library: RecipeLibrary
    @Published private(set) var state = State.loading
    @Published private(set) var detailed: Set<UUID> = []
    @Published private(set) var added: Set<UUID> = []
    @Published var problem: String?

    private let browser: MealieBrowser?
    private var slugs: [UUID: String] = [:]
    private var photos: [UUID: Data] = [:]
    private var isLoading = false

    init(source: DiscoverSource) {
        self.source = source
        let browser = source.browser
        self.browser = browser
        library = RecipeLibrary(browsing: { id in await browser?.image(for: id, thumbnail: true) })
    }

    init(previewing source: DiscoverSource, recipes: [Recipe], images: [UUID: Data] = [:]) {
        self.source = source
        browser = nil
        library = RecipeLibrary(recipes: recipes, images: images)
        photos = images
        detailed = Set(recipes.map(\.id))
        state = .loaded
    }

    func load(force: Bool = false) async {
        guard let browser, !isLoading, force || state != .loaded else { return }
        isLoading = true
        defer { isLoading = false }
        if state != .loaded { state = .loading }
        do {
            let entries = try await browser.recipes()
            slugs = Dictionary(entries.map { ($0.recipe.id, $0.slug) }, uniquingKeysWith: { first, _ in first })
            detailed = []
            library.browse(entries.map(\.recipe), imageIDs: Set(entries.filter(\.hasImage).map(\.recipe.id)))
            state = .loaded
        } catch {
            if state != .loaded { state = .failed(error.localizedDescription) }
        }
    }

    /// The list leaves out ingredients and steps, so a recipe is read in full when it's opened.
    func loadDetails(_ id: UUID) async throws {
        guard let browser, !detailed.contains(id), let slug = slugs[id] else { return }
        guard let recipe = try await browser.recipe(slug: slug) else { throw MealieError.notMealie }
        library.browse(recipe)
        detailed.insert(id)
    }

    func photo(for id: UUID) async -> Data? {
        if let data = photos[id] { return data }
        guard let browser, library.hasImage(id), let data = await browser.image(for: id, thumbnail: false) else { return nil }
        photos[id] = data
        return data
    }

    /// Saves a copy to your own recipes, with its photo.
    func add(_ id: UUID, to mine: RecipeLibrary) async {
        do {
            try await loadDetails(id)
            guard let recipe = library.recipe(id: id) else { return }
            let photo = await photo(for: id).flatMap { RecipeImageProcessing.jpegData(from: $0) }
            await mine.save(MealieBrowser.copy(of: recipe), image: photo.map(ImageChange.set) ?? .unchanged)
            added.insert(id)
        } catch {
            problem = error.localizedDescription
        }
    }
}

private extension String {
    var nonEmpty: String? { isEmpty ? nil : self }
}

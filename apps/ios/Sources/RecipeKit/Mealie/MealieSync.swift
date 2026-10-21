import Foundation

/// Keeps a library folder in step with a Mealie server: recipes with their photos, the meal plan and one shopping list.
///
/// Each pass compares three things per item: the library now, Mealie now, and what both had after the last pass.
/// Whoever changed since then wins, and when both did, the later recipe edit wins. Mealie has no change feed, so
/// that last-pass snapshot lives in a per-device state file kept outside the library folder.
public struct MealieSync: Sendable {
    public struct Options: Sendable, Equatable {
        public var shoppingListName: String
        public var syncMealPlan: Bool
        public var syncGroceries: Bool
        public var allowMassDeletion: Bool

        public init(shoppingListName: String = "Recipes", syncMealPlan: Bool = true, syncGroceries: Bool = true, allowMassDeletion: Bool = false) {
            self.shoppingListName = shoppingListName
            self.syncMealPlan = syncMealPlan
            self.syncGroceries = syncGroceries
            self.allowMassDeletion = allowMassDeletion
        }
    }

    public struct Counts: Codable, Equatable, Sendable {
        public var sent = 0
        public var received = 0
        public var deletedInMealie = 0
        public var deletedHere = 0
        /// Items edited on both sides since the last pass.
        public var conflicts = 0

        public init() {}

        var changedAnything: Bool { sent + received + deletedInMealie + deletedHere > 0 }
    }

    public struct Report: Codable, Equatable, Sendable {
        public var recipes = Counts()
        public var photos = Counts()
        public var mealPlan = Counts()
        public var groceries = Counts()
        public var timeline = Counts()
        /// Items Mealie refused or that changed mid-pass; the next pass tries them again.
        public var problems: [String] = []

        public init() {}

        public var changedAnything: Bool { recipes.changedAnything || photos.changedAnything || mealPlan.changedAnything || groceries.changedAnything || timeline.changedAnything }
    }

    struct RecipeLink: Codable, Equatable {
        var remoteID: String
        var slug: String
        var localHash: String
        var remoteStamp: Double
        var imageHash: String?
        var imageToken: String?
        var imageMtime: Double?
        var imageSize: Int?
    }

    struct HashLink: Codable, Equatable {
        var remoteID: String
        var hash: String
    }

    struct State: Codable {
        var server: String
        var userID: String?
        var shoppingListID: String?
        var shoppingListName: String?
        var recipes: [String: RecipeLink] = [:]
        var mealPlan: [String: HashLink] = [:]
        var groceries: [String: HashLink] = [:]
        /// Timeline event ids here to the Mealie events they match. Optional so older state files still load.
        var timelineLinks: [String: String]?
    }

    let library: Library
    let server: URL
    let api: any MealieAPI
    let stateURL: URL
    let options: Options

    public init(library: Library, server: URL, api: any MealieAPI, stateURL: URL, options: Options = Options()) {
        self.library = library
        self.server = server
        self.api = api
        self.stateURL = stateURL
        self.options = options
    }

    /// Where a device keeps its last-pass snapshot for one library and one server. Not inside the library, which iCloud shares between devices.
    public static func defaultStateURL(library: URL, server: URL) -> URL {
        let key = ServerSync.sha256(Data("\(library.standardizedFileURL.path)\n\(server.absoluteString)".utf8)).prefix(16)
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first ?? FileManager.default.temporaryDirectory
        return base.appendingPathComponent("MealieSync", isDirectory: true).appendingPathComponent("\(key).json")
    }

    @discardableResult
    public func sync() async throws -> Report {
        var state = loadState()
        let user = try await api.currentUser()
        if state.userID != nil, state.userID != user.id { state = State(server: server.absoluteString) }
        state.userID = user.id
        var report = Report()
        do {
            try await syncRecipes(&state, user: user, report: &report)
            try await syncTimeline(&state, user: user, report: &report)
            if options.syncMealPlan { try await syncMealPlan(&state, report: &report) }
            if options.syncGroceries { try await syncGroceries(&state, report: &report) }
        } catch {
            saveState(state)
            throw error
        }
        saveState(state)
        return report
    }

    // MARK: - Recipes

    struct LocalRecipe {
        var recipe: Recipe
        var hash: String
    }

    private enum RecipeStep {
        case create(LocalRecipe)
        case push(LocalRecipe, remote: MealieRecipeSummary)
        case pull(MealieRecipeSummary, localID: UUID, detail: MealieObject?, expectedHash: String?)
        case deleteRemote(UUID, remote: MealieRecipeSummary)
        case deleteLocal(LocalRecipe)
        case unlink(UUID)
    }

    private func syncRecipes(_ state: inout State, user: MealieUser, report: inout Report) async throws {
        let summaries = try await api.recipeList()
        let ratings = try await api.ratings()
        let remoteByID = Dictionary(summaries.map { ($0.id, $0) }, uniquingKeysWith: { $1 })
        let scan = try readLocalRecipes()
        let local = scan.recipes
        var steps: [RecipeStep] = []

        for (key, link) in state.recipes.sorted(by: { $0.key < $1.key }) {
            guard let id = UUID(uuidString: key), !scan.placeholders.contains(id) else { continue }
            let mine = local[id], theirs = remoteByID[link.remoteID]
            let remoteChanged = theirs.map { $0.updatedAt.timeIntervalSince1970 != link.remoteStamp } ?? false
            switch (mine, theirs) {
            case (nil, nil): steps.append(.unlink(id))
            case (nil, let theirs?):
                steps.append(remoteChanged ? .pull(theirs, localID: id, detail: nil, expectedHash: nil) : .deleteRemote(id, remote: theirs))
            case (let mine?, nil):
                if mine.hash != link.localHash { steps.append(.unlink(id)); steps.append(.create(mine)) } else { steps.append(.deleteLocal(mine)) }
            case (let mine?, let theirs?):
                let localChanged = mine.hash != link.localHash
                if localChanged, remoteChanged {
                    report.recipes.conflicts += 1
                    steps.append(mine.recipe.updatedAt > theirs.updatedAt ? .push(mine, remote: theirs) : .pull(theirs, localID: id, detail: nil, expectedHash: mine.hash))
                } else if localChanged {
                    steps.append(.push(mine, remote: theirs))
                } else if remoteChanged {
                    steps.append(.pull(theirs, localID: id, detail: nil, expectedHash: mine.hash))
                }
            }
        }

        let linkedRemote = Set(state.recipes.values.map(\.remoteID))
        var unlinkedLocal = local.filter { state.recipes[$0.key.uuidString] == nil }
        var claimed = Set(local.keys).union(scan.placeholders)
        for remote in summaries where !linkedRemote.contains(remote.id) {
            let detail = try await api.recipe(slug: remote.slug)
            if let id = MealieRecipeMapping.appID(in: detail), let mine = unlinkedLocal[id] {
                unlinkedLocal[id] = nil
                state.recipes[id.uuidString] = RecipeLink(remoteID: remote.id, slug: remote.slug, localHash: mine.hash, remoteStamp: remote.updatedAt.timeIntervalSince1970)
                let theirs = MealieRecipeMapping.recipe(from: detail, rating: ratings[remote.id], existing: mine.recipe, id: id)
                if MealieRecipeMapping.fingerprint(theirs) != MealieRecipeMapping.fingerprint(mine.recipe) {
                    report.recipes.conflicts += 1
                    steps.append(mine.recipe.updatedAt > remote.updatedAt ? .push(mine, remote: remote) : .pull(remote, localID: id, detail: detail, expectedHash: mine.hash))
                }
            } else {
                let id = [MealieRecipeMapping.appID(in: detail), UUID(uuidString: remote.id)].compactMap { $0 }.first { !claimed.contains($0) } ?? UUID()
                claimed.insert(id)
                steps.append(.pull(remote, localID: id, detail: detail, expectedHash: nil))
            }
        }
        for mine in unlinkedLocal.values.sorted(by: { $0.recipe.createdAt < $1.recipe.createdAt }) { steps.append(.create(mine)) }

        let deletions = steps.filter { if case .deleteRemote = $0 { true } else if case .deleteLocal = $0 { true } else { false } }.count
        if !options.allowMassDeletion, deletions > max(10, state.recipes.count / 2) { throw MealieError.tooManyDeletions(deletions) }

        let labels = LabelCache(api: api)
        var tokens = Dictionary(summaries.map { ($0.id, $0.imageToken) }, uniquingKeysWith: { $1 })
        for step in steps {
            do {
                try await perform(step, state: &state, user: user, ratings: ratings, labels: labels, tokens: &tokens, report: &report)
            } catch MealieError.server(let status, let message) {
                report.problems.append("\(title(of: step)): \(message) (\(status))")
            }
        }

        let current = try readLocalRecipes().recipes
        for (key, link) in state.recipes.sorted(by: { $0.key < $1.key }) {
            guard let id = UUID(uuidString: key), current[id] != nil else { continue }
            do {
                try await syncPhoto(id: id, link: link, remoteToken: tokens[link.remoteID] ?? nil, state: &state, report: &report)
            } catch MealieError.server(_, let message) {
                report.problems.append("Photo for \(current[id]?.recipe.title ?? key): \(message)")
            }
        }
    }

    private func title(of step: RecipeStep) -> String {
        switch step {
        case .create(let mine), .push(let mine, _), .deleteLocal(let mine): mine.recipe.title
        case .pull(let remote, _, _, _), .deleteRemote(_, let remote): remote.slug
        case .unlink: "Recipe"
        }
    }

    private func perform(
        _ step: RecipeStep, state: inout State, user: MealieUser, ratings: [String: MealieRating],
        labels: LabelCache, tokens: inout [String: String?], report: inout Report
    ) async throws {
        switch step {
        case .unlink(let id):
            state.recipes[id.uuidString] = nil
        case .create(let mine):
            let slug = try await api.createRecipe(name: mine.recipe.title)
            let detail = try await api.recipe(slug: slug)
            let current = ratings[detail.string("id") ?? ""]
            try await push(mine, to: detail, current: current, user: user, labels: labels, state: &state, tokens: &tokens)
            report.recipes.sent += 1
        case .push(let mine, let remote):
            let detail = try await api.recipe(slug: remote.slug)
            try await push(mine, to: detail, current: ratings[remote.id], user: user, labels: labels, state: &state, tokens: &tokens)
            report.recipes.sent += 1
        case .pull(let remote, let id, let known, let expected):
            let detail: MealieObject
            if let known { detail = known } else { detail = try await api.recipe(slug: remote.slug) }
            let existing = readLocalRecipe(id)
            guard existing?.hash == expected else {
                report.problems.append("\(existing?.recipe.title ?? remote.slug) changed while syncing; it will sync on the next pass.")
                return
            }
            let recipe = MealieRecipeMapping.recipe(from: detail, rating: ratings[remote.id], existing: existing?.recipe, id: id)
            let data = try RecipeCoding.makeEncoder().encode(recipe)
            try FileIO.write(data, to: library.recipes.fileURL(for: id))
            let old = state.recipes[id.uuidString]
            state.recipes[id.uuidString] = RecipeLink(
                remoteID: remote.id, slug: detail.string("slug") ?? remote.slug, localHash: ServerSync.sha256(data), remoteStamp: recipe.updatedAt.timeIntervalSince1970,
                imageHash: old?.remoteID == remote.id ? old?.imageHash : nil, imageToken: old?.remoteID == remote.id ? old?.imageToken : nil,
                imageMtime: old?.imageMtime, imageSize: old?.imageSize
            )
            report.recipes.received += 1
        case .deleteRemote(let id, let remote):
            try await api.deleteRecipe(slug: remote.slug)
            state.recipes[id.uuidString] = nil
            report.recipes.deletedInMealie += 1
        case .deleteLocal(let mine):
            guard readLocalRecipe(mine.recipe.id)?.hash == mine.hash else { return }
            try library.deleteRecipe(mine.recipe)
            state.recipes[mine.recipe.id.uuidString] = nil
            report.recipes.deletedHere += 1
        }
    }

    private func push(
        _ mine: LocalRecipe, to detail: MealieObject, current: MealieRating?, user: MealieUser,
        labels: LabelCache, state: inout State, tokens: inout [String: String?]
    ) async throws {
        let names = MealieRecipeMapping.labels(for: mine.recipe, remote: detail)
        let tags = try await labels.tags(named: names.tags)
        let categories = try await labels.categories(named: names.categories)
        let body = MealieRecipeMapping.body(for: mine.recipe, patching: detail, tags: tags, categories: categories)
        let slug = detail.string("slug") ?? ""
        let updated = try await api.updateRecipe(slug: slug, body)
        let finalSlug = updated.string("slug") ?? slug

        let wanted = mine.recipe.rating.map(Double.init)
        let currentRating = current?.rating.flatMap { $0 > 0 ? $0 : nil }
        if wanted != currentRating || mine.recipe.isFavorite != (current?.isFavorite ?? false) {
            try await api.setRating(userID: user.id, slug: finalSlug, rating: wanted, isFavorite: mine.recipe.isFavorite)
        }

        let final = try await api.recipe(slug: finalSlug)
        guard let remoteID = final.string("id") else { throw MealieError.notMealie }
        let old = state.recipes[mine.recipe.id.uuidString]
        let keepsPhoto = old?.remoteID == remoteID
        state.recipes[mine.recipe.id.uuidString] = RecipeLink(
            remoteID: remoteID, slug: final.string("slug") ?? finalSlug, localHash: mine.hash,
            remoteStamp: Self.stamp(of: final),
            imageHash: keepsPhoto ? old?.imageHash : nil, imageToken: keepsPhoto ? old?.imageToken : nil,
            imageMtime: keepsPhoto ? old?.imageMtime : nil, imageSize: keepsPhoto ? old?.imageSize : nil
        )
        tokens[remoteID] = .some(final.string("image"))
    }

    // MARK: - Photos

    private func syncPhoto(id: UUID, link: RecipeLink, remoteToken: String?, state: inout State, report: inout Report) async throws {
        var link = link
        let url = library.images.fileURL(for: id)
        let local = localPhoto(at: url, link: link)
        let localChanged = local?.hash != link.imageHash
        let remoteChanged = remoteToken != link.imageToken
        guard localChanged || remoteChanged else { return }

        if localChanged {
            let before = try await api.recipe(slug: link.slug)
            let unchanged = Self.stamp(of: before) == link.remoteStamp
            if let local {
                try await api.setRecipeImage(slug: link.slug, data: local.data)
                report.photos.sent += 1
            } else {
                try await api.deleteRecipeImage(slug: link.slug)
                report.photos.deletedInMealie += 1
            }
            if remoteChanged { report.photos.conflicts += 1 }
            let after = try await api.recipe(slug: link.slug)
            link.imageToken = after.string("image")
            if unchanged { link.remoteStamp = Self.stamp(of: after) }
            link.imageHash = local?.hash
            link.imageMtime = local?.mtime
            link.imageSize = local?.data.count
        } else if let remoteToken {
            guard let original = try await api.recipeImage(id: link.remoteID), let jpeg = RecipeImageProcessing.jpegData(from: original) else { return }
            try library.images.save(jpeg, for: id)
            link.imageToken = remoteToken
            link.imageHash = ServerSync.sha256(jpeg)
            link.imageMtime = Self.mtime(of: url)
            link.imageSize = jpeg.count
            report.photos.received += 1
        } else {
            try library.images.delete(for: id)
            link.imageToken = nil
            link.imageHash = nil
            link.imageMtime = nil
            link.imageSize = nil
            report.photos.deletedHere += 1
        }
        state.recipes[id.uuidString] = link
    }

    private struct LocalPhoto {
        var data: Data
        var hash: String
        var mtime: Double
    }

    private func localPhoto(at url: URL, link: RecipeLink) -> LocalPhoto? {
        guard FileManager.default.fileExists(atPath: url.path), let data = try? FileIO.read(url) else { return nil }
        let mtime = Self.mtime(of: url)
        if let hash = link.imageHash, link.imageMtime == mtime, link.imageSize == data.count { return LocalPhoto(data: data, hash: hash, mtime: mtime) }
        return LocalPhoto(data: data, hash: ServerSync.sha256(data), mtime: mtime)
    }

    // MARK: - Disk

    struct Scan {
        var recipes: [UUID: LocalRecipe] = [:]
        var placeholders: Set<UUID> = []
    }

    /// Files iCloud hasn't downloaded yet are reported as placeholders, not as missing.
    func readLocalRecipes() throws -> Scan {
        let directory = library.recipes.directory
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        var scan = Scan()
        for url in try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil) {
            if FileIO.startDownloadIfPlaceholder(url, in: directory) {
                let name = url.lastPathComponent.dropFirst().dropLast(".icloud".count)
                if let id = UUID(uuidString: String(name.dropLast(".json".count))) { scan.placeholders.insert(id) }
                continue
            }
            if url.pathExtension == "json", let mine = readRecipe(at: url) { scan.recipes[mine.recipe.id] = mine }
        }
        return scan
    }

    func readLocalRecipe(_ id: UUID) -> LocalRecipe? {
        readRecipe(at: library.recipes.fileURL(for: id))
    }

    private func readRecipe(at url: URL) -> LocalRecipe? {
        guard let data = try? FileIO.read(url), let recipe = try? RecipeCoding.makeDecoder().decode(Recipe.self, from: data) else { return nil }
        return LocalRecipe(recipe: recipe, hash: ServerSync.sha256(data))
    }

    static func stamp(of recipe: MealieObject) -> Double {
        (recipe.string("updatedAt").flatMap(MealieDate.parse) ?? .distantPast).timeIntervalSince1970
    }

    static func mtime(of url: URL) -> Double {
        ((try? url.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate ?? Date()).timeIntervalSince1970
    }

    private func loadState() -> State {
        let fresh = State(server: server.absoluteString)
        guard let data = try? Data(contentsOf: stateURL), let state = try? JSONDecoder().decode(State.self, from: data), state.server == fresh.server else { return fresh }
        return state
    }

    private func saveState(_ state: State) {
        try? FileManager.default.createDirectory(at: stateURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        if let data = try? JSONEncoder().encode(state) { try? data.write(to: stateURL, options: .atomic) }
    }
}

/// Mealie's tags and categories by name, created on first use.
final class LabelCache {
    private let api: any MealieAPI
    private var tagsByName: [String: MealieObject]?
    private var categoriesByName: [String: MealieObject]?

    init(api: any MealieAPI) {
        self.api = api
    }

    func tags(named names: [String]) async throws -> [MealieObject] {
        if tagsByName == nil { tagsByName = Self.index(try await api.tags()) }
        var result: [MealieObject] = []
        for name in names {
            if let existing = tagsByName?[name.lowercased()] {
                result.append(existing)
            } else {
                let created = try await api.createTag(name: name)
                tagsByName?[name.lowercased()] = created
                result.append(created)
            }
        }
        return result
    }

    func categories(named names: [String]) async throws -> [MealieObject] {
        if categoriesByName == nil { categoriesByName = Self.index(try await api.categories()) }
        return names.compactMap { categoriesByName?[$0.lowercased()] }
    }

    private static func index(_ objects: [MealieObject]) -> [String: MealieObject] {
        Dictionary(objects.compactMap { object in object.string("name").map { (CategoryTree.normalized($0).lowercased(), object) } }, uniquingKeysWith: { first, _ in first })
    }
}

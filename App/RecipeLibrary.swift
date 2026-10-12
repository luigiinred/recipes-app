import CoreGraphics
import CoreSpotlight
import Foundation
import RecipeKit

enum ImageChange {
    case unchanged
    case set(Data)
    case remove
}

struct StepImageChanges {
    var added: [UUID: Data] = [:]
    var removed: [UUID] = []
}

@MainActor
final class RecipeLibrary: ObservableObject {
    @Published private(set) var recipes: [Recipe] = []
    @Published private(set) var mealPlan: [MealPlanEntry] = []
    @Published private(set) var groceries: [GroceryItem] = []
    @Published private(set) var feeds: [Feed] = []
    @Published private(set) var imageStamps: [UUID: Date] = [:]
    @Published private(set) var stepImageStamps: [UUID: Date] = [:]
    @Published private(set) var isICloud = false
    @Published private(set) var remindersStatus = RemindersStatus.unavailable
    @Published private(set) var errorMessage: String?

    private var library: Library?
    private var reminders: RemindersSync?
    private var remindersChanged = false
    private static let remindersKey = "syncGroceriesWithReminders"
    private var thumbnails: [UUID: (stamp: Date, image: CGImage)] = [:]
    private var stepThumbnails: [UUID: (stamp: Date, image: CGImage)] = [:]

    init() {}

    init(
        recipes: [Recipe], mealPlan: [MealPlanEntry] = [], groceries: [GroceryItem] = [], feeds: [Feed] = [],
        images: [UUID: Data] = [:], stepImages: [UUID: Data] = [:], isICloud: Bool = true, remindersStatus: RemindersStatus = .unavailable
    ) {
        self.remindersStatus = remindersStatus
        self.recipes = recipes
        self.mealPlan = mealPlan
        self.groceries = groceries
        self.feeds = feeds
        self.isICloud = isICloud
        for (id, data) in images {
            guard let image = RecipeImageProcessing.thumbnail(from: data, maxPixelSize: Self.thumbnailSize) else { continue }
            thumbnails[id] = (.distantPast, image)
            imageStamps[id] = .distantPast
        }
        for (id, data) in stepImages {
            guard let image = RecipeImageProcessing.thumbnail(from: data, maxPixelSize: Self.thumbnailSize) else { continue }
            stepThumbnails[id] = (.distantPast, image)
            stepImageStamps[id] = .distantPast
        }
    }

    static let thumbnailSize = 1200

    var categoryTree: [CategoryNode] { CategoryTree.build(from: recipes.flatMap(\.tags)) }

    var tags: [String] {
        Array(Set(recipes.flatMap(\.tags))).sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
    }

    func recipe(id: UUID?) -> Recipe? {
        guard let id else { return nil }
        return recipes.first { $0.id == id }
    }

    func hasImage(_ id: UUID) -> Bool { imageStamps[id] != nil }

    func cachedThumbnail(for id: UUID) -> CGImage? {
        guard let cached = thumbnails[id], cached.stamp == imageStamps[id] else { return nil }
        return cached.image
    }

    func loadThumbnail(for id: UUID) async -> CGImage? {
        guard let library, let stamp = imageStamps[id] else { return cachedThumbnail(for: id) }
        if let cached = cachedThumbnail(for: id) { return cached }
        let image = await Task.detached {
            library.images.data(for: id).flatMap { RecipeImageProcessing.thumbnail(from: $0, maxPixelSize: Self.thumbnailSize) }
        }.value
        if let image { thumbnails[id] = (stamp, image) }
        return image
    }

    func cachedStepImage(for id: UUID) -> CGImage? {
        guard let cached = stepThumbnails[id], cached.stamp == stepImageStamps[id] else { return nil }
        return cached.image
    }

    func loadStepImage(for id: UUID) async -> CGImage? {
        guard let library, let stamp = stepImageStamps[id] else { return cachedStepImage(for: id) }
        if let cached = cachedStepImage(for: id) { return cached }
        let image = await Task.detached {
            library.stepImages.data(for: id).flatMap { RecipeImageProcessing.thumbnail(from: $0, maxPixelSize: Self.thumbnailSize) }
        }.value
        if let image { stepThumbnails[id] = (stamp, image) }
        return image
    }

    func run() async {
        let resolved = await Task.detached { RecipeLocation.resolveForApp() }.value
        library = resolved.library
        isICloud = resolved.isICloud
        let reminders = RemindersSync()
        self.reminders = reminders
        let watcher = Task { for await _ in reminders.changes { self.remindersChanged = true } }
        defer { watcher.cancel() }
        remindersStatus = remindersEnabled ? .needsAccess : .off
        while !Task.isCancelled {
            await reload()
            await syncReminders()
            try? await Task.sleep(for: .seconds(2))
        }
    }

    var remindersEnabled: Bool {
        UserDefaults.standard.register(defaults: [Self.remindersKey: true])
        return UserDefaults.standard.bool(forKey: Self.remindersKey)
    }

    func setRemindersEnabled(_ enabled: Bool) async {
        UserDefaults.standard.set(enabled, forKey: Self.remindersKey)
        remindersStatus = enabled ? .needsAccess : .off
        await syncReminders()
    }

    private func syncReminders() async {
        guard let reminders, let library, remindersEnabled else {
            if reminders != nil, remindersStatus != .off { remindersStatus = .off }
            return
        }
        guard await reminders.requestAccess() else {
            remindersStatus = reminders.isDenied ? .denied : .needsAccess
            return
        }
        remindersChanged = false
        do {
            let outcome = try await reminders.reconcile(local: groceries)
            if !outcome.save.isEmpty || !outcome.delete.isEmpty {
                let result = await Task.detached {
                    Result {
                        for item in outcome.save { try library.groceries.save(item) }
                        for item in outcome.delete { try library.groceries.delete(item) }
                    }
                }.value
                if case .failure(let error) = result { remindersStatus = .failed(error.localizedDescription); return }
                await reload()
            }
            remindersStatus = .synced(Date())
        } catch {
            remindersStatus = .failed(error.localizedDescription)
        }
    }

    func reload() async {
        guard let library else { return }
        let result = await Task.detached {
            Result { try (library.recipes.list(), library.mealPlan.list(), library.groceries.list(), library.feeds.list(), library.images.stamps(), library.stepImages.stamps()) }
        }.value
        switch result {
        case .success(let (recipes, plan, groceries, feeds, stamps, stepStamps)):
            if recipes != self.recipes {
                self.recipes = recipes
                if reminders != nil { Self.index(recipes) }
            }
            if plan != mealPlan { mealPlan = plan }
            if groceries != self.groceries { self.groceries = groceries }
            let sortedFeeds = feeds.sorted { $0.createdAt < $1.createdAt }
            if sortedFeeds != self.feeds { self.feeds = sortedFeeds }
            if stamps != imageStamps { imageStamps = stamps }
            if stepStamps != stepImageStamps { stepImageStamps = stepStamps }
            errorMessage = nil
        case .failure(let error):
            errorMessage = error.localizedDescription
        }
    }

    private static func index(_ recipes: [Recipe]) {
        #if !SHARE_EXTENSION
        let entities = recipes.map(RecipeEntity.init)
        Task.detached {
            try? await CSSearchableIndex.default().indexAppEntities(entities)
        }
        #endif
    }

    func save(_ recipe: Recipe, image: ImageChange = .unchanged, steps: StepImageChanges = StepImageChanges()) async {
        await perform { library in
            for (id, data) in steps.added { try library.stepImages.save(data, for: id) }
            try library.recipes.save(recipe)
            for id in steps.removed { try library.stepImages.delete(for: id) }
            switch image {
            case .unchanged: break
            case .set(let data): try library.images.save(data, for: recipe.id)
            case .remove: try library.images.delete(for: recipe.id)
            }
        }
    }

    func add(_ result: ImportResult) async -> Recipe? {
        guard let library else { return nil }
        let outcome = await Task.detached { Result { try library.add(result) } }.value
        await reload()
        switch outcome {
        case .success(let saved): return saved
        case .failure(let error):
            errorMessage = error.localizedDescription
            return nil
        }
    }

    func delete(_ recipe: Recipe) async {
        await perform { try $0.deleteRecipe(recipe) }
    }

    /// Fills in step timestamps from the video's captions; returns how many steps got one.
    func findTimestamps(for recipe: Recipe) async -> Int {
        guard let times = await YouTubeImporter.timestamps(for: recipe) else { return 0 }
        var changed = recipe
        changed.stepTimestamps = times
        await save(changed)
        return times.compactMap { $0 }.count
    }

    func setFavorite(_ recipe: Recipe, _ value: Bool) async {
        var changed = recipe
        changed.isFavorite = value
        await save(changed)
    }

    func setRating(_ recipe: Recipe, _ value: Int?) async {
        var changed = recipe
        changed.rating = value
        await save(changed)
    }

    func setQueued(_ recipe: Recipe, _ value: Bool) async {
        var changed = recipe
        changed.wantToCook = value
        changed.queuedAt = value ? Date() : nil
        await save(changed)
    }

    func add(_ feed: Feed) async {
        await perform { try $0.feeds.save(feed) }
    }

    func remove(_ feed: Feed) async {
        await perform { try $0.feeds.delete(feed) }
    }

    func plan(_ recipe: Recipe, on day: Date, meal: Meal) async {
        let entry = MealPlanEntry(recipeID: recipe.id, title: recipe.title, day: DayKey.string(from: day), meal: meal)
        var dequeued = recipe
        dequeued.wantToCook = false
        dequeued.queuedAt = nil
        let wasQueued = recipe.wantToCook
        await perform { library in
            try library.mealPlan.save(entry)
            if wasQueued { try library.recipes.save(dequeued) }
        }
    }

    func update(_ entry: MealPlanEntry) async {
        var entry = entry
        entry.updatedAt = Date()
        await perform { [entry] in try $0.mealPlan.save(entry) }
    }

    func remove(_ entry: MealPlanEntry) async {
        await perform { try $0.mealPlan.delete(entry) }
    }

    func removeEntry(id: UUID) async {
        guard let entry = mealPlan.first(where: { $0.id == id }) else { return }
        await remove(entry)
    }

    /// Handles a drag that ended on a planner slot: a recipe becomes a new meal, a planned meal moves.
    func drop(_ payload: PlannerPayload, on day: Date, meal: Meal) async {
        switch payload.kind {
        case .recipe:
            guard let recipe = recipe(id: payload.id) else { return }
            await plan(recipe, on: day, meal: meal)
        case .entry:
            guard var entry = mealPlan.first(where: { $0.id == payload.id }) else { return }
            entry.day = DayKey.string(from: day)
            entry.meal = meal
            await update(entry)
        }
    }

    func addGroceries(_ items: [GroceryItem]) async {
        let waiting = groceries.filter { !$0.isChecked }
        let fresh = items.filter { item in
            !waiting.contains { $0.name.lowercased() == item.name.lowercased() && $0.quantity == item.quantity }
        }
        await perform { library in for item in fresh { try library.groceries.save(item) } }
    }

    func setChecked(_ item: GroceryItem, _ checked: Bool) async {
        var item = item
        item.isChecked = checked
        item.updatedAt = Date()
        await perform { [item] in try $0.groceries.save(item) }
    }

    func remove(_ item: GroceryItem) async {
        await perform { try $0.groceries.delete(item) }
    }

    func clearCompleted() async {
        let done = groceries.filter(\.isChecked)
        await perform { library in for item in done { try library.groceries.delete(item) } }
    }

    /// Saves fixed sample content, replacing earlier copies of it.
    func addSamples(
        recipes: [Recipe], images: [UUID: Data], stepImages: [UUID: Data], plan: [MealPlanEntry], groceries: [GroceryItem]
    ) async {
        await perform { library in
            for recipe in recipes { try library.recipes.save(recipe) }
            for (id, data) in images { try library.images.save(data, for: id) }
            for (id, data) in stepImages { try library.stepImages.save(data, for: id) }
            for entry in plan { try library.mealPlan.save(entry) }
            for item in groceries { try library.groceries.save(item) }
        }
    }

    func exportJSON() async throws -> Data {
        guard let library else { throw RecipeError.invalid("The library isn't ready yet.") }
        return try await Task.detached { try library.export().jsonData() }.value
    }

    private func perform(_ work: @escaping @Sendable (Library) throws -> some Any) async {
        guard let library else { return }
        let result = await Task.detached { Result { _ = try work(library) } }.value
        if case .failure(let error) = result { errorMessage = error.localizedDescription }
        await reload()
    }
}

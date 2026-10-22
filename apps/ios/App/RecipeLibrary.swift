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
    @Published private(set) var isLoaded = false
    @Published private(set) var remindersStatus = RemindersStatus.unavailable
    @Published private(set) var errorMessage: String?

    private var library: Library?
    private var reminders: RemindersSync?
    private var remindersChanged = false
    #if os(iOS) && !SHARE_EXTENSION
    private let widgets = WidgetSync()
    #endif
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
        isLoaded = true
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
            await publishWidgets()
            try? await Task.sleep(for: .seconds(2))
        }
    }

    private func publishWidgets() async {
        #if os(iOS) && !SHARE_EXTENSION
        guard let library, isLoaded else { return }
        await widgets.publish(recipes: recipes, mealPlan: mealPlan, groceries: groceries, imageIDs: Set(imageStamps.keys), library: library)
        #endif
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
            if !isLoaded { isLoaded = true }
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

    /// Files a recipe under a category unless it is already in it or one of its subcategories.
    func addTag(_ recipeID: UUID, to category: String) async {
        guard var changed = recipe(id: recipeID) else { return }
        let tag = CategoryTree.normalized(category)
        guard !tag.isEmpty, !changed.tags.contains(where: { CategoryTree.tag($0, isIn: tag) }) else { return }
        changed.tags.append(tag)
        await save(changed)
    }

    /// Takes a recipe out of a category by dropping its tags in that category and beneath it.
    func removeTags(_ recipe: Recipe, in category: String) async {
        var changed = recipe
        changed.tags.removeAll { CategoryTree.tag($0, isIn: category) }
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

    /// Logs a time the recipe was cooked. Cooking it takes it out of Up Next.
    func logMade(_ recipe: Recipe, on date: Date = Date(), note: String = "") async {
        var changed = self.recipe(id: recipe.id) ?? recipe
        changed.timeline.append(TimelineEvent(date: date, note: note.trimmingCharacters(in: .whitespacesAndNewlines)))
        changed.wantToCook = false
        changed.queuedAt = nil
        await save(changed)
    }

    func removeEvent(_ event: TimelineEvent, from recipe: Recipe) async {
        var changed = self.recipe(id: recipe.id) ?? recipe
        changed.timeline.removeAll { $0.id == event.id }
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

    /// Saves the idea as a recipe, unless one with that title exists, and puts it on the calendar.
    func plan(idea title: String, on day: Date, meal: Meal) async {
        let existing = recipes.first { $0.title.localizedCaseInsensitiveCompare(title) == .orderedSame }
        let idea = existing ?? Recipe(title: title)
        let entry = MealPlanEntry(recipeID: idea.id, title: idea.title, day: DayKey.string(from: day), meal: meal)
        await perform { library in
            if existing == nil { try library.recipes.save(idea) }
            try library.mealPlan.save(entry)
        }
    }

    func addIdea(title: String, notes: String) async -> Recipe {
        let idea = Recipe(title: title, notes: notes)
        await save(idea)
        return idea
    }

    func removeEntry(id: UUID) async {
        guard let entry = mealPlan.first(where: { $0.id == id }) else { return }
        await remove(entry)
    }

    /// Puts a smart plan on the calendar; recipes that were in Up Next leave the queue.
    func plan(_ suggestions: [PlanSuggestion]) async {
        let entries = suggestions.compactMap { suggestion -> MealPlanEntry? in
            guard let recipe = recipe(id: suggestion.recipeID) else { return nil }
            return MealPlanEntry(recipeID: recipe.id, title: recipe.title, day: suggestion.day, meal: suggestion.meal)
        }
        let used = Set(suggestions.map(\.recipeID))
        let dequeued = recipes.filter { used.contains($0.id) && $0.wantToCook }.map { recipe -> Recipe in
            var changed = recipe
            changed.wantToCook = false
            changed.queuedAt = nil
            return changed
        }
        await perform { library in
            for entry in entries { try library.mealPlan.save(entry) }
            for recipe in dequeued { try library.recipes.save(recipe) }
        }
    }

    /// Reorders Up Next after a drag by renumbering the queue times of the recipes that moved.
    func moveQueued(from source: IndexSet, to destination: Int) async {
        let queue = RecipeCollection.wantToCook.filter(recipes)
        guard queue.count > 1 else { return }
        var ordered = queue
        ordered.move(fromOffsets: source, toOffset: destination)
        let base = queue.map { $0.queuedAt ?? $0.createdAt }.min() ?? Date()
        let changed = ordered.enumerated().compactMap { index, recipe -> Recipe? in
            let time = base.addingTimeInterval(Double(index))
            guard recipe.queuedAt != time else { return nil }
            var changed = recipe
            changed.queuedAt = time
            return changed
        }
        await perform { library in for recipe in changed { try library.recipes.save(recipe) } }
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

    /// Re-saves every recipe whose ingredients, steps or tags aren't in the standard form yet; returns how many changed.
    func tidyRecipes() async -> Int {
        let changed = recipes.filter { $0.standardized() != $0 }
        guard !changed.isEmpty else { return 0 }
        await perform { library in for recipe in changed { try library.recipes.save(recipe) } }
        return changed.count
    }

    func clearAllGroceries() async {
        let all = groceries
        await perform { library in for item in all { try library.groceries.delete(item) } }
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

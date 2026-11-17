import CoreGraphics
import CoreSpotlight
import Foundation
import RecipeKit

enum ImageChange {
    case unchanged
    case set(Data)
    case remove
}

struct LoadProgress: Equatable {
    var done: Int
    var total: Int
}

struct StepImageChanges {
    var added: [UUID: Data] = [:]
    var removed: [UUID] = []
}

@MainActor
final class RecipeLibrary: ObservableObject {
    @Published private(set) var recipes: [Recipe] = []
    @Published private(set) var mealPlan: [MealPlanEntry] = []
    @Published private(set) var upNextNotes: [UpNextNote] = []
    @Published private(set) var groceries: [GroceryItem] = []
    @Published private(set) var feeds: [Feed] = []
    @Published private(set) var categoryOrder: [String] = []
    @Published private(set) var imageStamps: [UUID: Date] = [:]
    @Published private(set) var stepImageStamps: [UUID: Date] = [:]
    @Published private(set) var isICloud = false
    @Published private(set) var isLoaded = false
    @Published private(set) var loadProgress: LoadProgress?
    @Published private(set) var remindersStatus = RemindersStatus.unavailable
    @Published private(set) var errorMessage: String?

    private var library: Library?
    private var remoteImage: (@Sendable (UUID) async -> Data?)?
    private var reminders: RemindersSync?
    private var remindersChanged = false
    #if os(iOS) && !SHARE_EXTENSION
    private let widgets = WidgetSync()
    #endif
    private static let remindersKey = "syncGroceriesWithReminders"
    private var thumbnails: [UUID: (stamp: Date, image: CGImage)] = [:]
    private var stepThumbnails: [UUID: (stamp: Date, image: CGImage)] = [:]

    init() {}

    /// A library on disk without the app's iCloud lookup or Reminders, for tests.
    init(opening library: Library) {
        self.library = library
    }

    init(
        recipes: [Recipe], mealPlan: [MealPlanEntry] = [], upNextNotes: [UpNextNote] = [], groceries: [GroceryItem] = [], feeds: [Feed] = [], categoryOrder: [String] = [],
        images: [UUID: Data] = [:], stepImages: [UUID: Data] = [:], isICloud: Bool = true, remindersStatus: RemindersStatus = .unavailable
    ) {
        self.remindersStatus = remindersStatus
        self.recipes = recipes
        self.mealPlan = mealPlan
        self.upNextNotes = upNextNotes
        self.groceries = groceries
        self.feeds = feeds
        self.categoryOrder = categoryOrder
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

    /// Someone else's recipes, held in memory with no library behind them, so every change is a no-op. Photos are fetched as they're shown.
    init(browsing remoteImage: @escaping @Sendable (UUID) async -> Data?) {
        self.remoteImage = remoteImage
    }

    func browse(_ recipes: [Recipe], imageIDs: Set<UUID>) {
        guard library == nil else { return }
        self.recipes = recipes
        imageStamps = Dictionary(uniqueKeysWithValues: imageIDs.map { ($0, .distantPast) })
        isLoaded = true
    }

    func browse(_ recipe: Recipe) {
        guard library == nil, let index = recipes.firstIndex(where: { $0.id == recipe.id }) else { return }
        recipes[index] = recipe
    }

    static let thumbnailSize = 1200

    var categoryTree: [CategoryNode] { CategoryTree.build(from: recipes.flatMap(\.tags), order: categoryOrder) }

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
        if let cached = cachedThumbnail(for: id) { return cached }
        guard let stamp = imageStamps[id] else { return nil }
        let image: CGImage?
        if let library {
            image = await Task.detached {
                library.images.data(for: id).flatMap { RecipeImageProcessing.thumbnail(from: $0, maxPixelSize: Self.thumbnailSize) }
            }.value
        } else if let remoteImage, let data = await remoteImage(id) {
            image = await Task.detached { RecipeImageProcessing.thumbnail(from: data, maxPixelSize: Self.thumbnailSize) }.value
        } else {
            return nil
        }
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
        // Finding the iCloud folder can take a while at launch, so last launch's folder shows its recipes in the meantime.
        if let remembered = RecipeLocation.rememberedForApp() {
            library = remembered.library
            isICloud = remembered.isICloud
            await reload()
        }
        let resolved = await Task.detached { RecipeLocation.resolveForApp() }.value
        RecipeLocation.remember(resolved)
        if library?.root.standardizedFileURL != resolved.root.standardizedFileURL {
            library = resolved.library
            isICloud = resolved.isICloud
        }
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
        let isFirstLoad = !isLoaded
        let report: @Sendable (Int, Int) -> Void = { [weak self] done, total in
            guard isFirstLoad, let self else { return }
            Task { await self.updateLoadProgress(LoadProgress(done: done, total: total)) }
        }
        let found: @Sendable ([Recipe]) -> Void = { [weak self] recipes in
            guard isFirstLoad, let self else { return }
            Task { await self.showFirstRecipes(recipes) }
        }
        let result = await Task.detached {
            Result { try (library.recipes.list(progress: report, found: found, coordinated: !isFirstLoad), library.mealPlan.list(), library.upNextNotes.list(), library.groceries.list(), library.feeds.list(), library.images.stamps(), library.stepImages.stamps(), library.categoryOrder.load()) }
        }.value
        switch result {
        case .success(let (recipes, plan, notes, groceries, feeds, stamps, stepStamps, order)):
            if recipes != self.recipes {
                self.recipes = recipes
                if reminders != nil { Self.index(recipes) }
            }
            if plan != mealPlan { mealPlan = plan }
            if notes != upNextNotes { upNextNotes = notes }
            if groceries != self.groceries { self.groceries = groceries }
            let sortedFeeds = feeds.sorted { $0.createdAt < $1.createdAt }
            if sortedFeeds != self.feeds { self.feeds = sortedFeeds }
            if order != categoryOrder { categoryOrder = order }
            if stamps != imageStamps { imageStamps = stamps }
            if stepStamps != stepImageStamps { stepImageStamps = stepStamps }
            if !isLoaded { isLoaded = true }
            loadProgress = nil
            errorMessage = nil
        case .failure(let error):
            errorMessage = error.localizedDescription
        }
    }

    private func showFirstRecipes(_ found: [Recipe]) {
        guard !isLoaded, found.count > recipes.count else { return }
        recipes = found
    }

    private func updateLoadProgress(_ progress: LoadProgress) {
        guard !isLoaded, progress.done >= loadProgress?.done ?? 0 else { return }
        loadProgress = progress
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

    /// Moves a category, with everything beneath it, under `parent` (or to the top level) ahead of its sibling `before`.
    func moveCategory(_ path: String, toParent parent: String?, before sibling: String?) async {
        guard CategoryTree.canMove(path, toParent: parent) else { return }
        let destination = CategoryTree.destination(moving: path, toParent: parent)
        let order = CategoryTree.moved(path, toParent: parent, before: sibling, tags: recipes.flatMap(\.tags), order: categoryOrder).order
        let changed = recipes.compactMap { recipe -> Recipe? in
            var seen = Set<String>()
            let tags = recipe.tags.map { CategoryTree.rename($0, from: path, to: destination) }.filter { seen.insert($0.lowercased()).inserted }
            guard tags != recipe.tags else { return nil }
            var moved = recipe
            moved.tags = tags
            return moved
        }
        await perform { library in
            for recipe in changed { try library.recipes.save(recipe) }
            try library.categoryOrder.save(order)
        }
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
        show(recipes: [changed])
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

    func plan(_ recipe: Recipe, on day: Date, meal: Meal, before target: MealPlanEntry? = nil) async {
        let entry = MealPlanEntry(recipeID: recipe.id, title: recipe.title, day: DayKey.string(from: day), meal: meal)
        let placed = placing(entry, on: entry.day, before: target)
        var dequeued = recipe
        dequeued.wantToCook = false
        dequeued.queuedAt = nil
        let wasQueued = recipe.wantToCook
        show(recipes: wasQueued ? [dequeued] : [], entries: placed)
        await perform { library in
            for entry in placed { try library.mealPlan.save(entry) }
            if wasQueued { try library.recipes.save(dequeued) }
        }
    }

    /// Moves a meal to `day`, just before `target` or after the rest of its kind, renumbering the day so the order sticks.
    func place(_ entry: MealPlanEntry, on day: String, before target: MealPlanEntry?) async {
        guard target?.id != entry.id else { return }
        let placed = placing(entry, on: day, before: target)
        show(entries: placed)
        await perform { library in for entry in placed { try library.mealPlan.save(entry) } }
    }

    /// `entry` set on `day` before `target`, taking its kind of meal, plus that day's other meals whose numbers changed.
    private func placing(_ entry: MealPlanEntry, on day: String, before target: MealPlanEntry?) -> [MealPlanEntry] {
        var moved = entry
        moved.day = day
        if let target { moved.meal = target.meal }
        var ordered = mealPlan.filter { $0.day == day && $0.id != entry.id }.sorted(by: MealPlanEntry.dayOrder)
        let index = target.flatMap { target in ordered.firstIndex { $0.id == target.id } }
            ?? ordered.lastIndex { $0.meal.order <= moved.meal.order }.map { $0 + 1 } ?? 0
        ordered.insert(moved, at: index)
        var changed: [MealPlanEntry] = []
        for (number, var item) in ordered.enumerated() {
            let position = Double(number)
            guard item.id == entry.id || item.position != position else { continue }
            item.position = position
            item.updatedAt = Date()
            changed.append(item)
        }
        return changed
    }

    func update(_ entry: MealPlanEntry) async {
        var entry = entry
        entry.updatedAt = Date()
        show(entries: [entry])
        await perform { [entry] in try $0.mealPlan.save(entry) }
    }

    func remove(_ entry: MealPlanEntry) async {
        show(removingEntries: [entry.id])
        await perform { try $0.mealPlan.delete(entry) }
    }

    func addIdea(title: String, notes: String, image: Data? = nil) async -> Recipe {
        let idea = Recipe(title: title, notes: notes)
        await save(idea, image: image.map(ImageChange.set) ?? .unchanged)
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

    var upNext: [UpNextItem] { UpNextItem.queue(recipes: recipes, notes: upNextNotes) }

    /// Reorders Up Next after a drag by renumbering the queue times of the recipes and notes that moved.
    func moveQueued(from source: IndexSet, to destination: Int) async {
        let queue = upNext
        guard queue.count > 1 else { return }
        var ordered = queue
        ordered.move(fromOffsets: source, toOffset: destination)
        let base = queue.map(\.queuedAt).min() ?? Date()
        var recipes: [Recipe] = []
        var notes: [UpNextNote] = []
        for (index, item) in ordered.enumerated() {
            let time = base.addingTimeInterval(Double(index))
            guard item.queuedAt != time else { continue }
            switch item {
            case .recipe(var recipe): recipe.queuedAt = time; recipes.append(recipe)
            case .note(var note): note.queuedAt = time; notes.append(note)
            }
        }
        show(recipes: recipes, notes: notes)
        await perform { library in
            for recipe in recipes { try library.recipes.save(recipe) }
            for note in notes { try library.upNextNotes.save(note) }
        }
    }

    func moveQueued(_ id: UUID, to index: Int) async {
        guard let from = upNext.firstIndex(where: { $0.id == id }) else { return }
        await moveQueued(from: IndexSet(integer: from), to: index)
    }

    /// Takes a meal off the calendar and puts its recipe, or its words, back at the end of Up Next.
    func unplan(_ entry: MealPlanEntry) async {
        if let recipe = recipe(id: entry.recipeID) {
            var queued = recipe
            queued.wantToCook = true
            queued.queuedAt = Date()
            show(recipes: [queued], removingEntries: [entry.id])
            await perform { [queued] library in
                try library.mealPlan.delete(entry)
                try library.recipes.save(queued)
            }
        } else {
            let isQueued = upNext.contains { $0.title.localizedCaseInsensitiveCompare(entry.title) == .orderedSame }
            let note = UpNextNote(title: entry.title)
            show(removingEntries: [entry.id], notes: isQueued ? [] : [note])
            await perform { library in
                try library.mealPlan.delete(entry)
                if !isQueued { try library.upNextNotes.save(note) }
            }
        }
    }

    /// Puts typed words in Up Next, unless they're already there.
    func queue(text: String) async {
        let title = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty, !upNext.contains(where: { $0.title.localizedCaseInsensitiveCompare(title) == .orderedSame }) else { return }
        let note = UpNextNote(title: title)
        show(notes: [note])
        await perform { try $0.upNextNotes.save(note) }
    }

    /// Queues a recipe in a note's place in Up Next.
    func use(_ recipe: Recipe, for note: UpNextNote) async {
        var queued = recipe
        queued.wantToCook = true
        queued.queuedAt = note.queuedAt
        show(recipes: [queued], removingNotes: [note.id])
        await perform { [queued] library in
            try library.recipes.save(queued)
            try library.upNextNotes.delete(note)
        }
    }

    func remove(_ note: UpNextNote) async {
        show(removingNotes: [note.id])
        await perform { try $0.upNextNotes.delete(note) }
    }

    /// Puts typed words on the calendar as they are, without making a recipe of them.
    func plan(text: String, on day: Date, meal: Meal) async {
        let title = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return }
        let entry = MealPlanEntry(title: title, day: DayKey.string(from: day), meal: meal)
        let placed = placing(entry, on: entry.day, before: nil)
        show(entries: placed)
        await perform { library in for entry in placed { try library.mealPlan.save(entry) } }
    }

    /// Plans a dish from the web by its name at once, then imports its recipe and links the meal to it.
    func plan(importing url: URL, title: String, on day: Date, meal: Meal, before target: MealPlanEntry? = nil) async {
        let entry = MealPlanEntry(title: title, day: DayKey.string(from: day), meal: meal)
        let placed = placing(entry, on: entry.day, before: target)
        show(entries: placed)
        await perform { library in for entry in placed { try library.mealPlan.save(entry) } }
        guard let recipe = await importRecipe(from: url), var planned = mealPlan.first(where: { $0.id == entry.id }) else { return }
        planned.recipeID = recipe.id
        planned.title = recipe.title
        await update(planned)
    }

    /// Puts a dish from the web in Up Next by its name at once, then imports its recipe into the same place.
    func queue(importing url: URL, title: String, at index: Int?) async {
        let note = UpNextNote(title: title)
        show(notes: [note])
        await perform { try $0.upNextNotes.save(note) }
        if let index { await moveQueued(note.id, to: index) }
        guard let recipe = await importRecipe(from: url), let placed = upNextNotes.first(where: { $0.id == note.id }) else { return }
        await use(recipe, for: placed)
    }

    func importRecipe(from url: URL) async -> Recipe? {
        guard let result = try? await RecipeImporter.importResult(from: url) else { return nil }
        return await add(result)
    }

    /// Planning a note takes it out of Up Next, as planning a recipe does.
    func plan(_ note: UpNextNote, on day: Date, meal: Meal, before target: MealPlanEntry? = nil) async {
        let entry = MealPlanEntry(title: note.title, day: DayKey.string(from: day), meal: meal)
        let placed = placing(entry, on: entry.day, before: target)
        show(entries: placed, removingNotes: [note.id])
        await perform { library in
            for entry in placed { try library.mealPlan.save(entry) }
            try library.upNextNotes.delete(note)
        }
    }

    /// Turns a note into an idea that keeps its place in Up Next, or queues the recipe already named that.
    @discardableResult
    func makeIdea(from note: UpNextNote) async -> Recipe {
        var idea = existingRecipe(titled: note.title) ?? Recipe(title: note.title)
        idea.wantToCook = true
        idea.queuedAt = note.queuedAt
        await perform { [idea] library in
            try library.recipes.save(idea)
            try library.upNextNotes.delete(note)
        }
        return idea
    }

    /// Links a typed meal to an idea of the same name, saving the idea if there isn't one.
    @discardableResult
    func makeIdea(from entry: MealPlanEntry) async -> Recipe {
        let existing = existingRecipe(titled: entry.title)
        let idea = existing ?? Recipe(title: entry.title)
        var linked = entry
        linked.recipeID = idea.id
        linked.updatedAt = Date()
        await perform { [linked] library in
            if existing == nil { try library.recipes.save(idea) }
            try library.mealPlan.save(linked)
        }
        return idea
    }

    private func existingRecipe(titled title: String) -> Recipe? {
        recipes.first { $0.title.localizedCaseInsensitiveCompare(title) == .orderedSame }
    }

    func addGroceries(_ items: [GroceryItem]) async {
        let waiting = groceries.filter { !$0.isChecked }
        let fresh = items.filter { item in
            !waiting.contains { $0.name.lowercased() == item.name.lowercased() && $0.quantity == item.quantity }
        }
        show(groceries: fresh)
        await perform { library in for item in fresh { try library.groceries.save(item) } }
    }

    func setChecked(_ item: GroceryItem, _ checked: Bool) async {
        var item = item
        item.isChecked = checked
        item.updatedAt = Date()
        show(groceries: [item])
        await perform { [item] in try $0.groceries.save(item) }
    }

    func remove(_ item: GroceryItem) async {
        show(removingGroceries: [item.id])
        await perform { try $0.groceries.delete(item) }
    }

    func clearCompleted() async {
        let done = groceries.filter(\.isChecked)
        show(removingGroceries: Set(done.map(\.id)))
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
        show(removingGroceries: Set(all.map(\.id)))
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

    /// Puts a change on screen before it's written, so a drop lands at once; the reload after the write confirms it.
    private func show(recipes changed: [Recipe] = [], entries: [MealPlanEntry] = [], removingEntries: Set<UUID> = [],
                      notes: [UpNextNote] = [], removingNotes: Set<UUID> = [],
                      groceries changedGroceries: [GroceryItem] = [], removingGroceries: Set<UUID> = []) {
        guard library != nil else { return }
        if !changed.isEmpty { recipes.upsert(changed) }
        if !removingEntries.isEmpty { mealPlan.removeAll { removingEntries.contains($0.id) } }
        if !entries.isEmpty { mealPlan.upsert(entries) }
        if !removingNotes.isEmpty { upNextNotes.removeAll { removingNotes.contains($0.id) } }
        if !notes.isEmpty { upNextNotes.upsert(notes) }
        if !removingGroceries.isEmpty { groceries.removeAll { removingGroceries.contains($0.id) } }
        if !changedGroceries.isEmpty { groceries.upsert(changedGroceries) }
    }

    private func perform(_ work: @escaping @Sendable (Library) throws -> some Any) async {
        guard let library else { return }
        let result = await Task.detached { Result { _ = try work(library) } }.value
        if case .failure(let error) = result { errorMessage = error.localizedDescription }
        await reload()
    }
}

private extension Array where Element: Identifiable {
    mutating func upsert(_ items: [Element]) {
        for item in items {
            if let index = firstIndex(where: { $0.id == item.id }) { self[index] = item } else { append(item) }
        }
    }
}

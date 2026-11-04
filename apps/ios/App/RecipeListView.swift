import RecipeKit
import PhotosUI
import SwiftUI
import UniformTypeIdentifiers

struct ScanDraft: Identifiable {
    let id = UUID()
    let recipe: Recipe
    var text: String?
    var textTitle = "Scanned text"
    var notice: String?
    var imageData: Data?
    var stepImages: [Data?] = []
}

enum RecipeListStyle: String, CaseIterable {
    case cards, list

    var title: String { self == .cards ? "Photo Cards" : "Compact List" }
    var symbol: String { self == .cards ? "rectangle.grid.1x2" : "list.bullet" }
}

struct RecipeListView: View {
    @EnvironmentObject private var library: RecipeLibrary
    @Binding var collection: RecipeCollection
    @Binding var selection: Recipe.ID?
    var styleOverride: RecipeListStyle?

    @AppStorage(AppSettings.Key.listStyle) private var storedStyle = RecipeListStyle.list
    #if os(iOS)
    @Environment(\.horizontalSizeClass) private var sizeClass
    #endif
    @State private var search = ""
    @State private var editing: Recipe?
    @State private var scanning = false

    private var style: RecipeListStyle { styleOverride ?? storedStyle }

    private var browsedCategory: String? {
        if case .category(let path) = collection { path } else { nil }
    }

    private var usesGrid: Bool {
        guard styleOverride != .list else { return false }
        #if os(iOS)
        return sizeClass == .regular
        #else
        return true
        #endif
    }

    var body: some View {
        content
            .macSearchable(text: $search, prompt: "Search My Recipes")
            .navigationTitle(collection.title)
            .recipeActions(
                selection: $selection,
                listStyle: usesGrid ? nil : Binding(get: { style }, set: { storedStyle = $0 }),
                findRecipes: browsedCategory != nil && !library.recipes.isEmpty ? FindRecipesAction(title: collection.title) { scanning = true } : nil
            )
            .sheet(item: $editing) { recipe in
                RecipeEditorView(recipe: recipe) { saved, image, steps in Task { await library.save(saved, image: image, steps: steps) } }
            }
            .sheet(isPresented: $scanning) {
                if let browsedCategory {
                    CategoryScanSheet(category: browsedCategory, candidates: RecipeTags.recipes(fitting: browsedCategory, among: library.recipes))
                }
            }
    }

    @ViewBuilder
    private var content: some View {
        if usesGrid { recipeGrid } else { recipeList }
    }

    /// A category on iPhone and iPad is a folder: its subcategories, then the recipes filed directly in it.
    private var items: [Recipe] {
        #if os(iOS)
        if case .category(let path) = collection {
            return library.recipes.filter { recipe in
                recipe.tags.contains { CategoryTree.components($0).count == CategoryTree.components(path).count && CategoryTree.tag($0, isIn: path) }
            }.filter { $0.matches(search) }
        }
        #endif
        return collection.filter(library.recipes).filter { $0.matches(search) }
    }

    #if os(iOS)
    private var subcategories: [CategoryNode] {
        guard case .category(let path) = collection, search.isEmpty else { return [] }
        return CategoryTree.node(at: path, in: library.categoryTree)?.children ?? []
    }
    #endif

    private var hasSubcategories: Bool {
        #if os(iOS)
        !subcategories.isEmpty
        #else
        false
        #endif
    }

    private var recipeList: some View {
        let items = items
        return List(selection: $selection) {
            #if os(iOS)
            if !subcategories.isEmpty {
                Section("Categories") {
                    ForEach(subcategories) { CategoryRow(node: $0) }
                }
            }
            #endif
            Section {
                ForEach(items) { recipe in
                    Group {
                        switch style {
                        case .cards: RecipeCard(recipe: recipe)
                        case .list: RecipeRow(recipe: recipe)
                        }
                    }
                    .tag(recipe.id)
                    .themedRow()
                    .listRowSeparator(style == .cards ? .hidden : .automatic)
                    .listRowSeparator(recipe.id == items.first?.id ? .hidden : .automatic, edges: .top)
                    .listRowInsets(style == .cards ? EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16) : nil)
                    .recipeSwipeActions(for: recipe, removingTagFrom: browsedCategory)
                    .draggable(RecipeDragItem(id: recipe.id))
                    .contextMenu { recipeMenu(recipe) }
                }
            } header: {
                #if os(iOS)
                if !subcategories.isEmpty, !items.isEmpty { Text("Recipes") }
                #endif
            }
            .listSectionSeparator(.hidden, edges: .top)
        }
        .listStyle(.plain)
        .themedCanvas()
        .animation(.snappy, value: items.map(\.id))
        .overlay { emptyState }
    }

    @ViewBuilder
    private var emptyState: some View {
        if library.recipes.isEmpty {
            EmptyLibraryView()
        } else if items.isEmpty, search.isEmpty {
            #if os(iOS)
            if subcategories.isEmpty { MascotEmptyState(scene: .idle, title: collection.title, message: "No recipes here yet.") }
            #else
            MascotEmptyState(scene: .idle, title: collection.title, message: "No recipes here yet.")
            #endif
        } else if items.isEmpty {
            ContentUnavailableView.search(text: search)
        }
    }

    @ViewBuilder
    private func recipeMenu(_ recipe: Recipe) -> some View {
        RecipeQuickActions(recipe: recipe)
        Button("Edit", systemImage: "pencil") { editing = recipe }
        if let browsedCategory {
            Button("Remove Tag", systemImage: "tag.slash") { Task { await library.removeTags(recipe, in: browsedCategory) } }
        }
    }

    /// Wide screens: subcategories and photo cards in a grid. Opening a recipe takes over the screen.
    private var recipeGrid: some View {
        let items = items
        return ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                #if os(iOS)
                if !subcategories.isEmpty {
                    GridSection(title: "Categories", minimum: 240, spacing: 16) {
                        ForEach(subcategories) { FolderTile(collection: .category($0.path), symbol: $0.children.isEmpty ? "tag" : "folder") }
                    }
                }
                #endif
                if !items.isEmpty {
                    GridSection(title: hasSubcategories ? "Recipes" : nil, minimum: 260, spacing: 20) {
                        ForEach(items) { recipe in
                            Button { selection = recipe.id } label: { RecipeCard(recipe: recipe) }
                                .buttonStyle(.plain)
                                .draggable(RecipeDragItem(id: recipe.id))
                                .contextMenu { recipeMenu(recipe) }
                        }
                    }
                }
            }
            .padding(24)
        }
        .themedCanvas()
        .animation(.snappy, value: items.map(\.id))
        .overlay { emptyState }
    }
}

/// Shown in place of the recipes: a spinner until the first load finishes, then the empty library.
struct EmptyLibraryView: View {
    @EnvironmentObject private var library: RecipeLibrary

    var body: some View {
        if library.isLoaded {
            MascotEmptyState(scene: .wave, title: "No recipes yet",
                             message: "Tap + to add one, share one from Safari, or use the recipes command-line tool.")
        } else if let message = library.errorMessage {
            ContentUnavailableView("Couldn't load recipes", systemImage: "exclamationmark.triangle", description: Text(message))
        } else {
            VStack(spacing: 4) {
                MascotLoader(height: 120)
                Text("Syncing recipes…").appFont(.headline)
                if let detail = progressDetail {
                    Text(detail)
                        .appFont(.subheadline)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                        .contentTransition(.numericText())
                        .animation(.snappy, value: library.loadProgress)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .accessibilityElement(children: .combine)
        }
    }

    private var progressDetail: String? {
        guard let progress = library.loadProgress, progress.total > 0 else { return nil }
        let noun = progress.total == 1 ? "recipe" : "recipes"
        if progress.done == 0 { return "Found \(progress.total) \(noun)" }
        return "\(progress.done) of \(progress.total) \(noun) downloaded"
    }
}

/// Recipes elsewhere in the library that look like they belong in a category, to tick and file in one go.
struct CategoryScanSheet: View {
    @EnvironmentObject private var library: RecipeLibrary
    @Environment(\.dismiss) private var dismiss
    let category: String
    let candidates: [Recipe]
    @State private var chosen: Set<UUID>

    init(category: String, candidates: [Recipe]) {
        self.category = category
        self.candidates = candidates
        _chosen = State(initialValue: Set(candidates.map(\.id)))
    }

    var body: some View {
        NavigationStack {
            List(candidates) { recipe in
                Toggle(isOn: Binding(
                    get: { chosen.contains(recipe.id) },
                    set: { if $0 { chosen.insert(recipe.id) } else { chosen.remove(recipe.id) } }
                )) { RecipeRow(recipe: recipe) }
            }
            .listStyle(.plain)
            .overlay {
                if candidates.isEmpty {
                    ContentUnavailableView(
                        "Nothing to add", systemImage: "checkmark.circle",
                        description: Text("No other recipes look like they belong in \(CategoryTree.displayName(category)).")
                    )
                }
            }
            .navigationTitle("Add to \(CategoryTree.components(category).last ?? category)")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { CancelButton() }
                ToolbarItem(placement: .confirmationAction) {
                    ConfirmButton(title: chosen.isEmpty ? "Add" : "Add \(chosen.count)", isDisabled: chosen.isEmpty) {
                        Task {
                            for id in chosen { await library.addTag(id, to: category) }
                            dismiss()
                        }
                    }
                }
            }
        }
        #if os(macOS)
        .frame(minWidth: 420, minHeight: 480)
        #endif
    }
}

/// A titled, adaptive grid: folder tiles on the Recipes home, subcategories and cards in a category.
/// On an unfolded Duo each page gets its own columns, so no tile sits on the fold.
struct GridSection<Content: View>: View {
    let title: String?
    let minimum: CGFloat
    let spacing: CGFloat
    var takesCategories = false
    @ViewBuilder let content: Content
    @State private var space = GridSpace(width: 0, fold: nil)

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let title {
                if takesCategories { Text(title).appFont(.title3, weight: .semibold).categoryRootDrop() }
                else { Text(title).appFont(.title3, weight: .semibold) }
            }
            LazyVGrid(columns: columns, spacing: spacing) { content }
                .onGeometryChange(for: GridSpace.self) { GridSpace(width: $0.size.width, fold: $0.verticalFold) } action: { space = $0 }
        }
    }

    private var columns: [GridItem] {
        guard let fold = space.fold else { return [GridItem(.adaptive(minimum: minimum), spacing: spacing)] }
        let leading = page(fold.minX - spacing / 2), trailing = page(space.width - fold.maxX - spacing / 2)
        let leadingItems = (0..<leading.count).map { index in
            GridItem(.fixed(leading.width), spacing: index == leading.count - 1 ? fold.width + spacing : spacing)
        }
        return leadingItems + Array(repeating: GridItem(.fixed(trailing.width), spacing: spacing), count: trailing.count)
    }

    private func page(_ width: CGFloat) -> (count: Int, width: CGFloat) {
        let count = max(1, Int((width + spacing) / (minimum + spacing)))
        return (count, (width - CGFloat(count - 1) * spacing) / CGFloat(count))
    }
}

private struct GridSpace: Equatable {
    var width: CGFloat
    var fold: CGRect?
}

struct FindRecipesAction {
    let title: String
    let perform: () -> Void
}

/// Everything for adding recipes: the toolbar, the new/import/scan flows, and their sheets.
private struct RecipeActionsModifier: ViewModifier {
    @EnvironmentObject private var library: RecipeLibrary
    @EnvironmentObject private var router: AppRouter
    @Binding var selection: Recipe.ID?
    var listStyle: Binding<RecipeListStyle>?
    var findRecipes: FindRecipesAction?

    @State private var showingNew = false
    @State private var ideaDraft: IdeaDraft?
    @State private var showingImport = false
    @State private var showingFileImporter = false
    @State private var showingScanner = false
    @State private var draft: ScanDraft?
    @State private var showingMealCamera = false
    @State private var showingMealLibrary = false
    @State private var mealPhotoItem: PhotosPickerItem?
    @State private var progressMessage: String?
    @State private var scanError: String?

    func body(content: Content) -> some View {
        content
        .overlay {
            if let progressMessage {
                VStack(spacing: 4) {
                    MascotLoader(height: 120)
                    Text(progressMessage).appFont(.headline)
                }
                .padding(20)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            }
        }
        .toolbar {
            if let findRecipes {
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        if let listStyle { listStyleButton(listStyle) }
                        Menu { addItems } label: { Label("Add Recipe", systemImage: "plus") }
                        Button("Find Recipes for \(findRecipes.title)", systemImage: "sparkle.magnifyingglass", action: findRecipes.perform)
                    } label: { Label("More", systemImage: "ellipsis.circle") }
                }
            } else {
                if let listStyle {
                    ToolbarItem(placement: .primaryAction) { listStyleButton(listStyle) }
                }
                ToolbarItem(placement: addPlacement) {
                    Menu { addItems } label: { Label("Add Recipe", systemImage: "plus") }
                }
            }
        }
        .onChange(of: router.reminder, initial: true) { _, kind in
            guard kind == .addRecipe else { return }
            showingImport = true
            router.reminder = nil
        }
        .sheet(isPresented: $showingNew) {
            RecipeEditorView(recipe: Recipe(title: "")) { saved, image, steps in
                Task { await library.save(saved, image: image, steps: steps) }
                selection = saved.id
            }
        }
        .sheet(item: $ideaDraft) { draft in
            NewIdeaSheet(photo: draft.photo) { selection = $0.id }
        }
        .sheet(isPresented: $showingImport) {
            ImportURLView(
                onReview: { result in
                    draft = ScanDraft(
                        recipe: result.recipe, text: result.sourceText, textTitle: result.sourceTitle,
                        notice: result.message, imageData: result.imageData, stepImages: result.stepImageData
                    )
                },
                onSaved: { selection = $0.id }
            )
        }
        .sheet(item: $draft) { draft in
            RecipeEditorView(recipe: draft.recipe, scannedText: draft.text, scannedTextTitle: draft.textTitle, notice: draft.notice, initialImage: draft.imageData, initialStepImages: draft.stepImages) { saved, image, steps in
                Task { await library.save(saved, image: image, steps: steps) }
                selection = saved.id
            }
        }
        #if os(iOS)
        .fullScreenCover(isPresented: $showingScanner) {
            DocumentScanner(
                onFinish: { images in
                    showingScanner = false
                    scan { try RecipeScanner.recognizeText(in: images) }
                },
                onCancel: { showingScanner = false }
            )
            .ignoresSafeArea()
        }
        .fullScreenCover(isPresented: $showingMealCamera) {
            MealCamera(
                onFinish: { data in
                    showingMealCamera = false
                    ideaDraft = IdeaDraft(photo: data)
                },
                onCancel: { showingMealCamera = false }
            )
            .ignoresSafeArea()
        }
        #endif
        .photosPicker(isPresented: $showingMealLibrary, selection: $mealPhotoItem, matching: .images)
        .onChange(of: mealPhotoItem) { _, item in
            guard let item else { return }
            mealPhotoItem = nil
            Task {
                if let data = try? await item.loadTransferable(type: Data.self) {
                    ideaDraft = IdeaDraft(photo: data)
                } else {
                    scanError = "Couldn't load that photo."
                }
            }
        }
        .fileImporter(isPresented: $showingFileImporter, allowedContentTypes: [.image, .pdf]) { result in
            guard case .success(let url) = result else { return }
            scan {
                let accessing = url.startAccessingSecurityScopedResource()
                defer { if accessing { url.stopAccessingSecurityScopedResource() } }
                return try RecipeScanner.recognizeText(in: try RecipeScanner.images(from: url))
            }
        }
        .alert("Couldn't scan", isPresented: Binding(get: { scanError != nil }, set: { if !$0 { scanError = nil } })) {
            Button("OK") { scanError = nil }
        } message: {
            Text(scanError ?? "")
        }
    }

    private var addPlacement: ToolbarItemPlacement {
        #if os(iOS)
        .topBarLeading
        #else
        .primaryAction
        #endif
    }

    private func listStyleButton(_ listStyle: Binding<RecipeListStyle>) -> some View {
        Button {
            listStyle.wrappedValue = listStyle.wrappedValue == .cards ? .list : .cards
        } label: {
            Label(listStyle.wrappedValue == .cards ? "Show as List" : "Show as Cards", systemImage: listStyle.wrappedValue == .cards ? "list.bullet" : "square.grid.2x2")
        }
        .help(listStyle.wrappedValue == .cards ? "Show as a compact list" : "Show as photo cards")
    }

    @ViewBuilder
    private var addItems: some View {
        Button("New Recipe", systemImage: "square.and.pencil") { showingNew = true }
        Button("New Idea…", systemImage: "lightbulb") { ideaDraft = IdeaDraft() }
        Button("Import from Web or YouTube…", systemImage: "globe") { showingImport = true }
        #if os(iOS)
        Button("Scan Recipe…", systemImage: "doc.viewfinder") {
            if DocumentScanner.isAvailable { showingScanner = true } else { scanError = "Scanning needs a device with a camera." }
        }
        #endif
        Button("Import Photo or PDF…", systemImage: "photo.on.rectangle") { showingFileImporter = true }
        #if os(iOS)
        Menu("Idea from Photo", systemImage: "fork.knife.circle") {
            if MealCamera.isAvailable {
                Button("Take Photo", systemImage: "camera") { showingMealCamera = true }
            }
            Button("Choose Photo", systemImage: "photo") { showingMealLibrary = true }
        }
        #else
        Button("Idea from Photo…", systemImage: "fork.knife.circle") { showingMealLibrary = true }
        #endif
    }

    private func scan(_ recognize: @escaping @Sendable () throws -> String) {
        progressMessage = "Reading recipe…"
        Task {
            let result = await Task.detached { Result { try recognize() } }.value
            progressMessage = nil
            switch result {
            case .success(let text):
                if text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    scanError = "No text found."
                } else {
                    draft = ScanDraft(recipe: RecipeTextParser.parse(text), text: text)
                }
            case .failure(let error):
                scanError = error.localizedDescription
            }
        }
    }
}

extension View {
    func recipeActions(selection: Binding<Recipe.ID?>, listStyle: Binding<RecipeListStyle>?, findRecipes: FindRecipesAction? = nil) -> some View {
        modifier(RecipeActionsModifier(selection: selection, listStyle: listStyle, findRecipes: findRecipes))
    }
}

#if os(iOS)
enum RecipesRoute: Hashable {
    case collection(RecipeCollection)
    case recipe(UUID)
}

struct CategoryRow: View {
    @EnvironmentObject private var library: RecipeLibrary
    let node: CategoryNode

    var body: some View {
        NavigationLink(value: RecipesRoute.collection(.category(node.path))) {
            LabeledContent {
                Text("\(RecipeCollection.category(node.path).filter(library.recipes).count)").foregroundStyle(.secondary).monospacedDigit()
            } label: {
                Label(node.name, systemImage: node.children.isEmpty ? "tag" : "folder")
            }
        }
        // The row background only reaches the list from the outermost modifier.
        .categoryDragAndDrop(node.path)
        .themedRow(raised: true)
    }
}

/// A collection or category to open, as a tile.
private struct FolderTile: View {
    @EnvironmentObject private var library: RecipeLibrary
    @Environment(\.appearance) private var appearance
    @Environment(\.appAccent) private var accent
    let collection: RecipeCollection
    var symbol: String?

    private var count: Int { collection.filter(library.recipes).count }

    var body: some View {
        NavigationLink(value: RecipesRoute.collection(collection)) {
            HStack(spacing: 14) {
                Image(systemName: symbol ?? collection.symbol)
                    .appFont(.title2)
                    .foregroundStyle(accent)
                    .frame(width: 32)
                VStack(alignment: .leading, spacing: 2) {
                    Text(collection.title).appFont(.headline).lineLimit(1)
                    Text(count == 1 ? "1 recipe" : "\(count) recipes").appFont(.subheadline).foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right").appFont(.footnote, weight: .semibold).foregroundStyle(.tertiary)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(appearance.surface ?? Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
        .categoryDragAndDrop(categoryPath, axis: .horizontal)
    }

    private var categoryPath: String? {
        if case .category(let path) = collection { path } else { nil }
    }
}

#endif

extension View {
    func macSearchable(text: Binding<String>, prompt: String) -> some View {
        #if os(macOS)
        searchable(text: text, prompt: prompt)
        #else
        self
        #endif
    }

    /// Keeps the search field visible at the top on iPhone instead of scrolling away with the list.
    func persistentSearch(text: Binding<String>, prompt: String) -> some View {
        #if os(iOS)
        searchable(text: text, placement: .navigationBarDrawer(displayMode: .always), prompt: prompt)
        #else
        searchable(text: text, prompt: prompt)
        #endif
    }
}

/// One piece of the line under a recipe's title. Settings picks which ones show.
enum RecipeDetail: String, CaseIterable {
    case rating, favorite, upNext, tags, time, lastMade

    static let defaults: [RecipeDetail] = [.rating, .favorite, .upNext, .tags]

    static func parse(_ raw: String) -> Set<RecipeDetail> {
        Set(raw.split(separator: ",").compactMap { RecipeDetail(rawValue: String($0)) })
    }

    static func raw(_ details: some Sequence<RecipeDetail>) -> String {
        allCases.filter(Set(details).contains).map(\.rawValue).joined(separator: ",")
    }

    var title: String {
        switch self {
        case .rating: "Rating"
        case .favorite: "Favorite"
        case .upNext: "Up Next"
        case .tags: "Tags"
        case .time: "Total time"
        case .lastMade: "Last made"
        }
    }

    var symbol: String {
        switch self {
        case .rating: "star"
        case .favorite: "heart"
        case .upNext: "text.line.first.and.arrowtriangle.forward"
        case .tags: "tag"
        case .time: "clock"
        case .lastMade: "frying.pan"
        }
    }
}

/// The marks and facts under a recipe's title, as chosen in Settings.
struct RecipeFacts: View {
    @AppStorage(AppSettings.Key.recipeDetails) private var raw = RecipeDetail.raw(RecipeDetail.defaults)
    @Environment(\.appAccent) private var accent
    let recipe: Recipe

    var body: some View {
        line
            .appFont(.subheadline)
            .foregroundStyle(.secondary)
            .lineLimit(1)
    }

    private var line: Text {
        let groups = [marks, facts].filter { !$0.isEmpty }.map { $0.dropFirst().reduce($0[0]) { $0 + Text("  ") + $1 } }
        guard let first = groups.first else { return Text(verbatim: "") }
        return groups.dropFirst().reduce(first) { $0 + Text("  ·  ").foregroundStyle(.tertiary) + $1 }
    }

    private var marks: [Text] {
        let shown = RecipeDetail.parse(raw)
        var marks: [Text] = []
        if shown.contains(.rating), let rating = recipe.rating {
            marks.append(Text("\(Image(systemName: "star.fill")) \(rating)").fontWeight(.semibold).foregroundStyle(.primary))
        }
        if shown.contains(.favorite), recipe.isFavorite {
            marks.append(Text(Image(systemName: "heart.fill")).foregroundStyle(accent))
        }
        if shown.contains(.upNext), recipe.wantToCook {
            marks.append(Text(Image(systemName: "text.line.first.and.arrowtriangle.forward")).foregroundStyle(.primary))
        }
        return marks
    }

    private var facts: [Text] {
        let shown = RecipeDetail.parse(raw)
        var facts: [Text] = []
        if recipe.isIdea { facts.append(Text("Idea")) }
        if shown.contains(.tags), !recipe.tags.isEmpty {
            facts.append(Text(recipe.tags.map { CategoryTree.components($0).last ?? $0 }.joined(separator: ", ")))
        }
        if shown.contains(.time), let minutes = recipe.totalMinutes { facts.append(Text("\(minutes) min")) }
        if shown.contains(.lastMade), let made = recipe.lastMade {
            facts.append(Text("Made \(made, format: .relative(presentation: .named))"))
        }
        return facts
    }
}

struct RecipeCard: View {
    let recipe: Recipe

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Color.clear
                .aspectRatio(16 / 10, contentMode: .fit)
                .frame(maxWidth: .infinity)
                .overlay { RecipeImageView(recipe: recipe) }
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            VStack(alignment: .leading, spacing: 4) {
                Text(recipe.title).appFont(.title3, weight: .semibold).lineLimit(2)
                RecipeFacts(recipe: recipe)
            }
            .padding(.horizontal, 4)
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }
}

struct RecipeRow: View {
    let recipe: Recipe

    var body: some View {
        HStack(spacing: 12) {
            RecipeImageView(recipe: recipe)
                .frame(width: 64, height: 64)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            VStack(alignment: .leading, spacing: 3) {
                Text(recipe.title).appFont(.headline).lineLimit(2)
                RecipeFacts(recipe: recipe)
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 3)
    }
}

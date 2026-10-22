import RecipeKit
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
    var symbol: String { self == .cards ? "square.grid.2x2" : "list.bullet" }
}

struct RecipeListView: View {
    @EnvironmentObject private var library: RecipeLibrary
    @Binding var collection: RecipeCollection
    @Binding var selection: Recipe.ID?
    var styleOverride: RecipeListStyle?
    var showsSettings = false

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
            .macSearchable(text: $search, prompt: "Search recipes")
            .navigationTitle(collection.title)
            .recipeActions(
                selection: $selection,
                listStyle: usesGrid ? nil : Binding(get: { style }, set: { storedStyle = $0 }),
                showsSettings: showsSettings
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
            if browsedCategory != nil, !library.recipes.isEmpty {
                Section { scanButton }.themedRow()
            }
        }
        .listStyle(.plain)
        .themedCanvas()
        .animation(.snappy, value: items.map(\.id))
        .overlay { emptyState }
    }

    private var scanButton: some View {
        Button { scanning = true } label: {
            Label("Find Recipes for \(collection.title)", systemImage: "sparkle.magnifyingglass")
        }
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
                    GridSection(title: hasSubcategories ? "Recipes" : nil, minimum: 300, spacing: 24) {
                        ForEach(items) { recipe in
                            Button { selection = recipe.id } label: { RecipeCard(recipe: recipe) }
                                .buttonStyle(.plain)
                                .draggable(RecipeDragItem(id: recipe.id))
                                .contextMenu { recipeMenu(recipe) }
                        }
                    }
                }
                if browsedCategory != nil, !library.recipes.isEmpty { scanButton.buttonStyle(.bordered) }
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
                Text("Syncing recipes…").font(.headline)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .accessibilityElement(children: .combine)
        }
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
struct GridSection<Content: View>: View {
    let title: String?
    let minimum: CGFloat
    let spacing: CGFloat
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let title { Text(title).font(.title3.weight(.semibold)) }
            LazyVGrid(columns: [GridItem(.adaptive(minimum: minimum), spacing: spacing)], spacing: spacing) { content }
        }
    }
}

/// Everything for adding recipes: the toolbar, the new/import/scan flows, and their sheets.
private struct RecipeActionsModifier: ViewModifier {
    @EnvironmentObject private var library: RecipeLibrary
    @EnvironmentObject private var router: AppRouter
    @Binding var selection: Recipe.ID?
    var listStyle: Binding<RecipeListStyle>?
    var showsSettings = false

    @State private var showingNew = false
    @State private var showingIdea = false
    @State private var showingImport = false
    @State private var showingFileImporter = false
    @State private var showingScanner = false
    @State private var draft: ScanDraft?
    @State private var isScanning = false
    @State private var scanError: String?
    @State private var showingSettings = false

    func body(content: Content) -> some View {
        content
        .overlay {
            if isScanning {
                VStack(spacing: 4) {
                    MascotLoader(height: 120)
                    Text("Reading recipe…").font(.headline)
                }
                .padding(20)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            }
        }
        .toolbar {
            #if os(iOS)
            if showsSettings {
                ToolbarItem(placement: .navigation) {
                    Button { showingSettings = true } label: { Label("Settings", systemImage: "gearshape") }
                }
            }
            #endif
            if let listStyle {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        listStyle.wrappedValue = listStyle.wrappedValue == .cards ? .list : .cards
                    } label: {
                        Label(listStyle.wrappedValue == .cards ? "Show as List" : "Show as Cards", systemImage: listStyle.wrappedValue == .cards ? "list.bullet" : "square.grid.2x2")
                    }
                    .help(listStyle.wrappedValue == .cards ? "Show as a compact list" : "Show as photo cards")
                }
            }
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button("New Recipe", systemImage: "square.and.pencil") { showingNew = true }
                    Button("New Idea…", systemImage: "lightbulb") { showingIdea = true }
                    Button("Import from Web or YouTube…", systemImage: "globe") { showingImport = true }
                    #if os(iOS)
                    Button("Scan Recipe…", systemImage: "doc.viewfinder") {
                        if DocumentScanner.isAvailable { showingScanner = true } else { scanError = "Scanning needs a device with a camera." }
                    }
                    #endif
                    Button("Import Photo or PDF…", systemImage: "photo.on.rectangle") { showingFileImporter = true }
                } label: { Label("Add Recipe", systemImage: "plus") }
            }
        }
        .onChange(of: router.reminder, initial: true) { _, kind in
            guard kind == .addRecipe else { return }
            showingImport = true
            router.reminder = nil
        }
        .sheet(isPresented: $showingSettings) { SettingsView() }
        .sheet(isPresented: $showingNew) {
            RecipeEditorView(recipe: Recipe(title: "")) { saved, image, steps in
                Task { await library.save(saved, image: image, steps: steps) }
                selection = saved.id
            }
        }
        .sheet(isPresented: $showingIdea) {
            NewIdeaSheet { selection = $0.id }
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
        #endif
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

    private func scan(_ recognize: @escaping @Sendable () throws -> String) {
        isScanning = true
        Task {
            let result = await Task.detached { Result { try recognize() } }.value
            isScanning = false
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
    func recipeActions(selection: Binding<Recipe.ID?>, listStyle: Binding<RecipeListStyle>?, showsSettings: Bool = false) -> some View {
        modifier(RecipeActionsModifier(selection: selection, listStyle: listStyle, showsSettings: showsSettings))
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
        .themedRow(raised: true)
        .dropDestination(for: RecipeDragItem.self) { items, _ in
            Task { for item in items { await library.addTag(item.id, to: node.path) } }
            return !items.isEmpty
        }
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
                    .font(.title2)
                    .foregroundStyle(accent)
                    .frame(width: 32)
                VStack(alignment: .leading, spacing: 2) {
                    Text(collection.title).font(.headline).lineLimit(1)
                    Text(count == 1 ? "1 recipe" : "\(count) recipes").font(.subheadline).foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right").font(.footnote.weight(.semibold)).foregroundStyle(.tertiary)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(appearance.surface ?? Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
        .dropDestination(for: RecipeDragItem.self) { items, _ in
            guard case .category(let path) = collection else { return false }
            Task { for item in items { await library.addTag(item.id, to: path) } }
            return !items.isEmpty
        }
    }
}

/// The top of the Recipes tab: the built-in collections, then categories to drill into.
struct RecipesHomeView: View {
    @EnvironmentObject private var library: RecipeLibrary
    @AppStorage(AppSettings.Key.ratingStyle) private var ratingStyleRaw = RatingStyle.favorites.rawValue
    @Environment(\.horizontalSizeClass) private var sizeClass
    @Binding var selection: Recipe.ID?

    private var collections: [RecipeCollection] {
        let liked: RecipeCollection = (RatingStyle(rawValue: ratingStyleRaw) ?? .favorites) == .stars ? .topRated : .favorites
        return [.all, .recent, liked, .uncategorized].filter { $0 == .all || $0 == .recent || $0 == liked || !$0.filter(library.recipes).isEmpty }
    }

    var body: some View {
        Group {
            if library.recipes.isEmpty {
                EmptyLibraryView().frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if sizeClass == .regular {
                grid
            } else {
                list
            }
        }
        .themedCanvas()
        .navigationTitle("Recipes")
        .recipeActions(selection: $selection, listStyle: nil, showsSettings: sizeClass != .regular)
    }

    private var list: some View {
        List {
            Section {
                ForEach(collections, id: \.self) { collection in
                    NavigationLink(value: RecipesRoute.collection(collection)) {
                        LabeledContent {
                            Text("\(collection.filter(library.recipes).count)").foregroundStyle(.secondary).monospacedDigit()
                        } label: {
                            Label(collection.title, systemImage: collection.symbol)
                        }
                    }
                    .themedRow(raised: true)
                }
            }
            if !library.categoryTree.isEmpty {
                Section("Categories") {
                    ForEach(library.categoryTree) { CategoryRow(node: $0) }
                }
            }
        }
        .contentMargins(.top, 16, for: .scrollContent)
    }

    private var grid: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                GridSection(title: nil, minimum: 240, spacing: 16) {
                    ForEach(collections, id: \.self) { FolderTile(collection: $0) }
                }
                if !library.categoryTree.isEmpty {
                    GridSection(title: "Categories", minimum: 240, spacing: 16) {
                        ForEach(library.categoryTree) { FolderTile(collection: .category($0.path), symbol: $0.children.isEmpty ? "tag" : "folder") }
                    }
                }
            }
            .padding(24)
        }
        .reviewPromptInset()
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

struct RecipeBadges: View {
    let recipe: Recipe

    var body: some View {
        HStack(spacing: 6) {
            if recipe.isFavorite { Image(systemName: "heart.fill").font(.caption).foregroundStyle(Theme.accent) }
            if let rating = recipe.rating {
                HStack(spacing: 2) {
                    Image(systemName: "star.fill")
                    Text("\(rating)").monospacedDigit()
                }
                .font(.caption.weight(.semibold))
                .foregroundStyle(Theme.accent)
            }
            if recipe.wantToCook {
                Image(systemName: "text.line.first.and.arrowtriangle.forward").font(.caption).foregroundStyle(.secondary)
            }
        }
    }
}

struct RecipeMeta: View {
    let recipe: Recipe

    var body: some View {
        HStack(spacing: 10) {
            if recipe.isIdea { Label("Idea", systemImage: "lightbulb") }
            if let minutes = recipe.totalMinutes { Label("\(minutes) min", systemImage: "clock") }
            if !recipe.tags.isEmpty { Label(recipe.tags.prefix(2).map(CategoryTree.displayName).joined(separator: ", "), systemImage: "tag") }
        }
        .font(.caption).foregroundStyle(.secondary).labelStyle(.titleAndIcon)
    }
}

struct RecipeCard: View {
    @EnvironmentObject private var library: RecipeLibrary
    @Environment(\.appAccent) private var accent
    let recipe: Recipe

    private var hasPhoto: Bool { library.hasImage(recipe.id) }

    var body: some View {
        Color.clear
            .aspectRatio(4 / 3, contentMode: .fit)
            .frame(maxWidth: .infinity)
            .overlay { backdrop }
            .overlay(alignment: .bottomLeading) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(recipe.title)
                        .font(.system(.title2, weight: .semibold))
                        .lineLimit(2)
                        .shadow(color: .black.opacity(0.35), radius: 4, y: 1)
                    details
                }
                .foregroundStyle(.white)
                .padding(16)
            }
            .overlay(alignment: .topTrailing) { badges.padding(12) }
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .shadow(color: .black.opacity(0.14), radius: 10, y: 5)
            .accessibilityElement(children: .combine)
    }

    private var backdrop: some View {
        ZStack {
            if hasPhoto {
                RecipeImageView(recipe: recipe)
            } else {
                LinearGradient(colors: [accent, accent.opacity(0.65)], startPoint: .topLeading, endPoint: .bottomTrailing)
                Image(systemName: "fork.knife")
                    .font(.system(size: 56)).foregroundStyle(.white.opacity(0.22))
            }
            LinearGradient(colors: [.clear, .black.opacity(0.7)], startPoint: .center, endPoint: .bottom)
        }
    }

    private var details: some View {
        var parts: [String] = []
        if recipe.isIdea { parts.append("Idea") }
        if let minutes = recipe.totalMinutes { parts.append("\(minutes) min") }
        if let tag = recipe.tags.first { parts.append(CategoryTree.displayName(tag)) }
        return Text(parts.joined(separator: "  ·  "))
            .font(.subheadline.weight(.medium))
            .foregroundStyle(.white.opacity(0.88))
            .lineLimit(1)
    }

    @ViewBuilder
    private var badges: some View {
        if recipe.isFavorite || recipe.wantToCook || recipe.rating != nil {
            HStack(spacing: 8) {
                if recipe.isFavorite { Image(systemName: "heart.fill").foregroundStyle(Theme.accent) }
                if let rating = recipe.rating {
                    Label("\(rating)", systemImage: "star.fill").foregroundStyle(Theme.accent).monospacedDigit()
                }
                if recipe.wantToCook { Image(systemName: "text.line.first.and.arrowtriangle.forward").foregroundStyle(.primary) }
            }
            .font(.footnote.weight(.semibold))
            .padding(.horizontal, 10).padding(.vertical, 6)
            .glassEffect(.regular, in: Capsule())
        }
    }
}

struct RecipeRow: View {
    let recipe: Recipe

    var body: some View {
        HStack(spacing: 12) {
            RecipeImageView(recipe: recipe)
                .frame(width: 64, height: 64)
                .clipShape(RoundedRectangle(cornerRadius: 10))
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(recipe.title).font(.system(.headline)).lineLimit(2)
                    RecipeBadges(recipe: recipe)
                }
                if !recipe.summary.isEmpty {
                    Text(recipe.summary).font(.subheadline).foregroundStyle(.secondary).lineLimit(1)
                }
                RecipeMeta(recipe: recipe)
            }
        }
        .padding(.vertical, 3)
    }
}

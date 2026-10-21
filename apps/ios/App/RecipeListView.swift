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
    /// On iPhone a category is a folder with subcategories to open. The iPad sidebar shows the tree instead.
    var showsFolders = true
    var showsSettings = false
    var showsFilter = false

    @AppStorage(AppSettings.Key.listStyle) private var storedStyle = RecipeListStyle.list
    @State private var search = ""
    @State private var editing: Recipe?

    private var style: RecipeListStyle { styleOverride ?? storedStyle }

    private var browsedCategory: String? {
        if case .category(let path) = collection { path } else { nil }
    }

    var body: some View {
        recipeList
            .macSearchable(text: $search, prompt: "Search recipes")
            .navigationTitle(collection.title)
            .toolbar {
                if showsFilter {
                    ToolbarItem(placement: .primaryAction) { RecipeFilterMenu(collection: $collection) }
                }
            }
            .recipeActions(selection: $selection, listStyle: Binding(get: { style }, set: { storedStyle = $0 }), showsSettings: showsSettings)
            .sheet(item: $editing) { recipe in
                RecipeEditorView(recipe: recipe) { saved, image, steps in Task { await library.save(saved, image: image, steps: steps) } }
            }
    }

    /// A category on iPhone and iPad is a folder: its subcategories, then the recipes filed directly in it.
    private var items: [Recipe] {
        #if os(iOS)
        if showsFolders, case .category(let path) = collection {
            return library.recipes.filter { recipe in
                recipe.tags.contains { CategoryTree.components($0).count == CategoryTree.components(path).count && CategoryTree.tag($0, isIn: path) }
            }.filter { $0.matches(search) }
        }
        #endif
        return collection.filter(library.recipes).filter { $0.matches(search) }
    }

    #if os(iOS)
    private var subcategories: [CategoryNode] {
        guard showsFolders, case .category(let path) = collection, search.isEmpty else { return [] }
        return CategoryTree.node(at: path, in: library.categoryTree)?.children ?? []
    }
    #endif

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
                    .contextMenu {
                        RecipeQuickActions(recipe: recipe)
                        Button("Edit", systemImage: "pencil") { editing = recipe }
                        if let browsedCategory {
                            Button("Remove Tag", systemImage: "tag.slash") { Task { await library.removeTags(recipe, in: browsedCategory) } }
                        }
                    }
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
        .overlay {
            if library.recipes.isEmpty {
                MascotEmptyState(mascot: .tomatoWave, title: "No recipes yet",
                                 message: "Tap + to add one, share one from Safari, or use the recipes command-line tool.")
            } else if items.isEmpty, search.isEmpty {
                #if os(iOS)
                if subcategories.isEmpty { MascotEmptyState(mascot: .tomatoSpoon, title: collection.title, message: "No recipes here yet.") }
                #else
                MascotEmptyState(mascot: .tomatoSpoon, title: collection.title, message: "No recipes here yet.")
                #endif
            } else if items.isEmpty {
                ContentUnavailableView.search(text: search)
            }
        }
    }
}

/// Collections and the category tree as filters on the recipe list.
struct RecipeFilterMenu: View {
    @EnvironmentObject private var library: RecipeLibrary
    @AppStorage(AppSettings.Key.ratingStyle) private var ratingStyleRaw = RatingStyle.favorites.rawValue
    @Binding var collection: RecipeCollection

    private var collections: [RecipeCollection] {
        RecipeCollection.smart(for: RatingStyle(rawValue: ratingStyleRaw) ?? .favorites)
            .filter { $0 != .uncategorized || !$0.filter(library.recipes).isEmpty }
    }

    var body: some View {
        Menu {
            Picker("Filter", selection: $collection) {
                Label(RecipeCollection.all.title, systemImage: RecipeCollection.all.symbol).tag(RecipeCollection.all)
                ForEach(collections, id: \.self) { Label($0.title, systemImage: $0.symbol).tag($0) }
            }
            if !library.categoryTree.isEmpty {
                Section("Categories") {
                    ForEach(library.categoryTree) { CategoryFilterItem(node: $0, collection: $collection) }
                }
            }
        } label: {
            Label("Filter", systemImage: collection == .all ? "line.3.horizontal.decrease" : "line.3.horizontal.decrease.circle.fill")
        }
    }
}

private struct CategoryFilterItem: View {
    let node: CategoryNode
    @Binding var collection: RecipeCollection

    var body: some View {
        if node.children.isEmpty {
            Button(node.name, systemImage: "tag") { collection = .category(node.path) }
        } else {
            Menu(node.name, systemImage: "folder") {
                Button("All \(node.name)", systemImage: "tag") { collection = .category(node.path) }
                ForEach(node.children) { CategoryFilterItem(node: $0, collection: $collection) }
            }
        }
    }
}

/// Everything for adding recipes: the toolbar, the new/import/scan flows, and their sheets.
private struct RecipeActionsModifier: ViewModifier {
    @EnvironmentObject private var library: RecipeLibrary
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
                    TomatoWokLoader(height: 120)
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

/// The top of the Recipes tab: the built-in collections, then categories to drill into.
struct RecipesHomeView: View {
    @EnvironmentObject private var library: RecipeLibrary
    @AppStorage(AppSettings.Key.ratingStyle) private var ratingStyleRaw = RatingStyle.favorites.rawValue
    @Binding var selection: Recipe.ID?

    private var collections: [RecipeCollection] {
        let liked: RecipeCollection = (RatingStyle(rawValue: ratingStyleRaw) ?? .favorites) == .stars ? .topRated : .favorites
        return [.all, .recent, liked, .uncategorized].filter { $0 == .all || $0 == .recent || $0 == liked || !$0.filter(library.recipes).isEmpty }
    }

    var body: some View {
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
        .overlay {
            if library.recipes.isEmpty {
                MascotEmptyState(mascot: .tomatoWave, title: "No recipes yet",
                                 message: "Tap + to add one, share one from Safari, or use the recipes command-line tool.")
            }
        }
        .themedCanvas()
        .navigationTitle("Recipes")
        .recipeActions(selection: $selection, listStyle: nil, showsSettings: true)
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

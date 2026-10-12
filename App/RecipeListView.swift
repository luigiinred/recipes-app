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
    let showsCollectionMenu: Bool
    var styleOverride: RecipeListStyle?

    @AppStorage(AppSettings.Key.listStyle) private var storedStyle = RecipeListStyle.list
    @State private var search = ""
    @State private var editing: Recipe?
    @State private var showingNew = false
    @State private var showingImport = false
    @State private var showingFileImporter = false
    @State private var showingScanner = false
    @State private var draft: ScanDraft?
    @State private var isScanning = false
    @State private var scanError: String?
    @State private var showingSettings = false

    private var style: RecipeListStyle { styleOverride ?? storedStyle }

    var body: some View {
        content
        .overlay {
            if isScanning {
                ProgressView("Reading recipe…").padding().background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
            }
        }
        .macSearchable(text: $search, prompt: "Search recipes")
        .navigationTitle(collection.title)
        .toolbar {
            if showsCollectionMenu {
                ToolbarItem(placement: .navigation) { CollectionMenu(collection: $collection) }
            }
            #if os(iOS)
            ToolbarItem(placement: .navigation) {
                Button { showingSettings = true } label: { Label("Settings", systemImage: "gearshape") }
            }
            #endif
            ToolbarItem(placement: .primaryAction) {
                Button {
                    storedStyle = style == .cards ? .list : .cards
                } label: {
                    Label(style == .cards ? "Show as List" : "Show as Cards", systemImage: style == .cards ? "list.bullet" : "square.grid.2x2")
                }
                .help(style == .cards ? "Show as a compact list" : "Show as photo cards")
            }
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button("New Recipe", systemImage: "square.and.pencil") { showingNew = true }
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
            RecipeEditorView(recipe: Recipe(title: "")) { saved, image in
                Task { await library.save(saved, image: image) }
                selection = saved.id
            }
        }
        .sheet(isPresented: $showingImport) {
            ImportURLView(
                onReview: { result in
                    draft = ScanDraft(
                        recipe: result.recipe, text: result.sourceText, textTitle: result.sourceTitle,
                        notice: result.message, imageData: result.imageData
                    )
                },
                onSaved: { selection = $0.id }
            )
        }
        .sheet(item: $editing) { recipe in
            RecipeEditorView(recipe: recipe) { saved, image in Task { await library.save(saved, image: image) } }
        }
        .sheet(item: $draft) { draft in
            RecipeEditorView(recipe: draft.recipe, scannedText: draft.text, scannedTextTitle: draft.textTitle, notice: draft.notice, initialImage: draft.imageData) { saved, image in
                Task { await library.save(saved, image: image) }
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

    private var pages: [RecipeCollection] {
        var result: [RecipeCollection] = [.all, .wantToCook, .favorites, .recent, .uncategorized]
        result += library.categoryTree.map { .category($0.path) }
        if !result.contains(collection) { result.append(collection) }
        return result
    }

    @ViewBuilder
    private var content: some View {
        #if os(iOS)
        VStack(spacing: 0) {
            CollectionStrip(selection: $collection, pages: pages)
            TabView(selection: $collection) {
                ForEach(pages, id: \.self) { page in
                    recipeList(for: page).tag(page)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
        }
        #else
        recipeList(for: collection)
        #endif
    }

    private func recipeList(for page: RecipeCollection) -> some View {
        let items = page.filter(library.recipes).filter { $0.matches(search) }
        return List(selection: $selection) {
            ForEach(items) { recipe in
                Group {
                    switch style {
                    case .cards: RecipeCard(recipe: recipe)
                    case .list: RecipeRow(recipe: recipe)
                    }
                }
                .tag(recipe.id)
                .listRowSeparator(style == .cards ? .hidden : .automatic)
                .listRowInsets(style == .cards ? EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16) : nil)
                .contextMenu {
                    Button(recipe.isFavorite ? "Remove Favorite" : "Favorite", systemImage: "heart") {
                        Task { await library.setFavorite(recipe, !recipe.isFavorite) }
                    }
                    Button(recipe.wantToCook ? "Remove from Want to Cook" : "Want to Cook", systemImage: "arrow.right.circle") {
                        Task { await library.setWantToCook(recipe, !recipe.wantToCook) }
                    }
                    Button("Edit", systemImage: "pencil") { editing = recipe }
                }
            }
        }
        .listStyle(.plain)
        .overlay {
            if library.recipes.isEmpty {
                ContentUnavailableView("No recipes yet", systemImage: "fork.knife",
                                       description: Text("Tap + to add one, or use the recipes command-line tool."))
            } else if items.isEmpty, search.isEmpty {
                ContentUnavailableView(page.title, systemImage: page.symbol, description: Text("No recipes here yet."))
            } else if items.isEmpty {
                ContentUnavailableView.search(text: search)
            }
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

struct CollectionMenu: View {
    @EnvironmentObject private var library: RecipeLibrary
    @Binding var collection: RecipeCollection

    var body: some View {
        Menu {
            choice(.all, title: RecipeCollection.all.title)
            ForEach(RecipeCollection.smart, id: \.self) { choice($0, title: $0.title) }
            if !library.categoryTree.isEmpty {
                Divider()
                ForEach(library.categoryTree) { category($0) }
            }
        } label: { Label("Collections", systemImage: "line.3.horizontal.decrease.circle") }
    }

    private func choice(_ value: RecipeCollection, title: String) -> some View {
        Button { collection = value } label: {
            if collection == value {
                Label(title, systemImage: "checkmark")
            } else {
                Label(title, systemImage: value.symbol)
            }
        }
    }

    private func category(_ node: CategoryNode) -> AnyView {
        if node.children.isEmpty { return AnyView(choice(.category(node.path), title: node.name)) }
        return AnyView(
            Menu {
                choice(.category(node.path), title: "All \(node.name)")
                Divider()
                ForEach(node.children) { category($0) }
            } label: { Label(node.name, systemImage: "tag") }
        )
    }
}

struct CollectionStrip: View {
    @Binding var selection: RecipeCollection
    let pages: [RecipeCollection]

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(pages, id: \.self) { page in
                        let selected = page == selection
                        Button {
                            withAnimation(.snappy) { selection = page }
                        } label: {
                            Label(page.title, systemImage: page.symbol)
                                .font(.subheadline.weight(.medium))
                                .padding(.horizontal, 14).padding(.vertical, 8)
                                .glassEffect(selected ? .regular.tint(Theme.accent.opacity(0.35)).interactive() : .regular.interactive(), in: Capsule())
                        }
                        .buttonStyle(.plain)
                        .id(page)
                        .accessibilityAddTraits(selected ? .isSelected : [])
                    }
                }
                .padding(.horizontal, 16).padding(.vertical, 8)
            }
            .onChange(of: selection) { _, new in
                withAnimation(.snappy) { proxy.scrollTo(new, anchor: .center) }
            }
        }
    }
}

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
            if recipe.wantToCook { Image(systemName: "arrow.right.circle.fill").font(.caption).foregroundStyle(.secondary) }
        }
    }
}

struct RecipeMeta: View {
    let recipe: Recipe

    var body: some View {
        HStack(spacing: 10) {
            if let minutes = recipe.totalMinutes { Label("\(minutes) min", systemImage: "clock") }
            if !recipe.tags.isEmpty { Label(recipe.tags.prefix(2).map(CategoryTree.displayName).joined(separator: ", "), systemImage: "tag") }
        }
        .font(.caption).foregroundStyle(.secondary).labelStyle(.titleAndIcon)
    }
}

struct RecipeCard: View {
    let recipe: Recipe

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            RecipeImageView(recipe: recipe)
                .aspectRatio(16 / 10, contentMode: .fit)
                .frame(maxWidth: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: 14))
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(recipe.title).font(.system(.title3, design: .serif, weight: .semibold)).lineLimit(2)
                    RecipeBadges(recipe: recipe)
                }
                if !recipe.summary.isEmpty {
                    Text(recipe.summary).font(.subheadline).foregroundStyle(.secondary).lineLimit(2)
                }
                RecipeMeta(recipe: recipe)
            }
            .padding(.horizontal, 2)
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
                    Text(recipe.title).font(.system(.headline, design: .serif)).lineLimit(2)
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

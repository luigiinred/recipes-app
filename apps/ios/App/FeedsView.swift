import RecipeKit
import SwiftUI

struct FeedEntriesList: View {
    @EnvironmentObject private var loader: FeedLoader
    let feed: Feed
    @Binding var selection: FeedEntry.ID?
    var pushes = false

    var body: some View {
        Group {
            switch loader.states[feed.id] {
            case .none, .loading:
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
            case .failed(let message):
                ContentUnavailableView("Couldn't load feed", systemImage: "exclamationmark.triangle", description: Text(message))
            case .loaded(let entries):
                List(selection: $selection) {
                    ForEach(entries) { entry in
                        Group {
                            if pushes {
                                NavigationLink(value: entry) { FeedEntryRow(entry: entry) }
                            } else {
                                FeedEntryRow(entry: entry).tag(entry.id)
                            }
                        }
                    }
                }
                .listStyle(.plain)
            }
        }
        .navigationTitle(feed.title)
        .task { await loader.load(feed) }
        .refreshable { await loader.load(feed, force: true) }
    }
}

struct FeedEntryRow: View {
    let entry: FeedEntry

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(entry.title).appFont(.headline).lineLimit(3)
                if !entry.summary.isEmpty {
                    Text(entry.summary).appFont(.subheadline).foregroundStyle(.secondary).lineLimit(2)
                }
                if let date = entry.published {
                    Text(date, format: .dateTime.month(.abbreviated).day().year())
                        .appFont(.caption).foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 0)
            if let url = entry.imageURL {
                AsyncImage(url: url) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    Color.secondary.opacity(0.12)
                }
                .frame(width: 64, height: 64)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
        .padding(.vertical, 3)
    }
}

struct FeedEntryPreview: View {
    @EnvironmentObject private var library: RecipeLibrary
    @EnvironmentObject private var loader: FeedLoader
    let entry: FeedEntry

    @State private var errorMessage: String?

    var body: some View {
        Group {
            if let result = loader.results[entry.id] {
                RecipeDetailView(recipe: result.recipe, previewSave: {
                    Task { _ = await library.add(result) }
                }, previewImage: result.imageData, previewSaveTitle: "Add to My Recipes", previewSaved: isSaved(result.recipe))
            } else if let errorMessage {
                ContentUnavailableView {
                    Label("No recipe found", systemImage: "fork.knife")
                } description: {
                    Text(errorMessage)
                } actions: {
                    Link("Open in Browser", destination: entry.link)
                }
            } else {
                ProgressView("Loading recipe…").frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .task(id: entry.id) {
            errorMessage = nil
            do { try await loader.loadRecipe(for: entry) } catch { errorMessage = error.localizedDescription }
        }
    }

    private func isSaved(_ recipe: Recipe) -> Bool {
        let source = recipe.sourceURL ?? entry.link.absoluteString
        return library.recipes.contains { $0.sourceURL == source }
    }
}

struct FeedsTabView: View {
    @EnvironmentObject private var library: RecipeLibrary
    @EnvironmentObject private var loader: FeedLoader
    @Environment(\.horizontalSizeClass) private var sizeClass
    @State private var adding = false
    @State private var selectedFeed: UUID?
    @State private var selection: FeedEntry.ID?

    var body: some View {
        Group {
            if sizeClass == .regular { splitLayout } else { stackLayout }
        }
        .sheet(isPresented: $adding) { AddFeedSheet() }
    }

    private var feedList: some View {
        List(selection: sizeClass == .regular ? $selectedFeed : nil) {
            ForEach(library.feeds) { feed in
                Group {
                    if sizeClass == .regular {
                        Label(feed.title, systemImage: "dot.radiowaves.up.forward").tag(feed.id)
                    } else {
                        NavigationLink(value: feed) { Label(feed.title, systemImage: "dot.radiowaves.up.forward") }
                    }
                }
                .swipeActions {
                    Button("Unsubscribe", role: .destructive) { Task { await library.remove(feed) } }
                }
            }
        }
        .overlay {
            if library.feeds.isEmpty {
                ContentUnavailableView("No feeds yet", systemImage: "dot.radiowaves.up.forward",
                                       description: Text("Subscribe to your favorite recipe blogs."))
            }
        }
        .navigationTitle("Feeds")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { adding = true } label: { Label("Add Feed", systemImage: "plus") }
            }
        }
    }

    private var stackLayout: some View {
        NavigationStack {
            feedList
                .navigationDestination(for: Feed.self) { feed in
                    FeedEntriesList(feed: feed, selection: $selection, pushes: true)
                }
                .navigationDestination(for: FeedEntry.self) { entry in
                    FeedEntryPreview(entry: entry)
                }
        }
    }

    private var splitLayout: some View {
        NavigationSplitView {
            feedList
        } content: {
            if let feed = library.feeds.first(where: { $0.id == selectedFeed }) {
                FeedEntriesList(feed: feed, selection: $selection).id(feed.id)
            } else {
                ContentUnavailableView("Select a feed", systemImage: "dot.radiowaves.up.forward")
            }
        } detail: {
            if let selectedFeed, case .loaded(let entries)? = loader.states[selectedFeed],
               let entry = entries.first(where: { $0.id == selection }) {
                FeedEntryPreview(entry: entry)
            } else {
                ContentUnavailableView("Select a post", systemImage: "fork.knife")
            }
        }
        .onChange(of: selectedFeed) { _, _ in selection = nil }
    }
}

struct AddFeedSheet: View {
    @EnvironmentObject private var library: RecipeLibrary
    @Environment(\.dismiss) private var dismiss

    @State private var address = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var preview: FoundFeed?

    private struct FoundFeed: Hashable {
        let url: String
        let title: String
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("https://", text: $address)
                        #if os(iOS)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        #endif
                        .onSubmit(subscribe)
                } footer: {
                    Text("Enter a recipe blog's address or its RSS feed.")
                }
                if let errorMessage { Text(errorMessage).foregroundStyle(.red) }
                Section {
                    Button("Preview Feed") { find { preview = FoundFeed(url: $0.url.absoluteString, title: $0.title) } }
                        .disabled(address.isEmpty || isLoading)
                }
            }
            .navigationDestination(item: $preview) { found in
                FeedPreviewPage(url: found.url, title: found.title, onFollow: { dismiss() })
            }
            .formStyle(.grouped)
            .navigationTitle("Add Feed")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { CancelButton() }
                ToolbarItem(placement: .confirmationAction) {
                    if isLoading { ProgressView().controlSize(.small) } else {
                        ConfirmButton(title: "Subscribe", isDisabled: address.isEmpty, action: subscribe)
                    }
                }
            }
        }
        #if os(macOS)
        .frame(minWidth: 460, minHeight: 220)
        #endif
    }

    private func subscribe() {
        find { found in
            await library.add(Feed(url: found.url.absoluteString, title: found.title))
            dismiss()
        }
    }

    private func find(then use: @escaping (_ found: (url: URL, title: String)) async -> Void) {
        guard !isLoading else { return }
        var text = address.trimmingCharacters(in: .whitespacesAndNewlines)
        if !text.contains("://") { text = "https://" + text }
        guard let url = URL(string: text), url.host != nil else {
            errorMessage = "That doesn't look like a web address."
            return
        }
        isLoading = true
        errorMessage = nil
        Task {
            do {
                let found = try await FeedService.discover(from: url)
                isLoading = false
                await use(found)
            } catch {
                errorMessage = error.localizedDescription
                isLoading = false
            }
        }
    }
}

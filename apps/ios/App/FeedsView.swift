import RecipeKit
import SwiftUI
import WebKit

struct FeedEntryPreview: View {
    @EnvironmentObject private var library: RecipeLibrary
    @EnvironmentObject private var loader: FeedLoader
    @AppStorage(AppSettings.Key.feedMarkViewed) private var markMode = FeedMarkMode.onClose
    @AppStorage(AppSettings.Key.feedReader) private var opensInReader = true
    let entry: FeedEntry

    @State private var errorMessage: String?
    @StateObject private var earlyPlayer = YouTubePlayerController()
    /// A video's recipe waits for this, so a video being watched hands its place to the recipe page's player.
    @State private var showsRecipe = false
    @State private var resumeAt: Int?

    private var videoID: String? { YouTubeImporter.videoID(from: entry.link) }

    var body: some View {
        Group {
            if let result = loader.results[entry.id], showsRecipe || videoID == nil {
                RecipeDetailView(recipe: result.recipe, previewSave: {
                    Task {
                        guard let saved = await library.add(result) else { return }
                        ToastCenter.shared.show("Added \(saved.title) to My Recipes") { await library.delete(saved) }
                    }
                }, previewImage: result.imageData, previewSaveTitle: "Add to My Recipes", previewSaved: isSaved(result.recipe),
                   resumesVideoAt: resumeAt)
                .transition(.opacity)
            } else if errorMessage != nil {
                if VideoRecipeFinder.isVideo(entry.link) {
                    VideoWithoutRecipe(entry: entry)
                } else if opensInReader {
                    ArticleReader(entry: entry)
                } else {
                    WebView(url: entry.link)
                        .navigationTitle(entry.title)
                        #if os(iOS)
                        .navigationBarTitleDisplayMode(.inline)
                        #endif
                        .toolbar {
                            ToolbarItem(placement: .primaryAction) {
                                Link(destination: entry.link) { Label("Open in Browser", systemImage: "safari") }
                            }
                        }
                }
            } else if let videoID {
                VideoWhileReading(entry: entry, videoID: videoID, controller: earlyPlayer)
            } else {
                RecipeDetailSkeleton(hasPhoto: entry.imageURL != nil)
            }
        }
        .animation(.recipeArrives, value: loader.results[entry.id] != nil)
        .animation(.recipeArrives, value: showsRecipe)
        .onChange(of: loader.results[entry.id] != nil, initial: true) { _, found in
            guard found, !showsRecipe else { return }
            Task {
                resumeAt = await earlyPlayer.currentSeconds()
                earlyPlayer.pause()
                showsRecipe = true
            }
        }
        .task(id: entry.id) {
            errorMessage = nil
            do { try await loader.loadRecipe(for: entry) } catch { errorMessage = error.localizedDescription }
        }
        .onAppear {
            loader.opened(entry)
            if markMode == .onOpen { loader.markViewed([entry.id]) }
        }
        .onDisappear(perform: closed)
    }

    private func closed() {
        guard markMode == .onClose, !loader.isViewed(entry), !loader.keptNew.contains(entry.id) else { return }
        let id = entry.id
        loader.markViewed([id])
        ToastCenter.shared.show("Marked as viewed") { loader.markNew([id]) }
    }

    private func isSaved(_ recipe: Recipe) -> Bool {
        let source = recipe.sourceURL ?? entry.link.absoluteString
        return library.recipes.contains { $0.sourceURL == source }
    }
}

/// A video opened before its recipe is read: the player right away, ready to watch, above the page still loading.
private struct VideoWhileReading: View {
    let entry: FeedEntry
    let videoID: String
    @ObservedObject var controller: YouTubePlayerController

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                YouTubeEmbed(recipe: Recipe(title: entry.title, sourceURL: entry.link.absoluteString), videoID: videoID, controller: controller)
                Label("Reading the recipe from the video…", systemImage: "sparkles")
                    .appFont(.subheadline)
                    .foregroundStyle(.secondary)
                RecipeDetailSkeleton(hasPhoto: false)
                    .frame(height: 600)
                    .allowsHitTesting(false)
            }
            .padding(.horizontal)
        }
        .navigationTitle(entry.title)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }
}

/// A video whose recipe isn't written down anywhere the app can read yet: watch it, or save it to find the recipe later.
private struct VideoWithoutRecipe: View {
    @EnvironmentObject private var library: RecipeLibrary
    let entry: FeedEntry

    var body: some View {
        VStack(spacing: 0) {
            WebView(url: entry.link)
            HStack(spacing: 12) {
                Image(systemName: "sparkles").foregroundStyle(Theme.accent)
                Text("No recipe in this video's description yet.").appFont(.subheadline)
                Spacer(minLength: 4)
                Button("Find Later") {
                    Task { await VideoRecipeFinder.saveForLater(title: entry.title, link: entry.link, imageURL: entry.imageURL, library: library) }
                }
                .buttonStyle(.borderedProminent)
                .tint(Theme.accent)
            }
            .padding(14)
            .background(.bar)
        }
        .navigationTitle(entry.title)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }
}

struct AddFeedSheet: View {
    @EnvironmentObject private var library: RecipeLibrary
    @SheetDismiss private var dismiss
    @State private var source = Source.site

    enum Source: String, CaseIterable {
        case site = "Site or Feed", youtube = "YouTube"
    }

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
                Picker("Source", selection: $source) {
                    ForEach(Source.allCases, id: \.self) { Text($0.rawValue) }
                }
                .pickerStyle(.segmented)
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())
                if source == .youtube {
                    YouTubeChannelSearch()
                } else {
                Section {
                    TextField("https://", text: $address)
                        #if os(iOS)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        #endif
                        .onSubmit(subscribe)
                } footer: {
                    Text("Enter a recipe blog's address, its RSS feed, a YouTube channel, or a subreddit like r/recipes.")
                }
                if let errorMessage { Text(errorMessage).foregroundStyle(.red) }
                Section {
                    Button("Preview Feed") { find { preview = FoundFeed(url: $0.url.absoluteString, title: $0.title) } }
                        .disabled(address.isEmpty || isLoading)
                }
                }
            }
            .navigationDestination(item: $preview) { found in
                FeedPreviewPage(url: found.url, title: found.title, onFollow: { dismiss() })
            }
            .formStyle(.grouped)
            .panelTitle("Add Feed")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { CancelButton() }
                ToolbarItem(placement: .confirmationAction) {
                    if source == .youtube {
                        ConfirmButton(title: "Done") { dismiss() }
                    } else if isLoading { ProgressView().controlSize(.small) } else {
                        ConfirmButton(title: "Subscribe", isDisabled: address.isEmpty, action: subscribe)
                    }
                }
            }
        }
        #if os(macOS)
        .sheetFrame(minWidth: 460, minHeight: 220)
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
        if let subreddit = FeedService.subreddit(text) { text = subreddit.url.absoluteString }
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

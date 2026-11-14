import RecipeKit
import SwiftUI

/// Search YouTube for cooking channels by name and follow them as feeds.
struct YouTubeChannelSearch: View {
    @State private var query = ""
    @State private var results: [YouTubeChannel] = []
    @State private var isSearching = false
    @State private var errorMessage: String?
    @State private var searched = false

    var body: some View {
        Section {
            HStack {
                Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                TextField("Channel name, like Pasta Grannies", text: $query)
                    #if os(iOS)
                    .textInputAutocapitalization(.words)
                    .submitLabel(.search)
                    #endif
                    .autocorrectionDisabled()
                    .onSubmit(search)
                if isSearching { ProgressView().controlSize(.small) }
            }
        } footer: {
            Text("Their newest videos show up in Feeds. Tap one to read its recipe, or save it to find the recipe later.")
        }
        if let errorMessage { Text(errorMessage).foregroundStyle(.red) }
        if !results.isEmpty {
            Section("Channels") {
                ForEach(results) { channel in
                    HStack(spacing: 12) {
                        AsyncImage(url: channel.thumbnailURL) { image in
                            image.resizable().scaledToFill()
                        } placeholder: {
                            Color.secondary.opacity(0.15).overlay(Image(systemName: "play.rectangle").foregroundStyle(.secondary))
                        }
                        .frame(width: 44, height: 44)
                        .clipShape(Circle())
                        VStack(alignment: .leading, spacing: 2) {
                            Text(channel.title).lineLimit(1)
                            if !channel.detail.isEmpty {
                                Text(channel.detail).appFont(.caption).foregroundStyle(.secondary).lineLimit(1)
                            }
                        }
                        Spacer()
                        FollowFeedButton(url: channel.feedURL.absoluteString, title: channel.title)
                    }
                }
            }
        } else if searched, !isSearching, errorMessage == nil {
            Text("No channels found.").foregroundStyle(.secondary)
        }
    }

    private func search() {
        let text = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !isSearching else { return }
        isSearching = true
        errorMessage = nil
        Task {
            do {
                results = try await YouTubeChannels.search(text)
            } catch {
                results = []
                errorMessage = error.localizedDescription
            }
            searched = true
            isSearching = false
        }
    }
}

/// Saves a video as an idea right away, then looks for its recipe in the background and fills the idea in when it finds one.
@MainActor
enum VideoRecipeFinder {
    static func isVideo(_ link: URL) -> Bool { YouTubeImporter.videoID(from: link) != nil }

    static func saveForLater(title: String, link: URL, imageURL: URL?, library: RecipeLibrary) async {
        let address = link.absoluteString
        if let existing = library.recipes.first(where: { $0.sourceURL == address }) {
            ToastCenter.shared.show("“\(existing.title)” is already in My Recipes", symbol: "checkmark.circle.fill")
            return
        }
        let idea = Recipe(title: title, sourceURL: address)
        let photo = await RecipeImageProcessing.download(imageURL?.absoluteString)
        await library.save(idea, image: photo.map(ImageChange.set) ?? .unchanged)
        ToastCenter.shared.show("Saved “\(title)”. Looking for its recipe…", symbol: "play.rectangle.fill") { await library.delete(idea) }
        Task { await findRecipe(for: idea, in: library, quietly: true) }
    }

    /// Writes the video's recipe into the idea, keeping its ID, favorite and tags. Returns whether one was found.
    @discardableResult
    static func findRecipe(for idea: Recipe, in library: RecipeLibrary, quietly: Bool = false) async -> Bool {
        guard let address = idea.sourceURL, let url = URL(string: address),
              let result = try? await YouTubeImporter.importResult(from: url),
              !result.recipe.ingredients.isEmpty || !result.recipe.steps.isEmpty,
              let current = library.recipe(id: idea.id), current.isIdea else {
            if !quietly { ToastCenter.shared.show("Couldn't find a recipe in that video yet", symbol: "exclamationmark.circle.fill") }
            return false
        }
        var recipe = result.recipe
        recipe.id = current.id
        recipe.createdAt = current.createdAt
        recipe.isFavorite = current.isFavorite
        recipe.rating = current.rating
        recipe.wantToCook = current.wantToCook
        recipe.queuedAt = current.queuedAt
        recipe.tags = Array(Set(current.tags + recipe.tags)).sorted()
        await library.save(recipe, image: result.imageData.map(ImageChange.set) ?? .unchanged)
        ToastCenter.shared.show("Found the recipe for “\(recipe.title)”", symbol: "sparkles") { await library.save(current) }
        return true
    }
}

extension Feed {
    var isYouTube: Bool { url.contains("youtube.com/feeds/") }
    var symbol: String {
        if isYouTube { return "play.rectangle" }
        if url.contains("reddit.com") { return "bubble.left.and.bubble.right" }
        return "dot.radiowaves.up.forward"
    }
}

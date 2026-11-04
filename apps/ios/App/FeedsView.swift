import RecipeKit
import SwiftUI

struct FeedEntryPreview: View {
    @EnvironmentObject private var library: RecipeLibrary
    @EnvironmentObject private var loader: FeedLoader
    let entry: FeedEntry

    @State private var errorMessage: String?
    @State private var browsing = false

    var body: some View {
        Group {
            if let result = loader.results[entry.id] {
                RecipeDetailView(recipe: result.recipe, previewSave: {
                    Task {
                        guard let saved = await library.add(result) else { return }
                        ToastCenter.shared.show("Added \(saved.title) to My Recipes") { await library.delete(saved) }
                    }
                }, previewImage: result.imageData, previewSaveTitle: "Add to My Recipes", previewSaved: isSaved(result.recipe))
                .transition(.opacity)
            } else if let errorMessage {
                ContentUnavailableView {
                    Label("No recipe found", systemImage: "fork.knife")
                } description: {
                    Text(errorMessage)
                } actions: {
                    #if os(iOS)
                    Button("View the Page") { browsing = true }
                    #else
                    Link("Open in Browser", destination: entry.link)
                    #endif
                }
            } else {
                RecipeDetailSkeleton(hasPhoto: entry.imageURL != nil)
            }
        }
        .animation(.recipeArrives, value: loader.results[entry.id] != nil)
        #if os(iOS)
        .sheet(isPresented: $browsing) { SafariView(url: entry.link).ignoresSafeArea() }
        #endif
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
                    Text("Enter a recipe blog's address, its RSS feed, or a YouTube channel.")
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

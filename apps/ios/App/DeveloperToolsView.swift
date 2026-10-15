import RecipeKit
import SwiftUI

/// Fills the library with recipes from many places so every import path and layout can be tried quickly.
struct DeveloperToolsView: View {
    struct Source: Identifiable {
        let name: String
        let site: String
        let url: String
        var id: String { url }
    }

    enum Status: Equatable {
        case running
        case saved(String)
        case failed(String)
    }

    static let sources: [Source] = [
        Source(name: "Best Chocolate Chip Cookies", site: "AllRecipes", url: "https://www.allrecipes.com/recipe/10813/best-chocolate-chip-cookies/"),
        Source(name: "Easy Meatloaf", site: "AllRecipes", url: "https://www.allrecipes.com/recipe/16354/easy-meatloaf/"),
        Source(name: "World's Best Lasagna", site: "AllRecipes", url: "https://www.allrecipes.com/recipe/23600/worlds-best-lasagna/"),
        Source(name: "Chewy Chocolate Chip Cookies", site: "Tasty", url: "https://tasty.co/recipe/the-best-chewy-chocolate-chip-cookies"),
        Source(name: "Slow-Cooked Bolognese", site: "Serious Eats", url: "https://www.seriouseats.com/the-best-slow-cooked-bolognese-sauce-recipe"),
        Source(name: "Easy Pancakes", site: "BBC Good Food", url: "https://www.bbcgoodfood.com/recipes/easy-pancakes"),
        Source(name: "Perfect Guacamole", site: "Simply Recipes", url: "https://www.simplyrecipes.com/recipes/perfect_guacamole/"),
        Source(name: "Baked Macaroni and Cheese", site: "Food Network", url: "https://www.foodnetwork.com/recipes/alton-brown/baked-macaroni-and-cheese-recipe-1939524"),
        Source(name: "White Chocolate Chip Cookies", site: "YouTube · Preppy Kitchen", url: "https://www.youtube.com/watch?v=jVQhsTjjKKY"),
        Source(name: "Classic Chocolate Chip Cookies", site: "YouTube", url: "https://www.youtube.com/watch?v=loqCY9b7aec"),
        Source(name: "Perfect Scrambled Eggs", site: "YouTube · Gordon Ramsay", url: "https://www.youtube.com/watch?v=VhJFyyukAzA"),
        Source(name: "Sourdough Bread", site: "YouTube · Babish", url: "https://www.youtube.com/watch?v=bSYdABrPrtM"),
        Source(name: "A video with no recipe", site: "YouTube · opens the review step", url: "https://www.youtube.com/watch?v=dQw4w9WgXcQ"),
    ]

    @EnvironmentObject private var library: RecipeLibrary
    @State private var statuses: [String: Status] = [:]
    @State private var isImportingAll = false
    @State private var addedSamples = false

    var body: some View {
        Form {
            Section {
                Button { addSamples() } label: { Label("Add Sample Recipes, Plan and Groceries", systemImage: "square.stack.3d.up") }
                    .sensoryFeedback(.success, trigger: addedSamples)
            } header: {
                Text("Built-in samples")
            } footer: {
                Text("Seven recipes with photos and step photos, a week of planned meals, and a grocery list. Adding them again replaces them rather than duplicating.")
            }
            Section {
                Button { importAll() } label: {
                    Label(isImportingAll ? "Importing…" : "Import All \(Self.sources.count) from the Web", systemImage: "arrow.down.circle")
                }
                .disabled(isImportingAll)
                ForEach(Self.sources) { source in
                    Button { Task { await `import`(source) } } label: { row(source) }
                        .buttonStyle(.plain)
                        .disabled(isImportingAll)
                }
            } header: {
                Text("Import from real sites")
            } footer: {
                Text("Uses the same importer as Import from Web or YouTube, and saves each recipe straight to your library. Needs a network connection, and YouTube imports can take a while.")
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Developer Tools")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }

    private func row(_ source: Source) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(source.name)
                Text(source.site).font(.caption).foregroundStyle(.secondary)
                if case .failed(let message) = statuses[source.id] {
                    Text(message).font(.caption).foregroundStyle(.red).lineLimit(2)
                }
            }
            Spacer()
            switch statuses[source.id] {
            case .running: ProgressView().controlSize(.small)
            case .saved: Image(systemName: "checkmark.circle.fill").foregroundStyle(Theme.accent)
            case .failed: Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
            case nil: Image(systemName: "plus.circle").foregroundStyle(.secondary)
            }
        }
        .contentShape(Rectangle())
        .animation(.snappy, value: statuses[source.id])
    }

    private func addSamples() {
        Task {
            await library.addSamples(
                recipes: SampleData.recipes, images: SampleData.images, stepImages: SampleData.stepImages,
                plan: SampleData.mealPlan, groceries: SampleData.groceries
            )
            addedSamples.toggle()
        }
    }

    private func importAll() {
        isImportingAll = true
        Task {
            for source in Self.sources { await `import`(source) }
            isImportingAll = false
        }
    }

    private func `import`(_ source: Source) async {
        guard let url = URL(string: source.url) else { return }
        statuses[source.id] = .running
        do {
            let result = try await RecipeImporter.importResult(from: url)
            if let saved = await library.add(result) {
                statuses[source.id] = .saved(saved.title)
            } else {
                statuses[source.id] = .failed("Couldn't save the recipe.")
            }
        } catch {
            statuses[source.id] = .failed(error.localizedDescription)
        }
    }
}

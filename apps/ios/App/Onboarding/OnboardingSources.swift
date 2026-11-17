import Foundation
import RecipeKit

/// A real recipe page or video the tour offers to import.
struct OnboardingSource: Identifiable {
    enum Kind { case web, video }

    let title: String
    let site: String
    let detail: String
    let url: URL
    let kind: Kind

    var id: String { url.absoluteString }

    /// Whether `recipe` was imported from this source; videos match by id because the saved link is normalized.
    func matches(_ recipe: Recipe) -> Bool {
        guard let saved = recipe.sourceURL.flatMap(URL.init(string:)) else { return false }
        if let video = YouTubeImporter.videoID(from: url) { return YouTubeImporter.videoID(from: saved) == video }
        return saved.absoluteString == url.absoluteString
    }
}

enum OnboardingSources {
    static let all = [
        OnboardingSource(
            title: "World's Best Lasagna", site: "AllRecipes",
            detail: "A recipe page: the ingredients, steps and photo come across together.",
            url: URL(string: "https://www.allrecipes.com/recipe/23600/worlds-best-lasagna/")!, kind: .web
        ),
        OnboardingSource(
            title: "Easy Pancakes", site: "BBC Good Food",
            detail: "Most recipe sites work the same way.",
            url: URL(string: "https://www.bbcgoodfood.com/recipes/easy-pancakes")!, kind: .web
        ),
        OnboardingSource(
            title: "White Chocolate Chip Cookies", site: "YouTube · Preppy Kitchen",
            detail: "A video: the recipe is read from its description, and the video plays on the recipe page.",
            url: URL(string: "https://www.youtube.com/watch?v=jVQhsTjjKKY")!, kind: .video
        ),
        OnboardingSource(
            title: "Perfect Scrambled Eggs", site: "YouTube · Gordon Ramsay",
            detail: "Tap a step's time to jump to that moment in the video.",
            url: URL(string: "https://www.youtube.com/watch?v=VhJFyyukAzA")!, kind: .video
        ),
    ]
}

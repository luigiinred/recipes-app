import Foundation
import Testing
@testable import RecipeKit

struct PagePreviewTests {
    private let url = URL(string: "https://example.com/recipes/soup")!

    @Test func readsTheRecipePhotoAndTime() {
        let html = """
        <html><head><script type="application/ld+json">
        {"@type": "Recipe", "name": "Soup", "image": "/img/soup.jpg", "prepTime": "PT10M", "cookTime": "PT25M",
         "recipeIngredient": ["1 onion"], "recipeInstructions": ["Cook."]}
        </script></head></html>
        """
        let preview = PagePreview(html: html, url: url)
        #expect(preview.isRecipe)
        #expect(preview.minutes == 35)
        #expect(preview.imageURL?.absoluteString == "https://example.com/img/soup.jpg")
    }

    @Test func fallsBackToTheSharePhoto() {
        let html = #"<html><head><meta property="og:image" content="https://cdn.example.com/a.jpg"></head></html>"#
        let preview = PagePreview(html: html, url: url)
        #expect(!preview.isRecipe)
        #expect(preview.minutes == nil)
        #expect(preview.imageURL?.absoluteString == "https://cdn.example.com/a.jpg")
    }
}

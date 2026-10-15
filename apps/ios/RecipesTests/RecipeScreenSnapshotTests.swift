import RecipeKit
import SwiftUI
import Testing
@testable import Recipes

@Suite("Recipe screens", .serialized)
@MainActor
struct RecipeScreenSnapshotTests {
    @Test("recipe reader with a photo: ingredients and steps side by side when wide")
    func detail() {
        assertPageSnapshots(of: RecipeDetailView(recipe: SampleData.shakshuka), coverage: .adaptive)
    }

    @Test("YouTube recipe: inline player poster and step timestamps")
    func detailVideo() {
        assertPageSnapshots(of: RecipeDetailView(recipe: SampleData.videoRecipe), coverage: .adaptive)
    }

    @Test("recipe reader with star ratings and step photos")
    func detailStars() {
        SampleData.defaults.set(RatingStyle.stars.rawValue, forKey: AppSettings.Key.ratingStyle)
        defer { SampleData.defaults.removeObject(forKey: AppSettings.Key.ratingStyle) }
        assertPageSnapshots(of: RecipeDetailView(recipe: SampleData.shakshuka))
    }

    @Test("recipe reader without a photo")
    func detailWithoutPhoto() {
        assertPageSnapshots(of: RecipeDetailView(recipe: SampleData.soup))
    }

    @Test("add ingredients to groceries")
    func addToGroceries() {
        assertPageSnapshots(of: AddToGroceriesSheet(recipe: SampleData.chili), inNavigationStack: false, macSize: SnapshotEnvironment.macSheetSize, coverage: .sheet)
    }

    @Test("add to calendar")
    func addToCalendar() {
        assertPageSnapshots(of: AddToCalendarSheet(recipe: SampleData.chili), inNavigationStack: false, macSize: SnapshotEnvironment.macSheetSize, coverage: .sheet)
    }

    @Test("pick a recipe for a day")
    func pickRecipe() {
        assertPageSnapshots(of: AddMealSheet(day: SampleData.now), inNavigationStack: false, macSize: SnapshotEnvironment.macSheetSize, coverage: .sheet)
    }

    @Test("import from web")
    func importFromWeb() {
        assertPageSnapshots(of: ImportURLView(onReview: { _ in }), inNavigationStack: false, macSize: SnapshotEnvironment.macSheetSize, coverage: .sheet)
    }
}

import RecipeKit
import SwiftUI
import Testing
@testable import Recipes

@Suite("App screens", .serialized)
@MainActor
struct AppScreenSnapshotTests {
    #if os(iOS)
    @Test("Recipes tab")
    func recipesTab() {
        assertPageSnapshots(of: RootView(tab: .recipes), inNavigationStack: false, coverage: .adaptive)
    }

    @Test("iPad: Recipes home as a grid of collections and categories")
    func iPadRecipesHome() {
        assertPageSnapshots(of: RootView(tab: .recipes), inNavigationStack: false, coverage: .iPad)
    }

    @Test("iPad: a category's recipes as a grid")
    func iPadCategoryGrid() {
        assertPageSnapshots(of: RootView(tab: .recipes, recipesCollection: .category("Dinner")), inNavigationStack: false, coverage: .iPad)
    }

    @Test("iPad: a category holding recipes shows photo cards")
    func iPadRecipeCards() {
        assertPageSnapshots(of: RootView(tab: .recipes, recipesCollection: .category("Dinner/Mains")), inNavigationStack: false, coverage: .iPad)
    }

    @Test("iPad: a recipe opened full screen from its category")
    func iPadRecipeSelected() {
        assertPageSnapshots(
            of: RootView(tab: .recipes, recipeSelection: SampleData.chili.id, recipesCollection: .category("Dinner")),
            inNavigationStack: false, coverage: .iPad
        )
    }

    @Test("iPad: Plan, My Week")
    func iPadPlan() {
        assertPageSnapshots(of: RootView(tab: .plan, planMode: .week), inNavigationStack: false, coverage: .iPad)
    }

    @Test("Search tab, with results")
    func searchTab() {
        assertPageSnapshots(of: RootView(tab: .search, searchQuery: "tomato"), inNavigationStack: false)
    }

    @Test("Plan tab: Up Next queue")
    func planQueue() {
        assertPageSnapshots(of: RootView(tab: .plan), inNavigationStack: false)
    }

    @Test("Plan tab: My Week")
    func planWeek() {
        assertPageSnapshots(of: RootView(tab: .plan, planMode: .week), inNavigationStack: false, coverage: .adaptive)
    }

    @Test("Plan tab: smart plan sheet over My Week")
    func planSmart() {
        assertPageSnapshots(of: RootView(tab: .plan, planMode: .week, showsSmartPlan: true), inNavigationStack: false)
    }

    @Test("Groceries tab")
    func groceriesTab() {
        assertPageSnapshots(of: RootView(tab: .groceries), inNavigationStack: false)
    }
    #else
    @Test("Recipes: all, with a recipe open")
    func recipes() {
        assertPageSnapshots(of: RootView(section: .recipes(.all), selection: SampleData.shakshuka.id), inNavigationStack: false)
    }

    @Test("Plan: Up Next with a recipe open")
    func planQueue() {
        assertPageSnapshots(of: RootView(section: .plan, selection: SampleData.chili.id), inNavigationStack: false)
    }

    @Test("Plan: My Week")
    func planWeek() {
        assertPageSnapshots(of: RootView(section: .plan, planMode: .week), inNavigationStack: false)
    }

    @Test("Groceries")
    func groceries() {
        assertPageSnapshots(of: RootView(section: .groceries), inNavigationStack: false)
    }

    #endif
}

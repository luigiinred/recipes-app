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

    @Test("Search tab, with results")
    func searchTab() {
        assertPageSnapshots(of: RootView(tab: .search, searchQuery: "tomato"), inNavigationStack: false)
    }

    @Test("Calendar tab: month dots over the agenda")
    func calendarTab() {
        assertPageSnapshots(of: RootView(tab: .calendar), inNavigationStack: false)
    }

    @Test("Calendar tab: weekly planner")
    func calendarPlanner() {
        assertPageSnapshots(
            of: RootView(tab: .calendar, calendarMode: .planner),
            inNavigationStack: false, coverage: .adaptive
        )
    }

    @Test("Calendar tab: add sheet with search, open over the planner")
    func calendarAddSheet() {
        assertPageSnapshots(of: RootView(tab: .calendar, calendarMode: .planner, showsAddSheet: true), inNavigationStack: false)
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

    @Test("Calendar")
    func calendar() {
        assertPageSnapshots(of: RootView(section: .calendar, selection: SampleData.chili.id), inNavigationStack: false)
    }

    @Test("Calendar: weekly planner, recipe drawer on the left")
    func planner() {
        assertPageSnapshots(of: RootView(section: .calendar, calendarMode: .planner), inNavigationStack: false)
    }

    @Test("Groceries")
    func groceries() {
        assertPageSnapshots(of: RootView(section: .groceries), inNavigationStack: false)
    }

    #endif
}

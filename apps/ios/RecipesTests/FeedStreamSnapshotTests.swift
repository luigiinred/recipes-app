import RecipeKit
import SnapshotTesting
import SwiftUI
import XCTest
@testable import Recipes

@MainActor
final class FeedStreamSnapshotTests: XCTestCase {
    func testStream() {
        assertPageSnapshots(of: FeedStreamView(), coverage: .adaptive)
    }

    func testNoFeeds() {
        assertPageSnapshots(of: FeedStreamView().environmentObject(RecipeLibrary(recipes: [])))
    }

    func testFeedPreview() {
        assertPageSnapshots(of: FeedPreviewPage(url: SampleData.feeds[0].url, title: "Simply Recipes", seed: SampleData.feedEntries))
    }

    func testPostAsRecipe() {
        assertPageSnapshots(of: FeedEntryPreview(entry: SampleData.feedEntries[0]))
    }

    #if os(iOS)
    func testHomeShelf() {
        assertPageSnapshots(of: RootView(tab: .recipes), inNavigationStack: false, coverage: .adaptive)
    }
    #endif

    func testDiscover() {
        assertPageSnapshots(of: FeedDiscoverPage())
    }

    func testRecipeLoading() {
        assertPageSnapshots(of: RecipeDetailSkeleton(), coverage: .sheet)
    }

    func testFeedsPage() {
        assertPageSnapshots(of: RecipeFeedsPage(), coverage: .sheet)
    }
}

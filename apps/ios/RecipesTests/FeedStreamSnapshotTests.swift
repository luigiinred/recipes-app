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

    func testHomeShelf() {
        let defaults = UserDefaults(suiteName: "FeedsHomeShelf")!
        defaults.set(true, forKey: AppSettings.Key.feedsTab)
        assertPageSnapshots(of: RootView(tab: .recipes).defaultAppStorage(defaults), inNavigationStack: false, coverage: .adaptive)
    }

    func testFeedsPage() {
        assertPageSnapshots(of: RecipeFeedsPage(), coverage: .sheet)
    }
}

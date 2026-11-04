import RecipeKit
import SnapshotTesting
import SwiftUI
import XCTest
@testable import Recipes

@MainActor
final class DiscoverSnapshotTests: XCTestCase {
    func testStream() {
        assertPageSnapshots(of: DiscoverView(), coverage: .adaptive)
    }

    func testNoFeeds() {
        assertPageSnapshots(of: DiscoverView().environmentObject(RecipeLibrary(recipes: [])))
    }

    func testFeedPreview() {
        assertPageSnapshots(of: FeedPreviewPage(url: SampleData.feeds[0].url, title: "Simply Recipes", seed: SampleData.feedEntries))
    }

    func testPostAsRecipe() {
        assertPageSnapshots(of: FeedEntryPreview(entry: SampleData.feedEntries[0]))
    }

    func testHomeShelf() {
        let defaults = UserDefaults(suiteName: "DiscoverHomeShelf")!
        defaults.set(true, forKey: AppSettings.Key.discoverTab)
        assertPageSnapshots(of: RootView(tab: .recipes).defaultAppStorage(defaults), inNavigationStack: false, coverage: .adaptive)
    }

    func testFeedsPage() {
        assertPageSnapshots(of: DiscoverFeedsPage(), coverage: .sheet)
    }
}

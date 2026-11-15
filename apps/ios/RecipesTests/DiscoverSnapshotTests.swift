import SwiftUI
import Testing
@testable import Recipes

@Suite("Discover", .serialized)
@MainActor
struct DiscoverSnapshotTests {
    #if os(iOS)
    @Test("recipes home lists Discover under the collections")
    func home() {
        assertPageSnapshots(of: RecipesHomeView(selection: .constant(nil)).environment(HomeBrowsing()).environmentObject(SampleData.discover()))
    }

    @Test("iPad recipes home has a Discover tile and sidebar row")
    func iPadHome() {
        assertPageSnapshots(of: RootView(tab: .recipes).environmentObject(SampleData.discover()), inNavigationStack: false, coverage: .iPad)
    }

    @Test("a category on the shared server")
    func category() {
        assertPageSnapshots(of: page(.collection(.category("Dinner"))))
    }
    #endif

    @Test("the shared server's recipes, read-only")
    func serverHome() {
        assertPageSnapshots(of: page(.home))
    }

    @Test("a shared recipe offers to add it to yours")
    func recipe() {
        assertPageSnapshots(of: page(.recipe(SampleData.chili.id)))
    }

    @Test("Mealie settings list the Discover servers")
    func settings() {
        assertPageSnapshots(
            of: MealieSettingsPage().environmentObject(SampleData.discover()),
            macSize: SnapshotEnvironment.macSheetSize, coverage: .sheet
        )
    }

    @Test("Mealie sharing offers three links and lists the servers")
    func sharing() {
        let mealie = MealieSyncController(previewing: .idle, address: "https://mealie.example.com", username: "timmy")
        assertPageSnapshots(
            of: MealieSharingPage().environmentObject(mealie).environmentObject(SampleData.discover()),
            macSize: SnapshotEnvironment.macSheetSize, coverage: .sheet
        )
    }

    #if os(iOS)
    @Test("a library search also shows matches on Mealie servers")
    func search() {
        assertPageSnapshots(
            of: RecipesHomeView(selection: .constant(nil), query: "chili", showsQuickFilters: true)
                .environment(HomeBrowsing())
                .environmentObject(SampleData.discover())
        )
    }

    @Test("the Discover tab lists Mealie servers")
    func discoverTab() {
        assertPageSnapshots(of: FeedStreamView().environmentObject(SampleData.discover()))
    }
    #endif

    private func page(_ route: DiscoverRoute) -> some View {
        DiscoverPage(sourceID: SampleData.discoverSource.id, route: route) { _ in }.environmentObject(SampleData.discover())
    }
}

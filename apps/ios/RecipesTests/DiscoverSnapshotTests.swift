import RecipeKit
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

    @Test("Add Server asks only for an address, with the token optional")
    func addServer() {
        assertPageSnapshots(of: AddDiscoverSheet().environmentObject(SampleData.discover()), inNavigationStack: false, coverage: .sheet)
    }

    @Test("each share link says what it gives and can be sent, copied or opened here", arguments: MealieLink.Kind.shareable)
    func shareLink(_ kind: MealieLink.Kind) {
        let link = MealieLink(server: URL(string: "https://mealie.example.com")!, token: "sample-token", kind: kind)
        assertPageSnapshots(of: MealieShareLinkSheet(link: link), named: kind.rawValue, inNavigationStack: false, coverage: .sheet)
    }

    @Test("an invite link asks for the new user's account")
    func join() {
        let link = MealieLink(server: URL(string: "https://mealie.example.com")!, token: "invite", kind: .invite)
        assertPageSnapshots(of: JoinMealieSheet(link: link), inNavigationStack: false, coverage: .sheet)
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

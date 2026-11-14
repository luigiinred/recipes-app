import Testing
@testable import Recipes

struct FeatureFlagTests {
    @Test("a top-level flag has no parent, and every source flag sits under Discover Search")
    func parents() {
        #expect(FeatureFlag.discoverSearch.parent == nil)
        #expect(FeatureFlag.allCases.filter { $0 != .discoverSearch }.allSatisfy { $0.parent == .discoverSearch })
        #expect(!FeatureFlag.discoverSearch.defaultValue)
    }
}

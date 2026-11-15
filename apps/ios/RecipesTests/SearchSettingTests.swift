import Foundation
import Testing
@testable import Recipes

@Suite(.serialized)
struct SearchSettingTests {
    @Test("every source sits under online search, and all are on until switched off")
    func onByDefault() {
        #expect(SearchSetting.discoverSearch.parent == nil)
        let nested = SearchSetting.allCases.filter { $0 != .discoverSearch }.allSatisfy { $0.parent == .discoverSearch }
        #expect(nested)
        let defaults = UserDefaults.standard
        let saved = SearchSetting.allCases.map { defaults.object(forKey: $0.key) }
        defer { for (setting, value) in zip(SearchSetting.allCases, saved) { defaults.set(value, forKey: setting.key) } }
        for setting in SearchSetting.allCases { defaults.removeObject(forKey: setting.key) }
        let allOn = SearchSetting.allCases.allSatisfy { $0.isOn }
        #expect(allOn)
        defaults.set(false, forKey: SearchSetting.discoverSearch.key)
        #expect(!SearchSetting.searchYouTube.isOn)
    }
}

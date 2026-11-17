import Foundation
import Testing
@testable import Recipes

@Suite(.serialized)
struct SearchSettingTests {
    @Test("online search is always on, and every source is on until switched off")
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
        #expect(SearchSetting.discoverSearch.isOn)
        #expect(SearchSetting.searchYouTube.isOn)
        defaults.set(false, forKey: SearchSetting.searchYouTube.key)
        #expect(!SearchSetting.searchYouTube.isOn)
    }
}

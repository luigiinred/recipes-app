#if os(iOS) && !SHARE_EXTENSION
import Foundation
import RecipeKit
import WidgetKit

/// Keeps the home screen widgets' copy of the library current.
@MainActor
final class WidgetSync {
    private let store = WidgetStore.shared
    private var published: WidgetSnapshot?

    private static let photoSize = 480

    func publish(recipes: [Recipe], mealPlan: [MealPlanEntry], groceries: [GroceryItem], imageIDs: Set<UUID>, library: Library) async {
        guard let store else { return }
        var snapshot = WidgetSnapshot.make(recipes: recipes, mealPlan: mealPlan, groceries: groceries, imageIDs: imageIDs)
        snapshot.accentHex = UserDefaults.standard.string(forKey: AppSettings.Key.accentColor)
        guard snapshot != published else { return }
        let shown = snapshot
        let saved = await Task.detached {
            let wanted = Set(shown.dishes.filter(\.hasImage).map(\.id))
            for id in wanted where !store.hasImage(for: id) {
                guard let data = library.images.data(for: id), let jpeg = RecipeImageProcessing.jpegData(from: data, maxPixelSize: Self.photoSize) else { continue }
                try? store.saveImage(jpeg, for: id)
            }
            store.pruneImages(keeping: wanted)
            return (try? store.save(shown)) != nil
        }.value
        guard saved else { return }
        published = snapshot
        WidgetCenter.shared.reloadAllTimelines()
    }
}
#endif

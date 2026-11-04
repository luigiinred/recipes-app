#if os(iOS)
import BackgroundTasks
import Foundation
import RecipeKit

/// Refreshes the offline copy of followed feeds while the app is in the background.
enum FeedRefresh {
    /// Must match `BGTaskSchedulerPermittedIdentifiers` in project.yml.
    static let taskID = (Bundle.main.bundleIdentifier ?? "recipes") + ".feeds-refresh"
    static let interval: TimeInterval = 60 * 60

    static func schedule() {
        guard FeedLoader.savesOffline else {
            BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: taskID)
            return
        }
        let request = BGAppRefreshTaskRequest(identifier: taskID)
        request.earliestBeginDate = Date(timeIntervalSinceNow: interval)
        try? BGTaskScheduler.shared.submit(request)
    }

    static func run() async {
        schedule()
        guard FeedLoader.savesOffline else { return }
        let feeds = await Task.detached { (try? RecipeLocation.resolveForApp().library.feeds.list()) ?? [] }.value
        _ = await FeedCache.standard.refresh(feeds)
    }
}
#endif

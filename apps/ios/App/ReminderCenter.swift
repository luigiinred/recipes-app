import Foundation
import RecipeKit
import UserNotifications

/// Schedules the optional reminders and routes taps on any notification, timers included.
@MainActor
final class ReminderCenter {
    static let shared = ReminderCenter()

    private let center = UNUserNotificationCenter.current()
    private let delegate = NotificationDelegate()

    /// Must run at launch so a tap that opens the app is delivered.
    func install() {
        center.delegate = delegate
    }

    var authorization: UNAuthorizationStatus {
        get async { await center.notificationSettings().authorizationStatus }
    }

    func requestAuthorization() async -> Bool {
        (try? await center.requestAuthorization(options: [.alert, .sound])) ?? false
    }

    /// Replaces every pending reminder with the ones the current settings and library call for.
    func reschedule(plan: [MealPlanEntry], recipes: [Recipe]) async {
        let preferences = AppSettings.reminderPreferences()
        let pending = await center.pendingNotificationRequests().map(\.identifier).filter { $0.hasPrefix(ReminderPlanner.idPrefix) }
        center.removePendingNotificationRequests(withIdentifiers: pending)
        guard preferences.anyOn else { return }
        let status = await authorization
        guard status == .authorized || status == .provisional else { return }
        for request in ReminderPlanner.requests(preferences, now: Date(), plan: plan, recipes: recipes) {
            let content = UNMutableNotificationContent()
            content.title = request.title
            content.body = request.body
            content.sound = .default
            content.userInfo = [NotificationDelegate.kindKey: request.kind.rawValue]
            let parts = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: request.fireDate)
            let trigger = UNCalendarNotificationTrigger(dateMatching: parts, repeats: false)
            try? await center.add(UNNotificationRequest(identifier: request.id, content: content, trigger: trigger))
        }
    }
}

final class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    static let kindKey = "reminderKind"
    static let recipeKey = "recipeID"

    func userNotificationCenter(
        _ center: UNUserNotificationCenter, willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse) async {
        let info = response.notification.request.content.userInfo
        let kind = (info[Self.kindKey] as? String).flatMap(ReminderKind.init(rawValue:))
        let recipe = (info[Self.recipeKey] as? String).flatMap(UUID.init(uuidString:))
        await MainActor.run {
            if let kind { AppRouter.shared.reminder = kind }
            if let recipe { AppRouter.shared.cookRecipeID = recipe }
        }
    }
}

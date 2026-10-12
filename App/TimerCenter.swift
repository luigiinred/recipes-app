import Foundation
import UserNotifications

struct CookTimer: Identifiable, Hashable {
    let id: UUID
    var label: String
    let duration: Int
    let endsAt: Date

    init(id: UUID = UUID(), label: String, duration: Int, endsAt: Date) {
        self.id = id
        self.label = label
        self.duration = duration
        self.endsAt = endsAt
    }

    func remaining(at now: Date) -> Int {
        max(0, Int(endsAt.timeIntervalSince(now).rounded(.up)))
    }
}

@MainActor
final class TimerCenter: ObservableObject {
    @Published private(set) var timers: [CookTimer] = []

    init(seed: [CookTimer] = []) {
        timers = seed
    }

    func start(label: String, seconds: Int) {
        let timer = CookTimer(label: label, duration: seconds, endsAt: Date().addingTimeInterval(Double(seconds)))
        timers.append(timer)
        scheduleNotification(for: timer)
    }

    func cancel(_ timer: CookTimer) {
        timers.removeAll { $0.id == timer.id }
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [timer.id.uuidString])
    }

    private func scheduleNotification(for timer: CookTimer) {
        let center = UNUserNotificationCenter.current()
        center.delegate = ForegroundPresenter.shared
        center.requestAuthorization(options: [.alert, .sound]) { granted, _ in
            guard granted else { return }
            let content = UNMutableNotificationContent()
            content.title = "Timer done"
            content.body = timer.label
            content.sound = .default
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(1, Double(timer.duration)), repeats: false)
            center.add(UNNotificationRequest(identifier: timer.id.uuidString, content: content, trigger: trigger))
        }
    }
}

private final class ForegroundPresenter: NSObject, UNUserNotificationCenterDelegate {
    static let shared = ForegroundPresenter()

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }
}

func formatTimer(_ seconds: Int) -> String {
    let h = seconds / 3600, m = (seconds % 3600) / 60, s = seconds % 60
    return h > 0 ? String(format: "%d:%02d:%02d", h, m, s) : String(format: "%d:%02d", m, s)
}

import Foundation
import UserNotifications

struct CookTimer: Identifiable, Hashable, Codable {
    let id: UUID
    var label: String
    var recipeID: UUID?
    let duration: Int
    let endsAt: Date

    init(id: UUID = UUID(), label: String, recipeID: UUID? = nil, duration: Int, endsAt: Date) {
        self.id = id
        self.label = label
        self.recipeID = recipeID
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
    private var alarmBacked: Set<UUID> = []
    private let defaults: UserDefaults?
    private static let storeKey = "cookTimers"

    /// A seeded center is for previews and tests, so it neither restores nor saves.
    init(seed: [CookTimer]? = nil, defaults: UserDefaults = .standard) {
        self.defaults = seed == nil ? defaults : nil
        timers = seed ?? []
        #if os(iOS)
        if seed == nil { Task { await restoreAndFollowAlarms() } }
        #endif
    }

    func start(label: String, recipeID: UUID? = nil, seconds: Int) {
        let timer = CookTimer(label: label, recipeID: recipeID, duration: seconds, endsAt: Date().addingTimeInterval(Double(seconds)))
        timers.append(timer)
        save()
        #if os(iOS)
        Task {
            if await TimerAlarms.schedule(timer) { alarmBacked.insert(timer.id) } else { scheduleNotification(for: timer) }
        }
        #else
        scheduleNotification(for: timer)
        #endif
    }

    func cancel(_ timer: CookTimer) {
        timers.removeAll { $0.id == timer.id }
        alarmBacked.remove(timer.id)
        save()
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [timer.id.uuidString])
        #if os(iOS)
        TimerAlarms.cancel(timer.id)
        #endif
    }

    private func save() {
        guard let defaults else { return }
        defaults.set(try? JSONEncoder().encode(timers), forKey: Self.storeKey)
    }

    #if os(iOS)
    /// Alarms outlive the app, so timers do too; one stopped from the Lock Screen is dropped here.
    private func restoreAndFollowAlarms() async {
        let live = TimerAlarms.current
        let saved = defaults?.data(forKey: Self.storeKey).flatMap { try? JSONDecoder().decode([CookTimer].self, from: $0) } ?? []
        let restored = saved.filter { live.contains($0.id) }
        alarmBacked.formUnion(restored.map(\.id))
        timers = restored + timers
        save()
        for await ids in TimerAlarms.ids {
            let gone = alarmBacked.subtracting(ids)
            guard !gone.isEmpty else { continue }
            alarmBacked.subtract(gone)
            timers.removeAll { gone.contains($0.id) }
            save()
        }
    }
    #endif

    private func scheduleNotification(for timer: CookTimer) {
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert, .sound]) { granted, _ in
            guard granted else { return }
            let content = UNMutableNotificationContent()
            content.title = "Timer done"
            content.body = timer.label
            content.sound = .default
            if let recipeID = timer.recipeID { content.userInfo = [NotificationDelegate.recipeKey: recipeID.uuidString] }
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(1, Double(timer.duration)), repeats: false)
            center.add(UNNotificationRequest(identifier: timer.id.uuidString, content: content, trigger: trigger))
        }
    }
}

func formatTimer(_ seconds: Int) -> String {
    let h = seconds / 3600, m = (seconds % 3600) / 60, s = seconds % 60
    return h > 0 ? String(format: "%d:%02d:%02d", h, m, s) : String(format: "%d:%02d", m, s)
}

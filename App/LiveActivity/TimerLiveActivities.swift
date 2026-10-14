#if os(iOS)
import ActivityKit
import Foundation

/// Mirrors each cook timer as a Live Activity on the Lock Screen and in the Dynamic Island.
@MainActor
enum TimerLiveActivities {
    private static var running: [UUID: Activity<TimerActivityAttributes>] = [:]
    private static let lingerAfterDone: TimeInterval = 300

    static func start(_ timer: CookTimer) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        let attributes = TimerActivityAttributes(label: timer.label, startedAt: timer.endsAt.addingTimeInterval(-Double(timer.duration)))
        let content = ActivityContent(state: TimerActivityAttributes.ContentState(endsAt: timer.endsAt), staleDate: timer.endsAt)
        guard let activity = try? Activity.request(attributes: attributes, content: content, pushType: nil) else { return }
        running[timer.id] = activity
        let id = timer.id
        Task {
            try? await Task.sleep(for: .seconds(Double(timer.duration) + lingerAfterDone))
            await end(id)
        }
    }

    static func end(_ id: UUID) async {
        guard let activity = running.removeValue(forKey: id) else { return }
        await activity.end(nil, dismissalPolicy: .immediate)
    }

    /// Timers don't survive a relaunch, so activities left over from a previous run are dismissed.
    static func endAll() async {
        running = [:]
        for activity in Activity<TimerActivityAttributes>.activities {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
    }
}
#endif

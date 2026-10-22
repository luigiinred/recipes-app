#if os(iOS)
import AlarmKit
import AppIntents
import SwiftUI

/// Cook timers run as AlarmKit timers, so they ring through silent mode and Focus and appear on the Lock Screen.
@MainActor
enum TimerAlarms {
    /// False when the user hasn't allowed alarms, so the caller can fall back to a notification.
    static func schedule(_ timer: CookTimer) async -> Bool {
        let manager = AlarmManager.shared
        if manager.authorizationState == .notDetermined { _ = try? await manager.requestAuthorization() }
        guard manager.authorizationState == .authorized else { return false }

        let title = LocalizedStringResource(stringLiteral: timer.label)
        let openButton = AlarmButton(text: "Cook Mode", textColor: .white, systemImageName: "frying.pan")
        let stopButton = AlarmButton(text: "Stop", textColor: .white, systemImageName: "stop.circle")
        let alert = AlarmPresentation.Alert(
            title: title,
            stopButton: stopButton,
            secondaryButton: timer.recipeID == nil ? nil : openButton,
            secondaryButtonBehavior: timer.recipeID == nil ? nil : .custom
        )
        let attributes = AlarmAttributes(
            presentation: AlarmPresentation(alert: alert, countdown: .init(title: title)),
            metadata: TimerAlarmMetadata(label: timer.label, recipeID: timer.recipeID),
            tintColor: accent
        )
        let configuration = AlarmManager.AlarmConfiguration<TimerAlarmMetadata>.timer(
            duration: Double(timer.duration),
            attributes: attributes,
            secondaryIntent: timer.recipeID.map { OpenCookModeIntent(recipeID: $0) }
        )
        return (try? await manager.schedule(id: timer.id, configuration: configuration)) != nil
    }

    static func cancel(_ id: UUID) {
        try? AlarmManager.shared.cancel(id: id)
    }

    /// The ids of timers the system still has, in step with the Lock Screen: stopping one there removes it.
    static var ids: AsyncStream<Set<UUID>> {
        AsyncStream { continuation in
            let task = Task {
                for await alarms in AlarmManager.shared.alarmUpdates { continuation.yield(Set(alarms.map(\.id))) }
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    static var current: Set<UUID> { Set(((try? AlarmManager.shared.alarms) ?? []).map(\.id)) }

    private static var accent: Color {
        Color(hex: UserDefaults.standard.string(forKey: AppSettings.Key.accentColor) ?? Theme.defaultAccentHex) ?? Theme.defaultAccent
    }
}

struct OpenCookModeIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "Open Cook Mode"
    static let openAppWhenRun = true
    static let isDiscoverable = false

    @Parameter(title: "Recipe")
    var recipeID: String

    init() { recipeID = "" }
    init(recipeID: UUID) { self.recipeID = recipeID.uuidString }

    @MainActor
    func perform() async throws -> some IntentResult {
        AppRouter.shared.cookRecipeID = UUID(uuidString: recipeID)
        return .result()
    }
}
#endif

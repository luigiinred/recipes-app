import EventKit
import Foundation
import RecipeKit

enum RemindersStatus: Equatable {
    case unavailable
    case off
    case needsAccess
    case denied
    case syncing
    case synced(Date)
    case failed(String)
}

/// Mirrors the grocery list into a "Groceries" list in the Reminders app and brings changes back.
@MainActor
final class RemindersSync {
    static let listTitle = "Groceries"

    private let store = EKEventStore()

    var hasAccess: Bool { EKEventStore.authorizationStatus(for: .reminder) == .fullAccess }

    var isDenied: Bool {
        let status = EKEventStore.authorizationStatus(for: .reminder)
        return status == .denied || status == .restricted
    }

    func requestAccess() async -> Bool {
        if hasAccess { return true }
        if isDenied { return false }
        return (try? await store.requestFullAccessToReminders()) ?? false
    }

    var changes: AsyncStream<Void> {
        AsyncStream { continuation in
            let token = NotificationCenter.default.addObserver(forName: .EKEventStoreChanged, object: store, queue: .main) { _ in
                continuation.yield()
            }
            continuation.onTermination = { _ in NotificationCenter.default.removeObserver(token) }
        }
    }

    /// Applies the Reminders side of the sync and returns what to change in the local grocery list.
    func reconcile(local: [GroceryItem]) async throws -> (save: [GroceryItem], delete: [GroceryItem]) {
        let calendar = try groceryCalendar()
        let reminders = await fetch(in: calendar)
        let remote = reminders.map {
            RemoteReminder(
                id: $0.calendarItemIdentifier, title: $0.title ?? "", notes: $0.notes ?? "",
                isCompleted: $0.isCompleted, modified: $0.lastModifiedDate ?? .distantPast
            )
        }
        let plan = GroceryReconciler.reconcile(local: local, remote: remote)
        if plan.isEmpty { return ([], []) }

        let byID = Dictionary(uniqueKeysWithValues: reminders.map { ($0.calendarItemIdentifier, $0) })
        var save = plan.saveItems

        for item in plan.createReminders {
            let reminder = EKReminder(eventStore: store)
            reminder.calendar = calendar
            apply(item, to: reminder)
            try store.save(reminder, commit: false)
            var linked = item
            linked.reminderID = reminder.calendarItemIdentifier
            save.removeAll { $0.id == linked.id }
            save.append(linked)
        }
        for change in plan.updateReminders {
            guard let reminder = byID[change.reminderID] else { continue }
            apply(change.item, to: reminder)
            try store.save(reminder, commit: false)
        }
        for id in plan.deleteReminders {
            if let reminder = byID[id] { try store.remove(reminder, commit: false) }
        }
        try store.commit()
        return (save, plan.deleteItems)
    }

    private func apply(_ item: GroceryItem, to reminder: EKReminder) {
        reminder.title = item.reminderTitle
        reminder.isCompleted = item.isChecked
        let kept = (reminder.notes ?? "").split(whereSeparator: \.isNewline).filter { !$0.hasPrefix(GroceryReconciler.markerPrefix) }
        reminder.notes = (kept.map(String.init) + [GroceryReconciler.marker(for: item)]).joined(separator: "\n")
    }

    private func fetch(in calendar: EKCalendar) async -> [EKReminder] {
        await withCheckedContinuation { continuation in
            store.fetchReminders(matching: store.predicateForReminders(in: [calendar])) { continuation.resume(returning: $0 ?? []) }
        }
    }

    private func groceryCalendar() throws -> EKCalendar {
        let calendars = store.calendars(for: .reminder)
        if let existing = calendars.first(where: { $0.title == Self.listTitle && $0.allowsContentModifications }) { return existing }
        let calendar = EKCalendar(for: .reminder, eventStore: store)
        calendar.title = Self.listTitle
        guard let source = store.defaultCalendarForNewReminders()?.source ?? store.sources.first(where: { $0.sourceType == .calDAV || $0.sourceType == .local }) else {
            throw RecipeError.invalid("No Reminders account is available.")
        }
        calendar.source = source
        try store.saveCalendar(calendar, commit: true)
        return calendar
    }
}

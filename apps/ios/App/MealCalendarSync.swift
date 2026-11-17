import EventKit
import Foundation
import RecipeKit

/// Keeps a "Meal Plan" calendar in the Calendar app matching the plan: one event per meal, at that meal's usual time.
/// The plan is the source; edits made in Calendar are put back on the next sync.
@MainActor
final class MealCalendarSync {
    static let shared = MealCalendarSync()
    static let calendarTitle = "Meal Plan"

    private let store = EKEventStore()
    private var pending: Task<Void, Never>?
    private static let calendarKey = "mealCalendarID"
    private static let marker = "recipes-meal:"

    static var isOn: Bool { UserDefaults.standard.bool(forKey: AppSettings.Key.mealCalendar) }

    var hasAccess: Bool { EKEventStore.authorizationStatus(for: .event) == .fullAccess }

    func requestAccess() async -> Bool {
        if hasAccess { return true }
        let status = EKEventStore.authorizationStatus(for: .event)
        guard status != .denied, status != .restricted else { return false }
        return (try? await store.requestFullAccessToEvents()) ?? false
    }

    /// Syncs a moment after the last change, so a run of edits writes the calendar once.
    func request(plan: [MealPlanEntry]) {
        guard Self.isOn, hasAccess else { return }
        pending?.cancel()
        pending = Task {
            try? await Task.sleep(for: .milliseconds(600))
            guard !Task.isCancelled else { return }
            try? sync(plan)
        }
    }

    func sync(_ plan: [MealPlanEntry]) throws {
        guard hasAccess else { return }
        let calendar = try mealCalendar()
        let span = Self.span(of: plan)
        let events = store.events(matching: store.predicateForEvents(withStart: span.start, end: span.end, calendars: [calendar]))
        var byEntry: [UUID: EKEvent] = [:]
        for event in events {
            if let id = Self.entryID(in: event), byEntry[id] == nil { byEntry[id] = event } else { try store.remove(event, span: .thisEvent, commit: false) }
        }
        let planned = Set(plan.map(\.id))
        for (id, event) in byEntry where !planned.contains(id) { try store.remove(event, span: .thisEvent, commit: false) }
        for entry in plan {
            guard let times = Self.times(for: entry) else { continue }
            let event = byEntry[entry.id] ?? EKEvent(eventStore: store)
            guard event.calendar == nil || event.title != entry.title || event.startDate != times.start || event.endDate != times.end else { continue }
            event.calendar = calendar
            event.title = entry.title
            event.startDate = times.start
            event.endDate = times.end
            event.notes = Self.marker + entry.id.uuidString
            event.url = entry.recipeID.map(RecipeLink.url(for:))
            try store.save(event, span: .thisEvent, commit: false)
        }
        try store.commit()
    }

    /// Takes the calendar away again, events and all, when syncing is turned off.
    func removeCalendar() {
        guard hasAccess, let id = UserDefaults.standard.string(forKey: Self.calendarKey),
              let calendar = store.calendar(withIdentifier: id) else { return }
        try? store.removeCalendar(calendar, commit: true)
        UserDefaults.standard.removeObject(forKey: Self.calendarKey)
    }

    private func mealCalendar() throws -> EKCalendar {
        if let id = UserDefaults.standard.string(forKey: Self.calendarKey), let existing = store.calendar(withIdentifier: id) { return existing }
        let calendar = EKCalendar(for: .event, eventStore: store)
        calendar.title = Self.calendarTitle
        guard let source = store.defaultCalendarForNewEvents?.source ?? store.sources.first(where: { $0.sourceType == .calDAV || $0.sourceType == .local }) else {
            throw RecipeError.invalid("No calendar account is available.")
        }
        calendar.source = source
        try store.saveCalendar(calendar, commit: true)
        UserDefaults.standard.set(calendar.calendarIdentifier, forKey: Self.calendarKey)
        return calendar
    }

    private static func entryID(in event: EKEvent) -> UUID? {
        guard let line = event.notes?.split(whereSeparator: \.isNewline).first(where: { $0.hasPrefix(marker) }) else { return nil }
        return UUID(uuidString: String(line.dropFirst(marker.count)))
    }

    /// Breakfast at 8, lunch at noon, a snack at 3 and dinner at 6, each an hour long.
    static func times(for entry: MealPlanEntry, calendar: Calendar = .current) -> (start: Date, end: Date)? {
        guard let day = DayKey.date(from: entry.day, calendar: calendar) else { return nil }
        let hour = switch entry.meal {
        case .breakfast: 8
        case .lunch: 12
        case .snack: 15
        case .dinner: 18
        }
        guard let start = calendar.date(bySettingHour: hour, minute: 0, second: 0, of: day),
              let end = calendar.date(byAdding: .hour, value: 1, to: start) else { return nil }
        return (start, end)
    }

    /// The days the plan covers, widened by a week each way so meals moved off the plan's edges are found and removed.
    private static func span(of plan: [MealPlanEntry]) -> (start: Date, end: Date) {
        let calendar = Calendar.current
        let days = plan.compactMap { DayKey.date(from: $0.day, calendar: calendar) }
        let first = days.min() ?? Date()
        let last = days.max() ?? Date()
        let start = calendar.date(byAdding: .day, value: -7, to: min(first, Date())) ?? first
        let end = calendar.date(byAdding: .day, value: 8, to: max(last, Date())) ?? last
        return (start, end)
    }
}

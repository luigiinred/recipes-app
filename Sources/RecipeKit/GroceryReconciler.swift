import Foundation

public struct RemoteReminder: Hashable, Sendable {
    public var id: String
    public var title: String
    public var notes: String
    public var isCompleted: Bool
    public var modified: Date

    public init(id: String, title: String, notes: String = "", isCompleted: Bool = false, modified: Date = .distantPast) {
        self.id = id
        self.title = title
        self.notes = notes
        self.isCompleted = isCompleted
        self.modified = modified
    }
}

/// Works out what to change on each side to bring the grocery list and the Reminders list together.
/// Reminders created here carry a marker in their notes, so a reminder whose item was deleted elsewhere
/// (or an item whose reminder was deleted) is a deletion rather than something to bring back.
public enum GroceryReconciler {
    public struct Plan: Equatable, Sendable {
        public var createReminders: [GroceryItem] = []
        public var updateReminders: [RemoteChange] = []
        public var deleteReminders: [String] = []
        public var saveItems: [GroceryItem] = []
        public var deleteItems: [GroceryItem] = []

        public var isEmpty: Bool {
            createReminders.isEmpty && updateReminders.isEmpty && deleteReminders.isEmpty && saveItems.isEmpty && deleteItems.isEmpty
        }
    }

    public struct RemoteChange: Equatable, Sendable {
        public var reminderID: String
        public var item: GroceryItem
    }

    public static let markerPrefix = "recipes-item:"

    public static func marker(for item: GroceryItem) -> String { markerPrefix + item.id.uuidString.lowercased() }

    public static func itemID(inNotes notes: String) -> UUID? {
        for line in notes.split(whereSeparator: \.isNewline) where line.hasPrefix(markerPrefix) {
            return UUID(uuidString: String(line.dropFirst(markerPrefix.count)))
        }
        return nil
    }

    public static func reconcile(local: [GroceryItem], remote: [RemoteReminder], tolerance: TimeInterval = 2) -> Plan {
        var plan = Plan()
        let localByID = Dictionary(uniqueKeysWithValues: local.map { ($0.id, $0) })
        var matched = Set<UUID>()

        for reminder in remote {
            guard let itemID = itemID(inNotes: reminder.notes) else {
                var item = GroceryItem(parsing: reminder.title)
                item.isChecked = reminder.isCompleted
                item.reminderID = reminder.id
                item.updatedAt = reminder.modified == .distantPast ? Date() : reminder.modified
                plan.saveItems.append(item)
                plan.updateReminders.append(RemoteChange(reminderID: reminder.id, item: item))
                continue
            }
            guard var item = localByID[itemID] else {
                plan.deleteReminders.append(reminder.id)
                continue
            }
            matched.insert(itemID)
            let same = reminder.title == item.reminderTitle && reminder.isCompleted == item.isChecked
            if same {
                if item.reminderID != reminder.id {
                    item.reminderID = reminder.id
                    plan.saveItems.append(item)
                }
            } else if item.updatedAt.timeIntervalSince(reminder.modified) > tolerance {
                item.reminderID = reminder.id
                plan.updateReminders.append(RemoteChange(reminderID: reminder.id, item: item))
                if localByID[itemID]?.reminderID != reminder.id { plan.saveItems.append(item) }
            } else {
                let parsed = IngredientParser.split(reminder.title)
                item.name = parsed.name
                item.quantity = parsed.quantity
                item.isChecked = reminder.isCompleted
                item.reminderID = reminder.id
                item.updatedAt = reminder.modified
                plan.saveItems.append(item)
            }
        }

        for item in local where !matched.contains(item.id) {
            if item.reminderID != nil {
                plan.deleteItems.append(item)
            } else {
                plan.createReminders.append(item)
            }
        }
        return plan
    }
}

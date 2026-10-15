import XCTest
@testable import RecipeKit

final class GroceryReconcilerTests: XCTestCase {
    private let t0 = Date(timeIntervalSince1970: 1_800_000_000)

    private func item(_ text: String, checked: Bool = false, reminderID: String? = nil, updated: Date? = nil) -> GroceryItem {
        var item = GroceryItem(parsing: text)
        item.isChecked = checked
        item.reminderID = reminderID
        item.updatedAt = updated ?? t0
        return item
    }

    private func reminder(for item: GroceryItem, id: String = "R1", title: String? = nil, completed: Bool? = nil, modified: Date? = nil) -> RemoteReminder {
        RemoteReminder(
            id: id, title: title ?? item.reminderTitle, notes: GroceryReconciler.marker(for: item),
            isCompleted: completed ?? item.isChecked, modified: modified ?? t0
        )
    }

    func testNewLocalItemCreatesReminder() {
        let milk = item("2 cups milk")
        let plan = GroceryReconciler.reconcile(local: [milk], remote: [])
        XCTAssertEqual(plan.createReminders, [milk])
        XCTAssertTrue(plan.saveItems.isEmpty && plan.deleteItems.isEmpty)
    }

    func testNewReminderImportsAsItemAndGetsMarked() {
        let plan = GroceryReconciler.reconcile(local: [], remote: [RemoteReminder(id: "R9", title: "500g flour", isCompleted: true, modified: t0)])
        XCTAssertEqual(plan.saveItems.count, 1)
        XCTAssertEqual(plan.saveItems[0].name, "flour")
        XCTAssertEqual(plan.saveItems[0].quantity, "500g")
        XCTAssertTrue(plan.saveItems[0].isChecked)
        XCTAssertEqual(plan.saveItems[0].reminderID, "R9")
        XCTAssertEqual(plan.updateReminders.map(\.reminderID), ["R9"])
    }

    func testNewerReminderWinsAndUpdatesItem() {
        let eggs = item("6 eggs", reminderID: "R1", updated: t0)
        let plan = GroceryReconciler.reconcile(local: [eggs], remote: [reminder(for: eggs, completed: true, modified: t0.addingTimeInterval(60))])
        XCTAssertEqual(plan.saveItems.first?.isChecked, true)
        XCTAssertTrue(plan.updateReminders.isEmpty)
    }

    func testNewerItemWinsAndUpdatesReminder() {
        let eggs = item("6 eggs", checked: true, reminderID: "R1", updated: t0.addingTimeInterval(60))
        let plan = GroceryReconciler.reconcile(local: [eggs], remote: [reminder(for: eggs, completed: false, modified: t0)])
        XCTAssertEqual(plan.updateReminders.first?.item.isChecked, true)
        XCTAssertTrue(plan.saveItems.isEmpty)
    }

    func testInSyncChangesNothing() {
        let eggs = item("6 eggs", reminderID: "R1")
        XCTAssertTrue(GroceryReconciler.reconcile(local: [eggs], remote: [reminder(for: eggs)]).isEmpty)
    }

    func testDeletedReminderDeletesSyncedItem() {
        let eggs = item("6 eggs", reminderID: "R1")
        XCTAssertEqual(GroceryReconciler.reconcile(local: [eggs], remote: []).deleteItems, [eggs])
    }

    func testDeletedItemDeletesOrphanReminder() {
        let gone = item("old")
        XCTAssertEqual(GroceryReconciler.reconcile(local: [], remote: [reminder(for: gone, id: "R5")]).deleteReminders, ["R5"])
    }

    func testMarkerParsing() {
        let milk = item("milk")
        XCTAssertEqual(GroceryReconciler.itemID(inNotes: "Added from a recipe\n" + GroceryReconciler.marker(for: milk)), milk.id)
        XCTAssertNil(GroceryReconciler.itemID(inNotes: "just a note"))
    }
}

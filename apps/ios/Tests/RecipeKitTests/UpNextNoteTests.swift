import XCTest
@testable import RecipeKit

final class UpNextNoteTests: XCTestCase {
    func testQueueMixesRecipesAndNotesInTheOrderTheyJoined() {
        let start = Date(timeIntervalSince1970: 1_000)
        var tacos = Recipe(title: "Tacos")
        tacos.wantToCook = true
        tacos.queuedAt = start
        var soup = Recipe(title: "Soup")
        soup.wantToCook = true
        soup.queuedAt = start.addingTimeInterval(20)
        let notQueued = Recipe(title: "Salad")
        let eggs = UpNextNote(title: "Eggs", queuedAt: start.addingTimeInterval(10))

        let queue = UpNextItem.queue(recipes: [soup, notQueued, tacos], notes: [eggs])

        XCTAssertEqual(queue.map(\.title), ["Tacos", "Eggs", "Soup"])
    }

    func testNotesRoundTripThroughTheLibrary() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let library = Library(root: root)
        let time = Date(timeIntervalSince1970: 1_000)
        let note = UpNextNote(title: "Eggs", queuedAt: time, createdAt: time, updatedAt: time)

        try library.upNextNotes.save(note)

        XCTAssertEqual(try library.upNextNotes.list(), [note])
    }
}

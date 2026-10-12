import CoreTransferable
import Foundation
import UniformTypeIdentifiers

enum CalendarMode: String, CaseIterable {
    case agenda, planner

    var title: String { self == .agenda ? "Agenda" : "Week" }
    var symbol: String { self == .agenda ? "list.bullet.below.rectangle" : "rectangle.split.3x1" }
}

/// What is being dragged around the planner: a recipe from the drawer, or a meal already on the calendar.
struct PlannerPayload: Codable, Hashable, Transferable {
    enum Kind: String, Codable { case recipe, entry }

    var kind: Kind
    var id: UUID

    static var transferRepresentation: some TransferRepresentation {
        CodableRepresentation(contentType: .json)
    }
}

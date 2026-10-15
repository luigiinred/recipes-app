import RecipeKit
import SwiftUI
import UniformTypeIdentifiers

struct LibraryExportDocument: FileDocument {
    static let readableContentTypes: [UTType] = [.json]

    let data: Data

    init(data: Data) {
        self.data = data
    }

    init(configuration: ReadConfiguration) throws {
        data = configuration.file.regularFileContents ?? Data()
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }

    static func defaultFilename(for date: Date = Date()) -> String {
        "Recipes Export \(DayKey.string(from: date))"
    }
}

import RecipeKit
import SwiftUI
#if os(iOS)
import UIKit
#else
import AppKit
import PDFKit
#endif

/// Prints the same page the PDF share makes.
@MainActor
enum RecipePrinter {
    static func print(_ recipe: Recipe, photo: CGImage?, style: RecipePDF.Style) {
        let data = RecipePDF.data(for: recipe, photo: photo, style: style)
        #if os(iOS)
        let info = UIPrintInfo(dictionary: nil)
        info.outputType = .general
        info.jobName = recipe.title
        let controller = UIPrintInteractionController.shared
        controller.printInfo = info
        controller.printingItem = data
        controller.present(animated: true)
        #else
        guard let document = PDFDocument(data: data) else { return }
        let info = NSPrintInfo.shared.copy() as! NSPrintInfo
        info.topMargin = 0; info.bottomMargin = 0; info.leftMargin = 0; info.rightMargin = 0
        guard let operation = document.printOperation(for: info, scalingMode: .pageScaleNone, autoRotate: false) else { return }
        operation.jobTitle = recipe.title
        operation.run()
        #endif
    }
}

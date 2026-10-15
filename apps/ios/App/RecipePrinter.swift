import RecipeKit
import SwiftUI
#if os(iOS)
import UIKit
#else
import AppKit
#endif

@MainActor
enum RecipePrinter {
    static func print(_ recipe: Recipe) {
        let html = RecipePrint.html(for: recipe)
        #if os(iOS)
        let info = UIPrintInfo(dictionary: nil)
        info.outputType = .general
        info.jobName = recipe.title
        let controller = UIPrintInteractionController.shared
        controller.printInfo = info
        controller.printFormatter = UIMarkupTextPrintFormatter(markupText: html)
        controller.present(animated: true)
        #else
        guard let attributed = try? NSAttributedString(
            data: Data(html.utf8),
            options: [.documentType: NSAttributedString.DocumentType.html, .characterEncoding: String.Encoding.utf8.rawValue],
            documentAttributes: nil
        ) else { return }
        let info = NSPrintInfo.shared.copy() as! NSPrintInfo
        info.topMargin = 54; info.bottomMargin = 54; info.leftMargin = 54; info.rightMargin = 54
        let width = info.paperSize.width - info.leftMargin - info.rightMargin
        let textView = NSTextView(frame: NSRect(x: 0, y: 0, width: width, height: 800))
        textView.textStorage?.setAttributedString(attributed)
        textView.sizeToFit()
        let operation = NSPrintOperation(view: textView, printInfo: info)
        operation.jobTitle = recipe.title
        operation.run()
        #endif
    }
}

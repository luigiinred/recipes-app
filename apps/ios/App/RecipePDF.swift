import CoreTransferable
import RecipeKit
import SwiftUI
import UniformTypeIdentifiers

/// A recipe laid out for US Letter paper: title, times and a small photo across the top, then ingredients in a narrow
/// column beside numbered steps. Always light on a white page, with the accent only in thin rules and small type, to save ink.
@MainActor
enum RecipePDF {
    struct Style {
        var accent: Color = Theme.defaultAccent
        var fontFamily: String?
        var fontDesign: Font.Design? = .serif
    }

    static let pageSize = CGSize(width: 612, height: 792)
    static let margin: CGFloat = 46
    static let gutter: CGFloat = 26
    static let footerHeight: CGFloat = 22
    static var contentWidth: CGFloat { pageSize.width - margin * 2 }
    static var ingredientsWidth: CGFloat { ((contentWidth - gutter) * 0.37).rounded() }
    static var methodWidth: CGFloat { contentWidth - gutter - ingredientsWidth }
    private static var columnsBottom: CGFloat { pageSize.height - margin * 2 - footerHeight }

    private struct Block {
        let view: AnyView
        let width: CGFloat
    }

    private struct Placement {
        let block: Block
        let x: CGFloat
        let y: CGFloat
    }

    static func data(for recipe: Recipe, photo: CGImage?, style: Style) -> Data {
        let pages = layout(recipe, photo: photo, style: style)
        let data = NSMutableData()
        var box = CGRect(origin: .zero, size: pageSize)
        guard let consumer = CGDataConsumer(data: data as CFMutableData),
              let pdf = CGContext(consumer: consumer, mediaBox: &box, [kCGPDFContextTitle as String: recipe.title] as CFDictionary) else { return Data() }
        for (index, page) in pages.enumerated() {
            pdf.beginPDFPage(nil)
            for placement in page { draw(placement.block, at: CGPoint(x: placement.x, y: placement.y), in: pdf, style: style) }
            let footer = Block(view: AnyView(Footer(recipe: recipe, page: index + 1, of: pages.count)), width: contentWidth)
            draw(footer, at: CGPoint(x: 0, y: pageSize.height - margin * 2 - height(of: footer, style: style)), in: pdf, style: style)
            pdf.endPDFPage()
        }
        pdf.closePDF()
        return data as Data
    }

    /// A file named after the recipe, for sharing.
    static func file(for recipe: Recipe, photo: CGImage?, style: Style) throws -> URL {
        let name = recipe.title.components(separatedBy: CharacterSet(charactersIn: "/:\\?%*|\"<>")).joined().trimmingCharacters(in: .whitespaces)
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("RecipePDF-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let url = folder.appendingPathComponent((name.isEmpty ? "Recipe" : name) + ".pdf")
        try data(for: recipe, photo: photo, style: style).write(to: url)
        return url
    }

    /// Fills each page's two columns from the top, never splitting a block; what doesn't fit starts the next page.
    private static func layout(_ recipe: Recipe, photo: CGImage?, style: Style) -> [[Placement]] {
        var ingredients = ingredientBlocks(recipe)
        var method = methodBlocks(recipe)
        var pages: [[Placement]] = []
        while pages.isEmpty || !ingredients.isEmpty || !method.isEmpty {
            var page: [Placement] = []
            let top: Block = pages.isEmpty
                ? Block(view: AnyView(Header(recipe: recipe, photo: photo)), width: contentWidth)
                : Block(view: AnyView(RunningHead(title: recipe.title)), width: contentWidth)
            page.append(Placement(block: top, x: 0, y: 0))
            let start = height(of: top, style: style) + (pages.isEmpty ? 22 : 14)
            let fullWidth = ingredients.isEmpty && !pages.isEmpty
            page += fill(&ingredients, x: 0, from: start, style: style)
            page += fill(&method, x: fullWidth ? 0 : ingredientsWidth + gutter, from: start, style: style, widen: fullWidth)
            pages.append(page)
            if pages.count > 40 { break }
        }
        return pages
    }

    private static func fill(_ blocks: inout [Block], x: CGFloat, from start: CGFloat, style: Style, widen: Bool = false) -> [Placement] {
        var placed: [Placement] = []
        var y = start
        while let next = blocks.first {
            let block = widen ? Block(view: next.view, width: contentWidth) : next
            let size = height(of: block, style: style)
            guard y + size <= columnsBottom || placed.isEmpty else { break }
            placed.append(Placement(block: block, x: x, y: y))
            y += size
            blocks.removeFirst()
        }
        return placed
    }

    private static func ingredientBlocks(_ recipe: Recipe) -> [Block] {
        guard !recipe.ingredients.isEmpty else { return [] }
        var blocks: [Block] = []
        for (groupIndex, group) in recipe.ingredientGroups.enumerated() {
            for (index, item) in group.items.enumerated() {
                let heading = index == 0 ? group.title : nil
                blocks.append(Block(view: AnyView(IngredientItem(
                    text: item.text, heading: heading, showsColumnTitle: groupIndex == 0 && index == 0
                )), width: ingredientsWidth))
            }
        }
        return blocks
    }

    private static func methodBlocks(_ recipe: Recipe) -> [Block] {
        var blocks = recipe.steps.enumerated().map { index, step in
            Block(view: AnyView(Step(number: index + 1, text: step, showsColumnTitle: index == 0)), width: methodWidth)
        }
        let notes = recipe.notes.trimmingCharacters(in: .whitespacesAndNewlines)
        if !notes.isEmpty { blocks.append(Block(view: AnyView(Notes(text: notes)), width: methodWidth)) }
        return blocks
    }

    private static func styled(_ block: Block, style: Style) -> some View {
        block.view
            .frame(width: block.width, alignment: .leading)
            .fixedSize(horizontal: false, vertical: true)
            .environment(\.colorScheme, .light)
            .environment(\.appAccent, style.accent)
            .environment(\.appFontFamily, style.fontFamily)
            .fontDesign(style.fontFamily == nil ? style.fontDesign : nil)
            .foregroundStyle(Color.black)
    }

    private static func height(of block: Block, style: Style) -> CGFloat {
        let renderer = ImageRenderer(content: styled(block, style: style))
        renderer.proposedSize = ProposedViewSize(width: block.width, height: nil)
        var height: CGFloat = 0
        renderer.render { size, _ in height = size.height }
        return height
    }

    private static func draw(_ block: Block, at point: CGPoint, in pdf: CGContext, style: Style) {
        let renderer = ImageRenderer(content: styled(block, style: style))
        renderer.proposedSize = ProposedViewSize(width: block.width, height: nil)
        renderer.render { size, render in
            pdf.saveGState()
            pdf.translateBy(x: margin + point.x, y: pageSize.height - margin - point.y - size.height)
            render(pdf)
            pdf.restoreGState()
        }
    }
}

/// The recipe as a PDF file for the share sheet, made when the user picks where to send it.
struct RecipePDFDocument: Transferable {
    let recipe: Recipe
    let photo: CGImage?
    let accent: Color
    let fontFamily: String?
    let fontDesign: Font.Design?

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(exportedContentType: .pdf) { document in
            let url = try await MainActor.run {
                try RecipePDF.file(for: document.recipe, photo: document.photo, style: .init(accent: document.accent, fontFamily: document.fontFamily, fontDesign: document.fontDesign))
            }
            return SentTransferredFile(url)
        }
        .suggestedFileName { $0.recipe.title + ".pdf" }
    }
}

// MARK: - Page parts

private struct PDFFont: ViewModifier {
    @Environment(\.appFontFamily) private var family
    let size: CGFloat
    let weight: Font.Weight

    func body(content: Content) -> some View {
        content.font(family.map { Font.custom($0, fixedSize: size).weight(weight) } ?? .system(size: size, weight: weight))
    }
}

private extension View {
    func pdfFont(_ size: CGFloat, _ weight: Font.Weight = .regular) -> some View { modifier(PDFFont(size: size, weight: weight)) }
}

private let secondary = Color(white: 0.38)

private struct ColumnTitle: View {
    let title: String

    var body: some View {
        Text(title.uppercased())
            .pdfFont(9, .bold)
            .tracking(1.4)
            .foregroundStyle(Theme.accent)
            .padding(.bottom, 8)
    }
}

private struct Header: View {
    let recipe: Recipe
    let photo: CGImage?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(recipe.title).pdfFont(26, .bold).lineSpacing(1)
                    if !recipe.summary.isEmpty {
                        Text(recipe.summary).pdfFont(11.5).foregroundStyle(secondary).lineSpacing(2.5)
                    }
                    if !facts.isEmpty {
                        Text(facts.joined(separator: "   ·   ")).pdfFont(10, .semibold).padding(.top, 2)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                if let photo {
                    Image(decorative: photo, scale: 1)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 112, height: 112)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
            }
            Rectangle().fill(Theme.accent).frame(height: 1.25)
        }
    }

    private var facts: [String] {
        var facts: [String] = []
        if let servings = recipe.servings { facts.append("Serves \(servings)") }
        if let prep = recipe.prepMinutes, prep > 0 { facts.append("Prep \(Self.duration(prep))") }
        if let cook = recipe.cookMinutes, cook > 0 { facts.append("Cook \(Self.duration(cook))") }
        if let prep = recipe.prepMinutes, let cook = recipe.cookMinutes, prep > 0, cook > 0 { facts.append("Total \(Self.duration(prep + cook))") }
        return facts
    }

    static func duration(_ minutes: Int) -> String {
        minutes < 60 ? "\(minutes) min" : minutes % 60 == 0 ? "\(minutes / 60) hr" : "\(minutes / 60) hr \(minutes % 60) min"
    }
}

private struct RunningHead: View {
    let title: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).pdfFont(13, .semibold).lineLimit(1)
            Rectangle().fill(Theme.accent).frame(height: 0.75)
        }
    }
}

private struct IngredientItem: View {
    let text: String
    let heading: String?
    let showsColumnTitle: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if showsColumnTitle { ColumnTitle(title: "Ingredients") }
            if let heading {
                Text(heading).pdfFont(10.5, .semibold).foregroundStyle(Theme.accent)
                    .padding(.top, showsColumnTitle ? 0 : 8)
                    .padding(.bottom, 4)
            }
            Text(IngredientLine.styled(text)).pdfFont(11).lineSpacing(2)
                .padding(.bottom, 6)
        }
    }
}

private struct Step: View {
    let number: Int
    let text: String
    let showsColumnTitle: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if showsColumnTitle { ColumnTitle(title: "Method") }
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text("\(number)").pdfFont(12, .bold).foregroundStyle(Theme.accent).monospacedDigit()
                    .frame(width: 18, alignment: .trailing)
                Text(text).pdfFont(11.5).lineSpacing(2.5)
            }
            .padding(.bottom, 11)
        }
    }
}

private struct Notes: View {
    let text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ColumnTitle(title: "Notes").padding(.top, 6)
            Text(text).pdfFont(10.5).foregroundStyle(secondary).lineSpacing(2)
        }
    }
}

private struct Footer: View {
    let recipe: Recipe
    let page: Int
    let of: Int

    var body: some View {
        HStack(alignment: .lastTextBaseline) {
            Text(source).lineLimit(1)
            Spacer(minLength: 12)
            if of > 1 { Text("\(page) of \(of)").monospacedDigit() }
        }
        .pdfFont(8.5)
        .foregroundStyle(secondary)
    }

    private var source: String {
        guard let link = recipe.sourceURL, let host = URL(string: link)?.host() else { return "Recipes" }
        return host.replacingOccurrences(of: "www.", with: "") + "  ·  Recipes"
    }
}

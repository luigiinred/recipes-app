import Foundation

/// The changes a cleanup would make to a recipe, each one shown and accepted on its own; nothing is applied until the user picks.
public struct RecipeCleanup: Sendable {
    public struct Change: Identifiable, Hashable, Sendable {
        public enum Kind: Hashable, Sendable {
            case ingredient(Int)
            case sections
            case step(Int)
            case notes
        }

        public var kind: Kind
        public var title: String
        /// Lines starting with "# " are section headings.
        public var before: [String]
        public var after: [String]

        public var id: Kind { kind }
    }

    public let original: Recipe
    public private(set) var changes: [Change] = []

    private var tidiedIngredients: [Int: String] = [:]
    private var headingLines: [Int: String] = [:]
    private var groups: [IngredientGrouper.Group]?
    private var stepPieces: [Int: [String]] = [:]
    private var notesAddition: String?

    public var isEmpty: Bool { changes.isEmpty }

    /// The recipe with every change accepted.
    public var recipe: Recipe { applying(Set(changes.map(\.id))) }

    /// "Tidy 3 ingredients and split the method into 6 steps."
    public var summary: String {
        var parts: [String] = []
        let ingredients = changes.filter { if case .ingredient = $0.kind { true } else { false } }.count
        if ingredients > 0 { parts.append("tidy \(ingredients) \(ingredients == 1 ? "ingredient" : "ingredients")") }
        if let sections = changes.first(where: { $0.kind == .sections }) { parts.append(sections.title.prefix(1).lowercased() + sections.title.dropFirst()) }
        let steps = changes.filter { if case .step = $0.kind { true } else { false } }
        let split = steps.filter { $0.after.count > 1 }.count
        if split > 0 { parts.append("split \(split) long \(split == 1 ? "step" : "steps")") }
        if steps.count > split { parts.append("tidy \(steps.count - split) \(steps.count - split == 1 ? "step" : "steps")") }
        if changes.contains(where: { $0.kind == .notes }) { parts.append("move loose text into Notes") }
        guard let first = parts.first else { return "" }
        let sentence = parts.count == 1 ? first : parts.dropLast().joined(separator: ", ") + " and " + parts.last!
        return sentence.prefix(1).uppercased() + sentence.dropFirst() + "."
    }

    init(original: Recipe) {
        self.original = original
    }

    /// Finds the changes: ingredients and steps in the standard form, labels as sections, and with Apple Intelligence on,
    /// long steps split and a long ingredient list grouped.
    public static func suggest(for original: Recipe) async -> RecipeCleanup {
        var cleanup = RecipeCleanup(original: original)

        for (index, text) in original.ingredients.enumerated() {
            let parsed = Ingredient(parsing: text).text
            if let heading = RecipeStandards.ingredientHeading(parsed) {
                cleanup.headingLines[index] = heading
            } else if parsed != text {
                cleanup.tidiedIngredients[index] = parsed
                cleanup.changes.append(Change(kind: .ingredient(index), title: parsed.isEmpty ? "Remove an empty line" : "Ingredient",
                                              before: [text], after: parsed.isEmpty ? [] : [parsed]))
            }
        }
        if !cleanup.headingLines.isEmpty {
            let count = cleanup.headingLines.count
            cleanup.changes.append(Change(kind: .sections, title: "Turn \(count) \(count == 1 ? "label" : "labels") into sections",
                                          before: layout(of: original), after: layout(of: cleanup.applying([.sections]))))
        } else if original.ingredientSections.isEmpty {
            let tidied = original.ingredients.indices.map { cleanup.tidiedIngredients[$0] ?? original.ingredients[$0] }.filter { !$0.isEmpty }
            if case .grouped(let list, let sections) = await IngredientGrouper.group(title: original.title, ingredients: tidied, steps: original.steps) {
                cleanup.groups = groups(from: list, sections: sections, source: tidied)
                if cleanup.groups != nil {
                    cleanup.changes.append(Change(kind: .sections, title: "Group the ingredients into \(sections.count) sections",
                                                  before: tidied, after: layout(of: cleanup.applying(Set(cleanup.changes.map(\.id) + [.sections])))))
                }
            }
        }

        var preface: [String] = []
        for (index, step) in original.steps.enumerated() {
            var pieces = [step]
            if let split = RecipeStandards.splitNumberedSteps(step) {
                if !split.preamble.isEmpty { preface.append(split.preamble) }
                pieces = split.steps
            }
            pieces = pieces.map(RecipeStandards.standardStep).filter { !$0.isEmpty }
            pieces = await StepSplitter.split(pieces)
            guard pieces != [step] else { continue }
            cleanup.stepPieces[index] = pieces
            let title = pieces.isEmpty ? "Remove empty step \(index + 1)" : pieces.count > 1 ? "Split step \(index + 1) into \(pieces.count)" : "Step \(index + 1)"
            cleanup.changes.append(Change(kind: .step(index), title: title, before: [step], after: pieces))
        }
        let extra = preface.joined(separator: "\n")
        if !extra.isEmpty, !original.notes.contains(extra) {
            cleanup.notesAddition = extra
            cleanup.changes.append(Change(kind: .notes, title: "Move text from the steps into Notes", before: [original.notes].filter { !$0.isEmpty },
                                          after: [original.notes.isEmpty ? extra : original.notes + "\n\n" + extra]))
        }
        return cleanup
    }

    /// The recipe with only the accepted changes. A split step keeps its video time and photo on its first part.
    public func applying(_ accepted: Set<Change.Kind>) -> Recipe {
        var recipe = original
        let sectionsOn = accepted.contains(.sections)

        var lines: [String] = []
        var headings: [IngredientSection] = []
        var landing: [Int] = []
        for (index, text) in original.ingredients.enumerated() {
            landing.append(lines.count)
            if sectionsOn, let heading = headingLines[index] {
                headings.append(IngredientSection(title: heading, start: lines.count))
                continue
            }
            let line = accepted.contains(.ingredient(index)) ? tidiedIngredients[index] ?? text : text
            if !line.isEmpty { lines.append(line) }
        }
        if sectionsOn, let groups, let grouped = IngredientGrouper.apply(groups, to: lines) {
            recipe.ingredients = grouped.ingredients
            recipe.ingredientSections = grouped.sections
        } else {
            let moved = original.ingredientSections.map {
                IngredientSection(title: $0.title, start: landing.indices.contains($0.start) ? landing[$0.start] : lines.count)
            }
            recipe.ingredients = lines
            recipe.ingredientSections = RecipeStandards.standardSections(moved + headings, ingredientCount: lines.count)
        }

        var steps: [String] = []
        var stamps: [Int?] = []
        var images: [UUID?] = []
        for (index, step) in original.steps.enumerated() {
            let pieces = accepted.contains(.step(index)) ? stepPieces[index] ?? [step] : [step]
            for (offset, piece) in pieces.enumerated() {
                steps.append(piece)
                stamps.append(offset == 0 ? original.timestamp(forStep: index) : nil)
                images.append(offset == 0 ? original.stepImage(forStep: index) : nil)
            }
        }
        recipe.steps = steps
        if !original.stepTimestamps.isEmpty { recipe.stepTimestamps = stamps }
        if !original.stepImages.isEmpty { recipe.stepImages = images.allSatisfy { $0 == nil } ? [] : images }

        if accepted.contains(.notes), let notesAddition {
            recipe.notes = original.notes.isEmpty ? notesAddition : original.notes + "\n\n" + notesAddition
        }
        return recipe
    }

    /// The ingredient list as lines, with "# " before each section title.
    static func layout(of recipe: Recipe) -> [String] {
        recipe.ingredientGroups.flatMap { group in (group.title.map { ["# " + $0] } ?? []) + group.items.map(\.text) }
    }

    /// The model hands back a reordered list; this reads which source line each grouped line came from.
    private static func groups(from list: [String], sections: [IngredientSection], source: [String]) -> [IngredientGrouper.Group]? {
        var unused = Array(source.indices)
        var origin: [Int] = []
        for line in list {
            guard let position = unused.firstIndex(where: { source[$0] == line }) else { return nil }
            origin.append(unused.remove(at: position))
        }
        let starts = sections.sorted { $0.start < $1.start }
        return starts.enumerated().map { offset, section in
            let end = offset + 1 < starts.count ? starts[offset + 1].start : list.count
            return IngredientGrouper.Group(title: section.title, members: Array(origin[section.start..<min(end, origin.count)]))
        }
    }
}

extension Recipe {
    /// A stable fingerprint of the parts a cleanup reads, so a recipe already checked isn't checked again until it changes.
    public var cleanupFingerprint: String {
        let sections = ingredientSections.map { "\($0.start):\($0.title)" }
        let parts = [title] + ingredients + ["§"] + sections + ["§"] + steps + ["§", notes]
        var hash: UInt64 = 0xcbf2_9ce4_8422_2325
        for byte in parts.joined(separator: "\u{1F}").utf8 {
            hash ^= UInt64(byte)
            hash = hash &* 0x100_0000_01b3
        }
        return String(hash, radix: 36)
    }
}

/// Words removed and added between two versions of a line, for showing a change.
public enum WordDiff {
    public enum Piece: Hashable, Sendable {
        case same(String)
        case removed(String)
        case added(String)
    }

    public static func pieces(from before: String, to after: String) -> [Piece] {
        let old = before.split(separator: " ").map(String.init)
        let new = after.split(separator: " ").map(String.init)
        guard old.count * new.count <= 40_000 else { return [.removed(before), .added(after)] }
        var table = Array(repeating: Array(repeating: 0, count: new.count + 1), count: old.count + 1)
        for i in stride(from: old.count - 1, through: 0, by: -1) {
            for j in stride(from: new.count - 1, through: 0, by: -1) {
                table[i][j] = old[i] == new[j] ? table[i + 1][j + 1] + 1 : max(table[i + 1][j], table[i][j + 1])
            }
        }
        var result: [Piece] = []
        var i = 0, j = 0
        while i < old.count || j < new.count {
            if i < old.count, j < new.count, old[i] == new[j] {
                result.append(.same(old[i])); i += 1; j += 1
            } else if j < new.count, i == old.count || table[i][j + 1] > table[i + 1][j] {
                result.append(.added(new[j])); j += 1
            } else {
                result.append(.removed(old[i])); i += 1
            }
        }
        return result
    }
}

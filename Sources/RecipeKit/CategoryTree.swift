import Foundation

/// Categories are tags; a "/" nests one under another, so "Dinner/Pasta" is Pasta inside Dinner.
public struct CategoryNode: Identifiable, Hashable, Sendable {
    public var path: String
    public var name: String
    public var children: [CategoryNode]

    public var id: String { path }
}

public enum CategoryTree {
    public static let separator: Character = "/"

    public static func components(_ tag: String) -> [String] {
        tag.split(separator: separator).map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
    }

    public static func normalized(_ tag: String) -> String {
        components(tag).joined(separator: String(separator))
    }

    /// Splits comma-separated input into normalized categories.
    public static func tags(from input: String) -> [String] {
        input.split(separator: ",").map { normalized(String($0)) }.filter { !$0.isEmpty }
    }

    public static func displayName(_ tag: String) -> String {
        components(tag).joined(separator: " › ")
    }

    public static func build(from tags: [String]) -> [CategoryNode] {
        func nodes(under prefix: [String], in paths: [[String]]) -> [CategoryNode] {
            var seen: [String] = []
            for path in paths where path.count > prefix.count
                && zip(path, prefix).allSatisfy({ $0.caseInsensitiveCompare($1) == .orderedSame }) {
                let next = path[prefix.count]
                if !seen.contains(where: { $0.caseInsensitiveCompare(next) == .orderedSame }) { seen.append(next) }
            }
            return seen.sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }.map { name in
                let childPrefix = prefix + [name]
                return CategoryNode(
                    path: childPrefix.joined(separator: String(separator)), name: name,
                    children: nodes(under: childPrefix, in: paths)
                )
            }
        }
        return nodes(under: [], in: tags.map(components).filter { !$0.isEmpty })
    }

    /// True when `tag` is `category` or sits anywhere beneath it.
    public static func tag(_ tag: String, isIn category: String) -> Bool {
        let tagParts = components(tag), categoryParts = components(category)
        guard !categoryParts.isEmpty, tagParts.count >= categoryParts.count else { return false }
        return zip(tagParts, categoryParts).allSatisfy { $0.caseInsensitiveCompare($1) == .orderedSame }
    }
}

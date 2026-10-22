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

    /// Siblings follow `order` (a list of category paths) first, then alphabetical for any it doesn't list.
    public static func build(from tags: [String], order: [String] = []) -> [CategoryNode] {
        let rank = Dictionary(order.enumerated().map { (normalized($1).lowercased(), $0) }, uniquingKeysWith: { first, _ in first })
        func nodes(under prefix: [String], in paths: [[String]]) -> [CategoryNode] {
            var seen: [String] = []
            for path in paths where path.count > prefix.count
                && zip(path, prefix).allSatisfy({ $0.caseInsensitiveCompare($1) == .orderedSame }) {
                let next = path[prefix.count]
                if !seen.contains(where: { $0.caseInsensitiveCompare(next) == .orderedSame }) { seen.append(next) }
            }
            func position(_ name: String) -> Int? { rank[(prefix + [name]).joined(separator: String(separator)).lowercased()] }
            return seen.sorted { a, b in
                switch (position(a), position(b)) {
                case let (x?, y?): x < y
                case (_?, nil): true
                case (nil, _?): false
                case (nil, nil): a.localizedCaseInsensitiveCompare(b) == .orderedAscending
                }
            }.map { name in
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
    public static func node(at path: String, in nodes: [CategoryNode]) -> CategoryNode? {
        var level = nodes
        var found: CategoryNode?
        for part in components(path) {
            guard let match = level.first(where: { $0.name.caseInsensitiveCompare(part) == .orderedSame }) else { return nil }
            found = match
            level = match.children
        }
        return found
    }

    public static func tag(_ tag: String, isIn category: String) -> Bool {
        let tagParts = components(tag), categoryParts = components(category)
        guard !categoryParts.isEmpty, tagParts.count >= categoryParts.count else { return false }
        return zip(tagParts, categoryParts).allSatisfy { $0.caseInsensitiveCompare($1) == .orderedSame }
    }

    /// The path of the sibling that follows `path`, skipping `excluding`, or nil when `path` is last.
    public static func nextSibling(after path: String, excluding: String? = nil, in nodes: [CategoryNode]) -> String? {
        let level = parent(of: path).map { node(at: $0, in: nodes)?.children ?? [] } ?? nodes
        let skipped = excluding.map(normalized)?.lowercased()
        let siblings = level.filter { $0.path.lowercased() != skipped }
        guard let index = siblings.firstIndex(where: { $0.path.lowercased() == normalized(path).lowercased() }) else { return nil }
        return siblings.indices.contains(index + 1) ? siblings[index + 1].path : nil
    }

    public static func parent(of path: String) -> String? {
        let parts = components(path)
        return parts.count > 1 ? parts.dropLast().joined(separator: String(separator)) : nil
    }

    /// Where `path` ends up when it is moved under `parent`, or to the top level when `parent` is nil.
    public static func destination(moving path: String, toParent parent: String?) -> String {
        let name = components(path).last ?? ""
        return normalized([parent ?? "", name].joined(separator: String(separator)))
    }

    /// A category can't move into itself or one of its own subcategories.
    public static func canMove(_ path: String, toParent parent: String?) -> Bool {
        guard !components(path).isEmpty else { return false }
        guard let parent else { return true }
        return !tag(parent, isIn: path)
    }

    /// Rewrites `tag` when it is `path` or sits beneath it, so the whole subtree follows a move.
    public static func rename(_ tag: String, from path: String, to destination: String) -> String {
        guard self.tag(tag, isIn: path) else { return tag }
        let rest = components(tag).dropFirst(components(path).count)
        return ([normalized(destination)] + rest).joined(separator: String(separator))
    }

    /// The tags and display order after moving a category under `parent`, ahead of its sibling `before` (or last).
    public static func moved(
        _ path: String, toParent parent: String?, before sibling: String?, tags: [String], order: [String]
    ) -> (tags: [String], order: [String]) {
        let destination = destination(moving: path, toParent: parent)
        let newTags = tags.map { rename($0, from: path, to: destination) }
        let newOrder = order.map { rename($0, from: path, to: destination) }
        let tree = build(from: newTags, order: newOrder)

        func flatten(_ nodes: [CategoryNode], under nodeParent: String?) -> [String] {
            var level = nodes
            if normalized(nodeParent ?? "") == normalized(parent ?? ""),
               let from = level.firstIndex(where: { $0.path.caseInsensitiveCompare(destination) == .orderedSame }) {
                let moving = level.remove(at: from)
                let to = sibling.flatMap { target in level.firstIndex { $0.path.caseInsensitiveCompare(normalized(target)) == .orderedSame } } ?? level.count
                level.insert(moving, at: to)
            }
            return level.flatMap { [$0.path] + flatten($0.children, under: $0.path) }
        }
        return (newTags, flatten(tree, under: nil))
    }
}

/// The user's chosen category order, one file in the library folder so iCloud shares it across devices.
public struct CategoryOrderStore: Sendable {
    public let url: URL

    public init(url: URL) {
        self.url = url
    }

    public func load() -> [String] {
        guard let data = try? FileIO.read(url), let paths = try? JSONDecoder().decode([String].self, from: data) else { return [] }
        return paths
    }

    public func save(_ paths: [String]) throws {
        try FileIO.write(try JSONEncoder().encode(paths), to: url)
    }
}

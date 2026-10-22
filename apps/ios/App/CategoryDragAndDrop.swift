import CoreTransferable
import RecipeKit
import SwiftUI
import UniformTypeIdentifiers

/// What a dragged category carries. Recipes use `.data` and categories `.json`, so a hover can tell them apart.
struct CategoryDragItem: Codable, Transferable {
    let path: String

    static var transferRepresentation: some TransferRepresentation {
        CodableRepresentation(contentType: .json)
    }
}

private enum CategoryDropZone {
    case before, into, after
}

extension View {
    /// Drag a category to reorder it, onto another to nest it, or drop a recipe on it to file the recipe there.
    @ViewBuilder
    func categoryDragAndDrop(_ path: String?, axis: Axis = .vertical) -> some View {
        if let path { modifier(CategoryDragAndDrop(path: path, axis: axis)) } else { self }
    }

    /// Drop a category here to take it out of whatever it is nested in.
    func categoryRootDrop() -> some View { modifier(CategoryRootDrop()) }
}

private struct CategoryDragAndDrop: ViewModifier {
    @EnvironmentObject private var library: RecipeLibrary
    @Environment(\.appAccent) private var accent
    let path: String
    let axis: Axis
    @State private var zone: CategoryDropZone?
    @State private var size = CGSize.zero

    func body(content: Content) -> some View {
        content
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .draggable(CategoryDragItem(path: path))
            .onGeometryChange(for: CGSize.self, of: \.size) { size = $0 }
            .overlay { indicator.allowsHitTesting(false) }
            .onDrop(of: [.data], delegate: CategoryDropDelegate(path: path, axis: axis, size: size, zone: $zone, library: library))
    }

    @ViewBuilder
    private var indicator: some View {
        switch zone {
        case .into: RoundedRectangle(cornerRadius: 8, style: .continuous).strokeBorder(accent, lineWidth: 2)
        case .before: edge(alignment: axis == .vertical ? .top : .leading)
        case .after: edge(alignment: axis == .vertical ? .bottom : .trailing)
        case nil: EmptyView()
        }
    }

    private func edge(alignment: Alignment) -> some View {
        accent
            .frame(width: axis == .vertical ? nil : 3, height: axis == .vertical ? 3 : nil)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: alignment)
    }
}

@MainActor
private struct CategoryDropDelegate: DropDelegate {
    let path: String
    let axis: Axis
    let size: CGSize
    @Binding var zone: CategoryDropZone?
    let library: RecipeLibrary

    func validateDrop(info: DropInfo) -> Bool { info.hasItemsConforming(to: [.data]) }

    func dropEntered(info: DropInfo) { zone = zone(for: info) }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        zone = zone(for: info)
        return DropProposal(operation: .move)
    }

    func dropExited(info: DropInfo) { zone = nil }

    func performDrop(info: DropInfo) -> Bool {
        let zone = zone(for: info)
        self.zone = nil
        let providers = info.itemProviders(for: [.data])
        guard !providers.isEmpty else { return false }
        for provider in providers {
            if provider.hasItemConformingToTypeIdentifier(UTType.json.identifier) {
                _ = provider.loadTransferable(type: CategoryDragItem.self) { result in
                    guard case .success(let item) = result else { return }
                    Task { @MainActor in await move(item.path, zone) }
                }
            } else {
                _ = provider.loadTransferable(type: RecipeDragItem.self) { result in
                    guard case .success(let item) = result else { return }
                    Task { @MainActor in await library.addTag(item.id, to: path) }
                }
            }
        }
        return true
    }

    /// Only a category can be placed before or after a row; a recipe always files into it.
    private func zone(for info: DropInfo) -> CategoryDropZone {
        guard info.hasItemsConforming(to: [.json]) else { return .into }
        let extent = axis == .vertical ? size.height : size.width
        let position = axis == .vertical ? info.location.y : info.location.x
        if position < extent * 0.25 { return .before }
        if position > extent * 0.75 { return .after }
        return .into
    }

    private func move(_ source: String, _ zone: CategoryDropZone) async {
        let parent = CategoryTree.parent(of: path)
        switch zone {
        case .into:
            await library.moveCategory(source, toParent: path, before: nil)
        case .before:
            await library.moveCategory(source, toParent: parent, before: path)
        case .after:
            let next = CategoryTree.nextSibling(after: path, excluding: source, in: library.categoryTree)
            await library.moveCategory(source, toParent: parent, before: next)
        }
    }
}

private struct CategoryRootDrop: ViewModifier {
    @EnvironmentObject private var library: RecipeLibrary
    @Environment(\.appAccent) private var accent
    @State private var targeted = false

    func body(content: Content) -> some View {
        content
            .background { if targeted { RoundedRectangle(cornerRadius: 8, style: .continuous).fill(accent.opacity(0.18)) } }
            .dropDestination(for: CategoryDragItem.self) { items, _ in
                Task { for item in items { await library.moveCategory(item.path, toParent: nil, before: nil) } }
                return !items.isEmpty
            } isTargeted: { targeted = $0 }
    }
}

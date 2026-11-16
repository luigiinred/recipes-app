import SwiftUI

/// The panel at a Mac window's trailing edge, where `.panel` content opens; one opened from inside a panel stacks on top.
@MainActor
@Observable
final class PanelHost {
    struct Entry: Identifiable {
        let id: UUID
        let content: AnyView
        let close: () -> Void
    }

    private(set) var stack: [Entry] = []

    var top: Entry? { stack.last }

    func contains(_ id: UUID) -> Bool { stack.contains { $0.id == id } }

    func show(_ id: UUID, content: AnyView, close: @escaping () -> Void) {
        let entry = Entry(id: id, content: content, close: close)
        if let index = stack.firstIndex(where: { $0.id == id }) { stack[index] = entry } else { stack.append(entry) }
    }

    /// Takes the entry off along with anything opened from it.
    func remove(_ id: UUID) {
        guard let index = stack.firstIndex(where: { $0.id == id }) else { return }
        stack.removeSubrange(index...)
    }

    func closeTop() { top?.close() }

    func closeAll() {
        for entry in stack.reversed() { entry.close() }
    }
}

struct DismissPanelAction {
    let close: () -> Void
}

extension EnvironmentValues {
    @Entry var dismissPanel: DismissPanelAction?
}

/// Closes the view's sheet, or its panel when it opened in one.
@MainActor
@propertyWrapper
struct SheetDismiss: DynamicProperty {
    @Environment(\.dismiss) private var system
    @Environment(\.dismissPanel) private var panel

    init() {}

    var wrappedValue: () -> Void {
        if let panel { return panel.close }
        let system = system
        return { system() }
    }
}

private struct PanelTitleKey: PreferenceKey {
    static let defaultValue: String? = nil
    static func reduce(value: inout String?, nextValue: () -> String?) { value = value ?? nextValue() }
}

private struct SheetFrame: ViewModifier {
    @Environment(\.dismissPanel) private var panel
    let minWidth: CGFloat
    let idealWidth: CGFloat?
    let minHeight: CGFloat
    let idealHeight: CGFloat?

    func body(content: Content) -> some View {
        if panel == nil {
            content.frame(minWidth: minWidth, idealWidth: idealWidth, minHeight: minHeight, idealHeight: idealHeight)
        } else {
            content
        }
    }
}

extension View {
    /// A sheet's size on Mac; in a panel the column sets the size instead.
    func sheetFrame(minWidth: CGFloat, idealWidth: CGFloat? = nil, minHeight: CGFloat, idealHeight: CGFloat? = nil) -> some View {
        modifier(SheetFrame(minWidth: minWidth, idealWidth: idealWidth, minHeight: minHeight, idealHeight: idealHeight))
    }

    /// The navigation title, which a panel shows in its own header since a Mac panel draws no navigation bar.
    func panelTitle(_ title: String) -> some View {
        navigationTitle(title).preference(key: PanelTitleKey.self, value: title)
    }

    /// A window with a panel host shows `.panel` content beside it, instead of in a sheet.
    /// In a narrow window the sidebar hides while a panel is open, to make room, and comes back when it closes.
    func panelHost(sidebar: Binding<NavigationSplitViewVisibility>) -> some View { modifier(PanelHostModifier(sidebar: sidebar)) }

    /// A sheet, except in a Mac window, where it opens in the panel at the window's trailing edge.
    func panel(isPresented: Binding<Bool>, onDismiss: (() -> Void)? = nil, @ViewBuilder content: @escaping () -> some View) -> some View {
        modifier(PanelPresenter(key: isPresented.wrappedValue ? AnyHashable(true) : nil, close: { isPresented.wrappedValue = false },
                                onDismiss: onDismiss, panel: content))
    }

    func panel<Item: Identifiable>(item: Binding<Item?>, onDismiss: (() -> Void)? = nil,
                                   @ViewBuilder content: @escaping (Item) -> some View) -> some View {
        let value = item.wrappedValue
        return modifier(PanelPresenter(key: value.map { AnyHashable($0.id) }, close: { item.wrappedValue = nil }, onDismiss: onDismiss) {
            if let value { content(value) }
        })
    }
}

private struct PanelHostModifier: ViewModifier {
    @Binding var sidebar: NavigationSplitViewVisibility
    @State private var host = PanelHost()
    @State private var width: CGFloat = 0
    @State private var sidebarBeforePanel: NavigationSplitViewVisibility?
    /// The last panel shown, kept while the column collapses: emptying it mid-animation sends AppKit's layout into a loop that aborts.
    @State private var shown: PanelHost.Entry?

    func body(content: Content) -> some View {
        content
            .inspector(isPresented: Binding(get: { host.top != nil }, set: { if !$0 { host.closeAll() } })) {
                // Only the top panel is drawn, so a covered one's toolbar buttons don't linger.
                ZStack {
                    if let entry = host.top ?? shown { PanelFrame(content: entry.content).id(entry.id) }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .onChange(of: host.top?.id) {
                    if let top = host.top { shown = top }
                }
                .onDisappear { shown = nil }
                .background {
                    // Esc closes the top panel wherever the focus is.
                    Button("Close") { host.closeTop() }.keyboardShortcut(.cancelAction).hidden()
                }
                .inspectorColumnWidth(min: 340, ideal: 420, max: 760)
            }
            .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { width = $0 }
            .onChange(of: host.top == nil) { _, closed in
                if !closed, width < 1100, sidebar != .detailOnly {
                    sidebarBeforePanel = sidebar
                    sidebar = .detailOnly
                } else if closed, let before = sidebarBeforePanel {
                    sidebar = before
                    sidebarBeforePanel = nil
                }
            }
            .environment(host)
    }
}

private struct PanelFrame: View {
    let content: AnyView
    @State private var title: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let title, !title.isEmpty {
                Text(title)
                    .appFont(.title3, weight: .bold)
                    .lineLimit(2)
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
                    .padding(.bottom, 4)
                    .accessibilityAddTraits(.isHeader)
            }
            content
        }
        .onPreferenceChange(PanelTitleKey.self) { title = $0 }
    }
}

private struct PanelPresenter<Panel: View>: ViewModifier {
    @Environment(PanelHost.self) private var host: PanelHost?
    let key: AnyHashable?
    let close: () -> Void
    let onDismiss: (() -> Void)?
    @ViewBuilder let panel: () -> Panel
    @State private var id = UUID()

    /// Works after the presenting view has left, as one inside a covered panel has.
    private func finish(in host: PanelHost) -> () -> Void {
        { [id, close, onDismiss] in
            close()
            guard host.contains(id) else { return }
            host.remove(id)
            onDismiss?()
        }
    }

    func body(content: Content) -> some View {
        let inPanel = host != nil
        content
            .onChange(of: key, initial: true) { _, _ in update(inPanel: inPanel) }
            .onDisappear {
                // A presenter inside a panel leaves whenever another panel covers it; only one in the window closes its panel.
                guard let host, host.stack.first?.id == id else { return }
                finish(in: host)()
            }
            .sheet(isPresented: Binding(get: { key != nil && !inPanel }, set: { if !$0 { close() } }), onDismiss: onDismiss, content: panel)
    }

    private func update(inPanel: Bool) {
        guard let host else { return }
        if key != nil, inPanel {
            let finish = finish(in: host)
            host.show(id, content: AnyView(panel().environment(\.dismissPanel, DismissPanelAction(close: finish))), close: finish)
        } else if host.contains(id) {
            host.remove(id)
            if key == nil { onDismiss?() }
        }
    }
}

import SwiftUI

extension GeometryProxy {
    /// The fold of an unfolded iPhone Duo held like a book, in this view's space, when it runs down through the view.
    var verticalFold: CGRect? {
        #if os(iOS)
        if #available(iOS 27.1, *) {
            return reservedRegions(kind: .division).first { $0.isActive && $0.frame.height > $0.frame.width }?.frame
        }
        #endif
        return nil
    }
}

extension View {
    /// Closes the tab view's sidebar while the device is unfolded, so this screen gets both pages.
    func collapsesSidebarWhenUnfolded() -> some View { modifier(UnfoldedSidebarCollapse()) }
}

private struct UnfoldedSidebarCollapse: ViewModifier {
    @State private var unfolded = false

    func body(content: Content) -> some View {
        #if os(iOS)
        if #available(iOS 27.1, *) {
            content
                .onHingeChange { _, new in unfolded = new.hinge.map { $0.status != .closed } ?? false }
                .background { if unfolded { SidebarCollapser() } }
        } else {
            content
        }
        #else
        content
        #endif
    }
}

#if os(iOS)
// SwiftUI's sidebar-adaptable TabView has no sidebar visibility binding; its UITabBarController does.
private struct SidebarCollapser: UIViewRepresentable {
    func makeUIView(context: Context) -> UIView { CollapsingView() }
    func updateUIView(_ uiView: UIView, context: Context) {}

    final class CollapsingView: UIView {
        override func didMoveToWindow() {
            super.didMoveToWindow()
            guard window != nil else { return }
            var responder: UIResponder? = self
            while let next = responder?.next {
                if let tabs = next as? UITabBarController {
                    tabs.sidebar.isHidden = true
                    return
                }
                responder = next
            }
        }
    }
}
#endif

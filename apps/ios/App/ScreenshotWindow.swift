#if os(macOS)
import AppKit
import SwiftUI

/// Sizes the window from RECIPES_WINDOW_SIZE (for example "1280x800"), puts it on the primary display and, with RECIPES_APPEARANCE=light, forces light mode, so App Store captures are repeatable.
private final class WindowSizerView: NSView {
    override func viewDidMoveToWindow() {
        if ProcessInfo.processInfo.environment["RECIPES_APPEARANCE"] == "light" {
            NSApp.appearance = NSAppearance(named: .aqua)
            window?.appearance = NSAppearance(named: .aqua)
        }
        guard let window, let spec = ProcessInfo.processInfo.environment["RECIPES_WINDOW_SIZE"],
              let screen = NSScreen.screens.first else { return }
        let parts = spec.split(separator: "x").compactMap { Double($0) }
        guard parts.count == 2 else { return }
        let area = screen.visibleFrame
        let size = CGSize(width: min(parts[0], area.width), height: min(parts[1], area.height))
        window.setFrame(CGRect(x: area.minX + 60, y: area.maxY - size.height - 20, width: size.width, height: size.height), display: true)
    }
}

private struct WindowSizer: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView { WindowSizerView() }
    func updateNSView(_ view: NSView, context: Context) {}
}

extension View {
    func sizedFromEnvironment() -> some View { background(WindowSizer()) }
}
#endif

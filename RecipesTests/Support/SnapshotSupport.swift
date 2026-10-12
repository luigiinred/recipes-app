import SnapshotTesting
import SwiftUI
import Testing
@testable import Recipes
#if os(iOS)
import UIKit
#else
import AppKit
#endif

enum SnapshotEnvironment {
    /// Text rendering shifts between OS releases, so references only compare
    /// against images drawn by the same major.minor. Re-record when bumping.
    static let osVersion = (major: 27, minor: 0)

    #if os(iOS)
    struct Device {
        let prefix: String?
        let config: (UIUserInterfaceStyle) -> ViewImageConfig
    }

    /// iPhone 17 portrait: 402×874pt @3x.
    static let iPhone = Device(prefix: nil) { style in
        ViewImageConfig(
            safeArea: UIEdgeInsets(top: 62, left: 0, bottom: 34, right: 0),
            size: CGSize(width: 402, height: 874),
            traits: traits(idiom: .phone, scale: 3, horizontal: .compact, style: style)
        )
    }

    /// iPhone 17 landscape: compact in both directions.
    static let iPhoneLandscape = Device(prefix: "iPhoneLandscape") { style in
        ViewImageConfig(
            safeArea: UIEdgeInsets(top: 0, left: 62, bottom: 21, right: 62),
            size: CGSize(width: 874, height: 402),
            traits: traits(idiom: .phone, scale: 2, horizontal: .compact, vertical: .compact, style: style)
        )
    }

    /// A book-style dual-screen or foldable canvas: about 4:3 and regular in both directions.
    static let unfolded = Device(prefix: "unfolded") { style in
        ViewImageConfig(
            safeArea: UIEdgeInsets(top: 48, left: 0, bottom: 24, right: 0),
            size: CGSize(width: 780, height: 700),
            traits: traits(idiom: .pad, scale: 2, horizontal: .regular, style: style)
        )
    }


    private static func traits(
        idiom: UIUserInterfaceIdiom, scale: CGFloat, horizontal: UIUserInterfaceSizeClass,
        vertical: UIUserInterfaceSizeClass = .regular, style: UIUserInterfaceStyle
    ) -> UITraitCollection {
        UITraitCollection { traits in
            traits.userInterfaceIdiom = idiom
            traits.displayScale = scale
            traits.horizontalSizeClass = horizontal
            traits.verticalSizeClass = vertical
            traits.userInterfaceStyle = style
            traits.preferredContentSizeCategory = .large
        }
    }
    #else
    /// A typical Mac window.
    static let macWindow = CGSize(width: 1100, height: 700)
    /// A sheet or dialog.
    static let macSheet = CGSize(width: 520, height: 640)
    /// A narrow window, where side-by-side layouts stack.
    static let macNarrow = CGSize(width: 620, height: 700)
    #endif

    static var macSheetSize: CGSize? {
        #if os(macOS)
        macSheet
        #else
        nil
        #endif
    }
}

/// How many canvases a screen gets. Dark mode and odd sizes are only worth capturing where they can differ.
enum SnapshotCoverage {
    /// Simple forms and pickers: one light capture.
    case sheet
    /// A normal screen: light and dark on iPhone, light on the Mac.
    case screen
    /// A screen whose layout changes with width: adds landscape, an unfolded/iPad-sized canvas, and a narrow Mac window.
    case adaptive
}

/// Snapshots `page` on the canvases its coverage calls for, with sample data in the environment, with sample data in the environment. Files are `<test>.light.png`,
/// `<test>.dark.png`, `<test>.iPad-light.png`, `<test>.mac-dark.png`, …
@MainActor
func assertPageSnapshots<Page: View>(
    of page: Page,
    named name: String? = nil,
    inNavigationStack: Bool = true,
    macSize: CGSize? = nil,
    coverage: SnapshotCoverage = .screen,
    record: SnapshotTestingConfiguration.Record? = nil,
    fileID: StaticString = #fileID,
    file filePath: StaticString = #filePath,
    testName: String = #function,
    line: UInt = #line,
    column: UInt = #column
) {
    guard isPinnedOSVersion() else { return }
    #if os(iOS)
    UIView.setAnimationsEnabled(false)
    #endif
    let content = inNavigationStack ? AnyView(NavigationStack { page }) : AnyView(page)
    // The offscreen renderer can't draw the glass scroll-edge effect; it paints those areas black.
    let root = AnyView(content.withSampleEnvironment()).hidingScrollEdgeEffect()

    func snapshotName(_ parts: String?...) -> String {
        ([name] + parts).compactMap { $0 }.joined(separator: "-")
    }

    #if os(iOS)
    let canvases: [(SnapshotEnvironment.Device, [UIUserInterfaceStyle])]
    switch coverage {
    case .sheet: canvases = [(SnapshotEnvironment.iPhone, [.light])]
    case .screen: canvases = [(SnapshotEnvironment.iPhone, [.light, .dark])]
    case .adaptive:
        canvases = [
            (SnapshotEnvironment.iPhone, [.light, .dark]),
            (SnapshotEnvironment.iPhoneLandscape, [.light]),
            (SnapshotEnvironment.unfolded, [.light]),
        ]
    }
    for (device, styles) in canvases {
        for style in styles {
            assertSnapshot(
                of: root,
                as: .wait(for: 0.9, on: .image(drawHierarchyInKeyWindow: true, precision: 0.98, perceptualPrecision: 0.97, layout: .device(config: device.config(style)))),
                named: snapshotName(device.prefix, style == .dark ? "dark" : "light"),
                record: record,
                fileID: fileID, file: filePath, testName: testName, line: line, column: column
            )
        }
    }
    #else
    let size = macSize ?? SnapshotEnvironment.macWindow
    var variants: [(NSAppearance.Name, String, CGSize, String?)] = [(.aqua, "light", size, nil)]
    if coverage == .adaptive {
        variants += [(.aqua, "light", SnapshotEnvironment.macNarrow, "narrow"), (.darkAqua, "dark", size, nil)]
    }
    for (appearance, styleName, size, sizeName) in variants {
        let host = NSHostingController(rootView: root.environment(\.controlActiveState, .inactive))
        host.view.appearance = NSAppearance(named: appearance)
        host.view.frame = CGRect(origin: .zero, size: size)
        // Sidebar-style lists only lay out their rows inside a window.
        let window = NSWindow(contentViewController: host)
        window.setContentSize(size)
        host.view.layoutSubtreeIfNeeded()
        RunLoop.main.run(until: Date().addingTimeInterval(0.25))
        window.displayIfNeeded()
        defer { window.close() }
        assertSnapshot(
            of: host,
            as: .image(precision: 0.995, perceptualPrecision: 0.98, size: size),
            named: snapshotName("mac", sizeName, styleName),
            record: record,
            fileID: fileID, file: filePath, testName: testName, line: line, column: column
        )
    }
    #endif
}

/// Reference images only compare on the OS version they were drawn on.
func isPinnedOSVersion() -> Bool {
    let version = ProcessInfo.processInfo.operatingSystemVersion
    let pinned = SnapshotEnvironment.osVersion
    guard version.majorVersion == pinned.major, version.minorVersion == pinned.minor else {
        Issue.record(
            "Snapshots are pinned to \(pinned.major).\(pinned.minor); this run is \(version.majorVersion).\(version.minorVersion). Re-record before comparing."
        )
        return false
    }
    return true
}

private extension View {
    @ViewBuilder
    func hidingScrollEdgeEffect() -> some View {
        if #available(iOS 26.0, macOS 26.0, *) {
            scrollEdgeEffectHidden(true, for: .all)
        } else {
            self
        }
    }
}

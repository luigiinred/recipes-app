#if os(iOS)
import SwiftUI
import UIKit

/// `Color.accentColor` follows UIKit's tint, which SwiftUI's `.tint` reaches inside a navigation stack but not in a full-screen cover or a sheet.
@MainActor
enum ThemeTint {
    static func apply(_ color: Color) {
        let tint = UIColor(color)
        UIView.appearance().tintColor = tint
        for window in UIApplication.shared.connectedScenes.compactMap({ ($0 as? UIWindowScene)?.windows }).flatMap({ $0 }) {
            window.tintColor = tint
        }
    }
}

/// Navigation titles and tab labels are drawn by UIKit, which ignores SwiftUI's font design, so they get the chosen design here.
@MainActor
enum ThemeFonts {
    private static var applied: FontStyle?

    static func apply(_ style: FontStyle) {
        // Snapshot tests render the same views in one process; they keep UIKit's own fonts so references stay stable.
        guard ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] == nil, style != applied else { return }
        applied = style

        let title: [NSAttributedString.Key: Any] = [.font: font(style, .headline, .semibold)]
        let largeTitle: [NSAttributedString.Key: Any] = [.font: font(style, .largeTitle, .bold)]
        let tabLabel: [NSAttributedString.Key: Any] = [.font: font(style, .caption2, .medium)]

        let bar = UINavigationBar.appearance()
        bar.titleTextAttributes = title
        bar.largeTitleTextAttributes = largeTitle
        let item = UITabBarItem.appearance()
        for state in [UIControl.State.normal, .selected] { item.setTitleTextAttributes(tabLabel, for: state) }

        for window in UIApplication.shared.connectedScenes.compactMap({ ($0 as? UIWindowScene)?.windows }).flatMap({ $0 }) {
            restyle(window, title: title, largeTitle: largeTitle, tabLabel: tabLabel)
        }
    }

    private static func font(_ style: FontStyle, _ textStyle: UIFont.TextStyle, _ weight: UIFont.Weight) -> UIFont {
        let size = UIFont.preferredFont(forTextStyle: textStyle).pointSize
        let base = UIFont.systemFont(ofSize: size, weight: weight)
        let design: UIFontDescriptor.SystemDesign
        switch style {
        case .serif: design = .serif
        case .sans: return base
        case .rounded: design = .rounded
        case .monospaced: design = .monospaced
        }
        guard let descriptor = base.fontDescriptor.withDesign(design) else { return base }
        return UIFont(descriptor: descriptor, size: size)
    }

    /// Bars that are already on screen keep the attributes they were made with, so they are updated in place.
    private static func restyle(_ view: UIView, title: [NSAttributedString.Key: Any], largeTitle: [NSAttributedString.Key: Any], tabLabel: [NSAttributedString.Key: Any]) {
        if let bar = view as? UINavigationBar {
            bar.titleTextAttributes = title
            bar.largeTitleTextAttributes = largeTitle
            bar.setNeedsLayout()
        } else if let bar = view as? UITabBar {
            for item in bar.items ?? [] {
                for state in [UIControl.State.normal, .selected] { item.setTitleTextAttributes(tabLabel, for: state) }
            }
        }
        for subview in view.subviews { restyle(subview, title: title, largeTitle: largeTitle, tabLabel: tabLabel) }
    }
}
#endif

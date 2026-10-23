#if os(iOS)
import SwiftUI
import UIKit

/// Turns between pages with a page curl, like a printed cookbook, keeping `index` in step with the page on screen.
struct PageCurl<Page: View>: UIViewControllerRepresentable {
    let count: Int
    @Binding var index: Int
    @ViewBuilder let page: (Int) -> Page

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIViewController(context: Context) -> UIPageViewController {
        let pages = UIPageViewController(
            transitionStyle: .pageCurl, navigationOrientation: .horizontal,
            options: [.spineLocation: NSNumber(value: UIPageViewController.SpineLocation.min.rawValue)]
        )
        pages.dataSource = context.coordinator
        pages.delegate = context.coordinator
        pages.view.backgroundColor = .clear
        pages.setViewControllers([context.coordinator.host(for: index)], direction: .forward, animated: false)
        return pages
    }

    func updateUIViewController(_ pages: UIPageViewController, context: Context) {
        context.coordinator.parent = self
        guard let shown = pages.viewControllers?.first as? PageHost else { return }
        if shown.index == index {
            shown.rootView = AnyView(page(index))
        } else {
            pages.setViewControllers([context.coordinator.host(for: index)], direction: index > shown.index ? .forward : .reverse, animated: true)
        }
    }

    final class Coordinator: NSObject, UIPageViewControllerDataSource, UIPageViewControllerDelegate {
        var parent: PageCurl

        init(_ parent: PageCurl) { self.parent = parent }

        func host(for index: Int) -> PageHost {
            let host = PageHost(rootView: AnyView(parent.page(index)))
            host.index = index
            host.view.backgroundColor = .clear
            return host
        }

        func pageViewController(_ pages: UIPageViewController, viewControllerBefore controller: UIViewController) -> UIViewController? {
            guard let index = (controller as? PageHost)?.index, index > 0 else { return nil }
            return host(for: index - 1)
        }

        func pageViewController(_ pages: UIPageViewController, viewControllerAfter controller: UIViewController) -> UIViewController? {
            guard let index = (controller as? PageHost)?.index, index + 1 < parent.count else { return nil }
            return host(for: index + 1)
        }

        func pageViewController(
            _ pages: UIPageViewController, didFinishAnimating finished: Bool,
            previousViewControllers: [UIViewController], transitionCompleted completed: Bool
        ) {
            guard completed, let index = (pages.viewControllers?.first as? PageHost)?.index else { return }
            parent.index = index
        }
    }

    final class PageHost: UIHostingController<AnyView> {
        var index = 0
    }
}
#endif

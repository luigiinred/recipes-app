import SwiftUI
import UniformTypeIdentifiers

#if os(iOS)
import UIKit
typealias PlatformViewController = UIViewController
#else
import AppKit
typealias PlatformViewController = NSViewController
#endif

final class ShareViewController: PlatformViewController {
    private var host: PlatformViewController?

    private func makeView() -> ShareView {
        ShareView(
            loadURL: { [weak self] in await self?.sharedURL() },
            finish: { [weak self] in self?.extensionContext?.completeRequest(returningItems: nil) },
            cancel: { [weak self] in self?.extensionContext?.cancelRequest(withError: CocoaError(.userCancelled)) },
            openApp: { [weak self] url in self?.open(url) }
        )
    }

    private func sharedURL() async -> URL? {
        let providers = (extensionContext?.inputItems as? [NSExtensionItem] ?? []).flatMap { $0.attachments ?? [] }
        for provider in providers where provider.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
            if let item = try? await provider.loadItem(forTypeIdentifier: UTType.url.identifier),
               let url = item as? URL, url.scheme?.hasPrefix("http") == true { return url }
        }
        for provider in providers where provider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) {
            if let item = try? await provider.loadItem(forTypeIdentifier: UTType.plainText.identifier),
               let text = item as? String,
               let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue),
               let match = detector.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
               let url = match.url { return url }
        }
        return nil
    }

    /// Opens the app, then closes the share sheet.
    private func open(_ url: URL) {
        #if os(iOS)
        var responder: UIResponder? = self
        while let current = responder {
            if let application = current as? UIApplication {
                application.open(url, options: [:], completionHandler: nil)
                break
            }
            responder = current.next
        }
        #else
        NSWorkspace.shared.open(url)
        #endif
        extensionContext?.completeRequest(returningItems: nil)
    }

    #if os(iOS)
    override func viewDidLoad() {
        super.viewDidLoad()
        UIView.appearance().tintColor = UIColor(Theme.defaultAccent)
        let controller = UIHostingController(rootView: makeView())
        addChild(controller)
        controller.view.frame = view.bounds
        controller.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(controller.view)
        controller.didMove(toParent: self)
        host = controller
    }
    #else
    override func loadView() {
        view = NSHostingView(rootView: makeView())
        preferredContentSize = NSSize(width: 520, height: 680)
    }
    #endif
}

import RecipeKit
import SwiftUI
import WebKit

@MainActor
final class YouTubePlayerController: ObservableObject {
    @Published private(set) var isShown = false
    @Published private(set) var errorMessage: String?
    @Published fileprivate(set) var isPlaying = false
    private(set) var startSeconds = 0
    fileprivate weak var webView: WKWebView?
    fileprivate var isReady = false

    func play(from seconds: Int = 0) {
        startSeconds = seconds
        errorMessage = nil
        if isShown, isReady {
            webView?.evaluateJavaScript("seekTo(\(seconds))")
        }
        isShown = true
    }

    func pause() {
        webView?.evaluateJavaScript("if (player && player.pauseVideo) { player.pauseVideo(); }")
    }

    fileprivate func fail(_ message: String) { errorMessage = message }
}

struct YouTubePlayerWebView: PlatformViewRepresentable {
    let videoID: String
    @ObservedObject var controller: YouTubePlayerController

    func makeCoordinator() -> Coordinator { Coordinator(controller) }

    private func makeWebView(_ context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        #if os(iOS)
        configuration.allowsInlineMediaPlayback = true
        configuration.mediaTypesRequiringUserActionForPlayback = []
        #endif
        configuration.userContentController.add(context.coordinator, name: "player")
        let webView = WKWebView(frame: .zero, configuration: configuration)
        #if os(iOS)
        webView.scrollView.isScrollEnabled = false
        webView.isOpaque = false
        #endif
        controller.webView = webView
        webView.loadHTMLString(Self.html(videoID: videoID, start: controller.startSeconds), baseURL: URL(string: Self.origin))
        return webView
    }

    #if os(iOS)
    func makeUIView(context: Context) -> WKWebView { makeWebView(context) }
    func updateUIView(_ view: WKWebView, context: Context) {}
    #else
    func makeNSView(context: Context) -> WKWebView { makeWebView(context) }
    func updateNSView(_ view: WKWebView, context: Context) {}
    #endif

    // YouTube rejects embeds that don't identify the host app (errors 152/153), so use the bundle ID as the origin.
    static let origin = "https://" + (Bundle.main.bundleIdentifier ?? "com.garrabrant.recipes").lowercased()

    static func html(videoID: String, start: Int) -> String {
        """
        <html><head><meta name="viewport" content="width=device-width,initial-scale=1">
        <style>html,body{margin:0;height:100%;background:#000}#p{position:absolute;inset:0;width:100%;height:100%}</style></head>
        <body><div id="p"></div>
        <script src="https://www.youtube.com/iframe_api"></script>
        <script>
        var player;
        function onYouTubeIframeAPIReady() {
          player = new YT.Player('p', {
            videoId: '\(videoID)', width: '100%', height: '100%',
            playerVars: { playsinline: 1, autoplay: 1, start: \(start), rel: 0, origin: '\(origin)', widget_referrer: '\(origin)' },
            events: {
              onReady: function() { window.webkit.messageHandlers.player.postMessage('ready'); },
              onStateChange: function(e) { window.webkit.messageHandlers.player.postMessage('state:' + e.data); },
              onError: function(e) { window.webkit.messageHandlers.player.postMessage('error:' + e.data); }
            }
          });
        }
        function seekTo(s) { if (player && player.seekTo) { player.seekTo(s, true); player.playVideo(); } }
        </script></body></html>
        """
    }

    final class Coordinator: NSObject, WKScriptMessageHandler {
        let controller: YouTubePlayerController
        init(_ controller: YouTubePlayerController) { self.controller = controller }

        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            guard let body = message.body as? String else { return }
            Task { @MainActor in
                if body == "ready" {
                    controller.isReady = true
                } else if body.hasPrefix("state:") {
                    // 1 = playing, 3 = buffering
                    controller.isPlaying = ["1", "3"].contains(body.dropFirst("state:".count))
                } else if body.hasPrefix("error:") {
                    let code = String(body.dropFirst("error:".count))
                    controller.fail("This video can't be played inside the app (error \(code)). Use Open in YouTube.")
                }
            }
        }
    }
}

#if os(iOS)
typealias PlatformViewRepresentable = UIViewRepresentable
#else
typealias PlatformViewRepresentable = NSViewRepresentable
#endif

struct YouTubeEmbed: View {
    @EnvironmentObject private var library: RecipeLibrary
    let recipe: Recipe
    let videoID: String
    @ObservedObject var controller: YouTubePlayerController
    /// Where the video starts when the poster is tapped.
    var startAt = 0
    /// How far the page has scrolled past its resting position; the video shrinks and pins to the top, playing or not.
    var scrolled: CGFloat = 0
    /// A small player without the "Open in YouTube" row.
    var isCompact = false
    @State private var width: CGFloat = 0
    @State private var aspect: Double = 16 / 9

    private static let maxHeight: CGFloat = 560
    private static let compactMaxHeight: CGFloat = 150
    private static let pinMargin: CGFloat = 8
    private static let shrinkDistance: CGFloat = 160

    private var miniScale: CGFloat {
        guard width > 0 else { return 1 }
        return min(1, (width < 500 ? 168 : 280) / width)
    }

    var body: some View {
        let progress = min(1, max(0, scrolled / Self.shrinkDistance))
        VStack(alignment: .leading, spacing: 8) {
            ZStack {
                if controller.isShown {
                    YouTubePlayerWebView(videoID: videoID, controller: controller)
                } else {
                    poster
                }
            }
            .aspectRatio(aspect, contentMode: .fit)
            .frame(maxHeight: isCompact ? Self.compactMaxHeight : Self.maxHeight)
            .background(.black)
            .clipShape(RoundedRectangle(cornerRadius: isCompact ? 12 : 16 - 8 * progress))
            .frame(maxWidth: .infinity)
            .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { width = $0 }
            .task(id: videoID) { aspect = await Self.ratio(for: videoID) }
            .scaleEffect(1 - (1 - miniScale) * progress, anchor: .topTrailing)
            .offset(y: max(0, scrolled - Self.pinMargin))
            .shadow(color: .black.opacity(isCompact ? 0.25 : 0.3 * progress), radius: isCompact ? 8 : 10 * progress, y: 4)

            if let message = controller.errorMessage {
                Label(message, systemImage: "exclamationmark.triangle").font(.footnote).foregroundStyle(.orange)
            }
            if !isCompact, let url = URL(string: "https://www.youtube.com/watch?v=\(videoID)&t=\(controller.startSeconds)s") {
                Link(destination: url) { Label("Open in YouTube", systemImage: "arrow.up.right.square") }
                    .font(.footnote)
                    .foregroundStyle(Theme.accent)
            }
        }
    }

    @MainActor private static var known: [String: Double] = [:]

    private static func ratio(for id: String) async -> Double {
        if let cached = known[id] { return cached }
        let ratio = await YouTubeImporter.aspectRatio(id: id) ?? 16 / 9
        known[id] = ratio
        return ratio
    }

    private var poster: some View {
        Button { controller.play(from: startAt) } label: {
            ZStack {
                if library.hasImage(recipe.id) {
                    RecipeImageView(recipe: recipe)
                } else {
                    Color.black
                }
                Image(systemName: "play.circle.fill")
                    .font(.system(size: isCompact ? 32 : 64))
                    .foregroundStyle(.white)
                    .shadow(radius: 8)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Play video")
    }
}

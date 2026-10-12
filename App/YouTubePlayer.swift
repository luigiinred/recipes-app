import RecipeKit
import SwiftUI
import WebKit

@MainActor
final class YouTubePlayerController: ObservableObject {
    @Published private(set) var isShown = false
    @Published private(set) var errorMessage: String?
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
        webView.loadHTMLString(Self.html(videoID: videoID, start: controller.startSeconds), baseURL: URL(string: "https://www.youtube.com"))
        return webView
    }

    #if os(iOS)
    func makeUIView(context: Context) -> WKWebView { makeWebView(context) }
    func updateUIView(_ view: WKWebView, context: Context) {}
    #else
    func makeNSView(context: Context) -> WKWebView { makeWebView(context) }
    func updateNSView(_ view: WKWebView, context: Context) {}
    #endif

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
            playerVars: { playsinline: 1, autoplay: 1, start: \(start), rel: 0 },
            events: {
              onReady: function() { window.webkit.messageHandlers.player.postMessage('ready'); },
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
                } else if body.hasPrefix("error") {
                    controller.fail("This video can't be played inside the app.")
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

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack {
                if controller.isShown {
                    YouTubePlayerWebView(videoID: videoID, controller: controller)
                } else {
                    poster
                }
            }
            .aspectRatio(16 / 9, contentMode: .fit)
            .frame(maxWidth: .infinity)
            .background(.black)
            .clipShape(RoundedRectangle(cornerRadius: 16))

            if let message = controller.errorMessage {
                Label(message, systemImage: "exclamationmark.triangle").font(.footnote).foregroundStyle(.orange)
            }
            if let url = URL(string: "https://www.youtube.com/watch?v=\(videoID)&t=\(controller.startSeconds)s") {
                Link(destination: url) { Label("Open in YouTube", systemImage: "arrow.up.right.square") }
                    .font(.footnote)
                    .foregroundStyle(Theme.accent)
            }
        }
    }

    private var poster: some View {
        Button { controller.play() } label: {
            ZStack {
                if library.hasImage(recipe.id) {
                    RecipeImageView(recipe: recipe)
                } else {
                    Color.black
                }
                Image(systemName: "play.circle.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(.white)
                    .shadow(radius: 8)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Play video")
    }
}

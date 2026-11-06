import RecipeKit
import SwiftUI
import WebKit

/// A post's article text without the site's ads, sidebars and pop-ups, extracted with Mozilla's Readability.
struct ReaderArticle: Sendable {
    var title: String
    var byline: String?
    var siteName: String?
    var html: String
    var minutes: Int
}

enum ReaderTextFont: String, CaseIterable {
    case system, serif, rounded

    var title: String {
        switch self {
        case .system: "System"
        case .serif: "New York"
        case .rounded: "Rounded"
        }
    }

    var css: String {
        switch self {
        case .system: "-apple-system, system-ui, sans-serif"
        case .serif: "ui-serif, 'New York', Georgia, serif"
        case .rounded: "ui-rounded, -apple-system, system-ui, sans-serif"
        }
    }
}

enum ReaderTheme: String, CaseIterable {
    case auto, light, sepia, dark

    var title: String {
        switch self {
        case .auto: "Match App"
        case .light: "Light"
        case .sepia: "Sepia"
        case .dark: "Dark"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .auto: nil
        case .light, .sepia: .light
        case .dark: .dark
        }
    }

    var canvas: Color? {
        switch self {
        case .auto: nil
        case .light: .white
        case .sepia: Color(red: 0.973, green: 0.945, blue: 0.890)
        case .dark: Color(red: 0.11, green: 0.11, blue: 0.118)
        }
    }
}

@MainActor
enum ReaderExtractor {
    static let textSizes: [Int] = [15, 16, 17, 19, 21, 24, 28]
    private static let minimumLength = 500

    private static let script: String? = Bundle.main.url(forResource: "Readability", withExtension: "js")
        .flatMap { try? String(contentsOf: $0, encoding: .utf8) }

    /// Loads the page with its own scripts off, so its ads and trackers never run, then lets Readability pick out the article.
    static func extract(_ url: URL) async throws -> ReaderArticle {
        guard let script else { throw RecipeError.invalid("Reader isn't available.") }
        var request = URLRequest(url: url)
        request.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Mobile/15E148 Safari/604.1",
                         forHTTPHeaderField: "User-Agent")
        let (data, response) = try await URLSession.shared.data(for: request)
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            throw RecipeError.invalid("The site turned the reader away.")
        }
        let html = String(data: data, encoding: .utf8) ?? String(decoding: data, as: UTF8.self)

        var configuration = WebPage.Configuration()
        configuration.defaultNavigationPreferences.allowsContentJavaScript = false
        let page = WebPage(configuration: configuration)
        for try await _ in page.load(html: html, baseURL: response.url ?? url) {}

        let body = script + """

        const article = new Readability(document.cloneNode(true)).parse();
        return article ? { title: article.title ?? "", byline: article.byline ?? "", siteName: article.siteName ?? "",
                           content: article.content ?? "", length: article.length ?? 0 } : null;
        """
        guard let result = try await page.callJavaScript(body) as? [String: Any],
              let content = result["content"] as? String,
              let length = (result["length"] as? NSNumber)?.intValue, length >= minimumLength else {
            throw RecipeError.invalid("This page has no article to show in Reader.")
        }
        func text(_ key: String) -> String? { (result[key] as? String).flatMap { $0.isEmpty ? nil : $0 } }
        return ReaderArticle(title: text("title") ?? "", byline: text("byline"), siteName: text("siteName"),
                             html: content, minutes: max(1, Int((Double(length) / 1100).rounded())))
    }

    static func document(for article: ReaderArticle, entry: FeedEntry, style: String, theme: ReaderTheme) -> String {
        let title = article.title.isEmpty ? entry.title : article.title
        let site = article.siteName ?? entry.link.host()?.replacingOccurrences(of: "www.", with: "") ?? ""
        let meta = [article.byline, "\(article.minutes) min read"].compactMap { $0 }.joined(separator: " · ")
        return """
        <!doctype html><html data-theme="\(theme.rawValue)" style="\(style)"><head>
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <style>\(css)</style></head><body>
        <header><div class="site">\(escape(site))</div><h1>\(escape(title))</h1><div class="meta">\(escape(meta))</div></header>
        <article>\(article.html)</article>
        </body></html>
        """
    }

    static func style(size: Int, font: ReaderTextFont, accent: Color) -> String {
        let px = textSizes[min(max(size, 0), textSizes.count - 1)]
        let resolved = accent.resolve(in: EnvironmentValues())
        let rgb = "rgb(\(Int(resolved.red * 255)), \(Int(resolved.green * 255)), \(Int(resolved.blue * 255)))"
        return "--size: \(px)px; --font: \(font.css); --accent: \(rgb);"
    }

    private static func escape(_ text: String) -> String {
        text.replacingOccurrences(of: "&", with: "&amp;").replacingOccurrences(of: "<", with: "&lt;").replacingOccurrences(of: ">", with: "&gt;")
    }

    private static let css = """
    :root { color-scheme: light dark; --ink: #1c1c1e; --muted: #6e6e73; --rule: rgba(60,60,67,.18); --bg: transparent; }
    @media (prefers-color-scheme: dark) { :root { --ink: #f2f2f7; --muted: #a1a1a6; --rule: rgba(235,235,245,.18); } }
    html[data-theme=light] { color-scheme: light; --ink: #1c1c1e; --muted: #6e6e73; --rule: rgba(60,60,67,.18); --bg: #fff; }
    html[data-theme=sepia] { color-scheme: light; --ink: #5b4636; --muted: #8a7560; --rule: rgba(91,70,54,.2); --bg: #f8f1e3; }
    html[data-theme=dark] { color-scheme: dark; --ink: #e5e5ea; --muted: #a1a1a6; --rule: rgba(235,235,245,.18); --bg: #1c1c1e; }
    html { background: var(--bg); -webkit-text-size-adjust: none; }
    body { margin: 0 auto; max-width: 680px; padding: 8px 22px 80px; color: var(--ink);
           font: var(--size)/1.6 var(--font); overflow-wrap: break-word; }
    header { margin-bottom: 1.4em; padding-bottom: 1em; border-bottom: .5px solid var(--rule); }
    .site { font: 600 .72em -apple-system, system-ui; letter-spacing: .04em; text-transform: uppercase; color: var(--muted); }
    h1 { font-size: 1.6em; line-height: 1.15; margin: .3em 0; letter-spacing: -.01em; }
    .meta { font: .8em -apple-system, system-ui; color: var(--muted); }
    h2, h3, h4 { line-height: 1.25; margin: 1.4em 0 .5em; }
    a { color: var(--accent); text-decoration: none; }
    img, video, iframe, svg { max-width: 100%; height: auto; border-radius: 14px; }
    figure { margin: 1.4em 0; } figcaption, .caption { font-size: .78em; color: var(--muted); margin-top: .5em; }
    blockquote { margin: 1.2em 0; padding-left: 1em; border-left: 3px solid var(--accent); color: var(--muted); font-style: italic; }
    pre, table { display: block; overflow-x: auto; max-width: 100%; }
    pre, code { font-size: .85em; }
    hr { border: 0; border-top: .5px solid var(--rule); margin: 2em 0; }
    """
}

/// Opens tapped links in the browser instead of inside the reader.
private struct ReaderLinks: WebPage.NavigationDeciding {
    let open: @MainActor (URL) -> Void

    func decidePolicy(for action: WebPage.NavigationAction, preferences: inout WebPage.NavigationPreferences) async -> WKNavigationActionPolicy {
        guard action.navigationType == .linkActivated, let url = action.request.url else { return .allow }
        await open(url)
        return .cancel
    }
}

struct ArticleReader: View {
    @EnvironmentObject private var loader: FeedLoader
    @Environment(\.appAccent) private var accent
    @Environment(\.openURL) private var openURL
    @AppStorage(AppSettings.Key.readerTextSize) private var size = 3
    @AppStorage(AppSettings.Key.readerFont) private var font = ReaderTextFont.serif
    @AppStorage(AppSettings.Key.readerTheme) private var theme = ReaderTheme.auto
    let entry: FeedEntry

    @State private var page: WebPage?
    @State private var failed = false

    var body: some View {
        Group {
            if let page {
                WebView(page)
                    .webViewContentBackground(.hidden)
                    .background(theme.canvas.map { AnyShapeStyle($0) } ?? AnyShapeStyle(.clear))
                    .ignoresSafeArea(edges: .bottom)
            } else if failed {
                WebView(url: entry.link)
            } else {
                ProgressView("Opening in Reader…").frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .preferredColorScheme(page == nil ? nil : theme.colorScheme)
        .navigationTitle(page == nil && failed ? entry.title : "")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            if page != nil {
                ToolbarItem(placement: .primaryAction) { appearanceMenu }
            }
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button { toggleViewed() } label: {
                        if loader.isViewed(entry) { Label("Mark as New", systemImage: "circle") }
                        else { Label("Mark as Viewed", systemImage: "checkmark.circle") }
                    }
                    ShareLink(item: entry.link) { Label("Share", systemImage: "square.and.arrow.up") }
                    Link(destination: entry.link) { Label("Open in Browser", systemImage: "safari") }
                } label: {
                    Label("More", systemImage: "ellipsis")
                }
            }
        }
        .task(id: entry.id) { await open() }
        .onChange(of: size) { applyStyle() }
        .onChange(of: font) { applyStyle() }
        .onChange(of: theme) { applyStyle() }
    }

    private var appearanceMenu: some View {
        Menu {
            ControlGroup {
                Button { size = max(0, size - 1) } label: { Label("Smaller", systemImage: "textformat.size.smaller") }
                    .disabled(size == 0)
                Button { size = min(ReaderExtractor.textSizes.count - 1, size + 1) } label: { Label("Larger", systemImage: "textformat.size.larger") }
                    .disabled(size == ReaderExtractor.textSizes.count - 1)
            }
            Picker("Font", selection: $font) {
                ForEach(ReaderTextFont.allCases, id: \.self) { Text($0.title).tag($0) }
            }
            Picker("Page", selection: $theme) {
                ForEach(ReaderTheme.allCases, id: \.self) { Text($0.title).tag($0) }
            }
        } label: {
            Label("Reader Settings", systemImage: "textformat.size")
        }
    }

    private func open() async {
        do {
            let article = try await ReaderExtractor.extract(entry.link)
            var configuration = WebPage.Configuration()
            configuration.defaultNavigationPreferences.allowsContentJavaScript = false
            let page = WebPage(configuration: configuration, navigationDecider: ReaderLinks { openURL($0) })
            for try await _ in page.load(html: ReaderExtractor.document(for: article, entry: entry, style: currentStyle, theme: theme), baseURL: entry.link) {}
            withAnimation(.easeOut(duration: 0.2)) { self.page = page }
        } catch {
            failed = true
        }
    }

    private var currentStyle: String { ReaderExtractor.style(size: size, font: font, accent: accent) }

    private func applyStyle() {
        guard let page else { return }
        let style = currentStyle, theme = theme.rawValue
        Task {
            _ = try? await page.callJavaScript("document.documentElement.setAttribute('style', style); document.documentElement.dataset.theme = theme;",
                                               arguments: ["style": style, "theme": theme])
        }
    }

    private func toggleViewed() {
        if loader.isViewed(entry) { loader.markNew([entry.id]) } else { loader.markViewed([entry.id]) }
    }
}

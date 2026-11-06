import AppIntents
import RecipeKit
import SwiftUI
import WidgetKit

// MARK: - Configuration

struct FeedChoice: AppEntity {
    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Feed"
    static let defaultQuery = FeedChoiceQuery()

    let id: String
    let title: String

    var displayRepresentation: DisplayRepresentation { DisplayRepresentation(title: "\(title)") }
}

struct FeedChoiceQuery: EntityQuery {
    private var followed: [FeedChoice] {
        (WidgetStore.shared?.loadFeeds().feeds ?? []).map { FeedChoice(id: $0.url, title: $0.title) }
    }

    func entities(for identifiers: [String]) async throws -> [FeedChoice] {
        followed.filter { identifiers.contains($0.id) }
    }

    func suggestedEntities() async throws -> [FeedChoice] { followed }
}

struct FeedsWidgetIntent: WidgetConfigurationIntent {
    static let title: LocalizedStringResource = "Feeds"
    static let description = IntentDescription("Show the newest posts from one feed, or from all the feeds you follow.")

    @Parameter(title: "Feed", description: "Leave empty to show every feed.")
    var feed: FeedChoice?
}

// MARK: - Timeline

struct FeedsEntry: TimelineEntry {
    let date: Date
    let snapshot: FeedWidgetSnapshot
    let feed: FeedChoice?
    let store: WidgetStore?

    var posts: [FeedWidgetSnapshot.Post] { snapshot.posts(from: feed?.id) }
    var title: String { feed?.title ?? "Feeds" }
}

struct FeedsProvider: AppIntentTimelineProvider {
    static let shownPosts = 6
    static let staleAfter: TimeInterval = 30 * 60
    static let refreshEvery: TimeInterval = 60 * 60

    func placeholder(in context: Context) -> FeedsEntry {
        FeedsEntry(date: Date(), snapshot: .sample, feed: nil, store: nil)
    }

    func snapshot(for configuration: FeedsWidgetIntent, in context: Context) async -> FeedsEntry {
        guard !context.isPreview, let store = WidgetStore.shared else { return placeholder(in: context) }
        let snapshot = store.loadFeeds()
        return FeedsEntry(date: Date(), snapshot: snapshot.feeds.isEmpty ? .sample : snapshot, feed: configuration.feed, store: snapshot.feeds.isEmpty ? nil : store)
    }

    /// Fetches the feeds itself when the app's copy is old, so posts stay fresh without opening the app.
    func timeline(for configuration: FeedsWidgetIntent, in context: Context) async -> Timeline<FeedsEntry> {
        let now = Date()
        guard let store = WidgetStore.shared else {
            return Timeline(entries: [FeedsEntry(date: now, snapshot: .empty, feed: configuration.feed, store: nil)], policy: .never)
        }
        var snapshot = store.loadFeeds()
        if !snapshot.feeds.isEmpty, snapshot.updatedAt.map({ now.timeIntervalSince($0) > Self.staleAfter }) ?? true {
            snapshot = await snapshot.refreshed(at: now)
        }
        let shown = Array(snapshot.posts(from: configuration.feed?.id).prefix(Self.shownPosts))
        try? await store.saveFeeds(snapshot, photographed: shown) { try? await URLSession.shared.data(from: $0).0 }
        let entry = FeedsEntry(date: now, snapshot: snapshot, feed: configuration.feed, store: store)
        return Timeline(entries: [entry], policy: .after(now.addingTimeInterval(Self.refreshEvery)))
    }
}

extension FeedWidgetSnapshot {
    static let sample: FeedWidgetSnapshot = {
        let now = Date()
        func post(_ title: String, _ source: String, hours: Double) -> Post {
            let slug = title.lowercased().replacingOccurrences(of: " ", with: "-")
            return Post(title: title, link: URL(string: "https://example.com/\(slug)")!, feedURL: source, source: source, published: now.addingTimeInterval(-hours * 3600))
        }
        return FeedWidgetSnapshot(posts: [
            post("Crispy chili oil noodles", "Smitten Kitchen", hours: 2),
            post("The only focaccia you need", "r/Breadit", hours: 5),
            post("Weeknight miso salmon", "Serious Eats", hours: 9),
            post("Brown butter blondies", "Sally's Baking", hours: 20),
            post("A week of make-ahead lunches", "Budget Bytes", hours: 30),
        ])
    }()
}

// MARK: - Widget

struct FeedsWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: "FeedsWidget", intent: FeedsWidgetIntent.self, provider: FeedsProvider()) { entry in
            FeedsWidgetView(entry: entry)
        }
        .configurationDisplayName("Feeds")
        .description("The newest posts from the feeds you follow.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge, .accessoryRectangular])
    }
}

private struct FeedsWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: FeedsEntry

    private var accent: Color {
        guard let hex = entry.snapshot.accentHex, hex.count == 6, let value = UInt32(hex, radix: 16) else {
            return Color(red: 0.86, green: 0.28, blue: 0.22)
        }
        return Color(red: Double(value >> 16 & 0xFF) / 255, green: Double(value >> 8 & 0xFF) / 255, blue: Double(value & 0xFF) / 255)
    }

    private static let feedsURL = URL(string: "recipes://feeds")!

    var body: some View {
        switch family {
        case .systemSmall:
            small.widgetURL(entry.posts.first.map { RecipeLink.feedPostURL(for: $0.entry) } ?? Self.feedsURL)
        case .accessoryRectangular:
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.title).font(.caption.weight(.semibold)).lineLimit(1)
                if entry.posts.isEmpty {
                    Text(emptyMessage).font(.caption).foregroundStyle(.secondary)
                } else {
                    ForEach(entry.posts.prefix(2)) { Text($0.title).font(.caption).lineLimit(1) }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .containerBackground(.background, for: .widget)
            .widgetURL(Self.feedsURL)
        default:
            list(limit: family == .systemLarge ? 5 : 2, photo: family == .systemLarge ? 58 : 50)
                .containerBackground(.background, for: .widget)
                .widgetURL(Self.feedsURL)
        }
    }

    private var emptyMessage: String {
        entry.snapshot.feeds.isEmpty && entry.store != nil ? "Follow a feed to see its posts here" : "No posts yet"
    }

    @ViewBuilder
    private var small: some View {
        if let post = entry.posts.first {
            VStack(alignment: .leading, spacing: 3) {
                Spacer(minLength: 0)
                Text(post.source).font(.caption2.weight(.semibold)).textCase(.uppercase).lineLimit(1)
                    .foregroundStyle(.white.opacity(0.85))
                Text(post.title).font(.subheadline.weight(.semibold)).lineLimit(3).foregroundStyle(.white)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .containerBackground(for: .widget) {
                ZStack {
                    PostPhoto(post: post, store: entry.store, accent: accent, symbolSize: 22, symbolAlignment: .topLeading)
                    LinearGradient(colors: [.clear, .black.opacity(0.7)], startPoint: .center, endPoint: .bottom)
                }
            }
        } else {
            empty.containerBackground(.background, for: .widget)
        }
    }

    private var empty: some View {
        VStack(spacing: 6) {
            Image(systemName: "dot.radiowaves.up.forward").font(.title2).foregroundStyle(accent)
            Text(emptyMessage).font(.caption).foregroundStyle(.secondary).multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func list(limit: Int, photo: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 5) {
                Image(systemName: "dot.radiowaves.up.forward")
                Text(entry.title).lineLimit(1)
                Spacer(minLength: 0)
            }
            .font(.caption.weight(.semibold))
            .foregroundStyle(accent)
            if entry.posts.isEmpty {
                empty
            } else {
                ForEach(entry.posts.prefix(limit)) { post in
                    Link(destination: RecipeLink.feedPostURL(for: post.entry)) { row(post, photo: photo) }
                }
                Spacer(minLength: 0)
            }
        }
    }

    private func row(_ post: FeedWidgetSnapshot.Post, photo: CGFloat) -> some View {
        HStack(spacing: 10) {
            PostPhoto(post: post, store: entry.store, accent: accent, symbolSize: 16)
                .frame(width: photo, height: photo)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text(post.title).font(.subheadline.weight(.medium)).lineLimit(2)
                Text(detail(for: post)).font(.caption).foregroundStyle(.secondary).lineLimit(1)
            }
            Spacer(minLength: 0)
        }
    }

    private func detail(for post: FeedWidgetSnapshot.Post) -> String {
        let shown = entry.feed == nil ? [post.source] : []
        let age = post.published.map { [$0.formatted(.relative(presentation: .named, unitsStyle: .abbreviated))] } ?? []
        return (shown + age).joined(separator: " · ")
    }
}

private struct PostPhoto: View {
    let post: FeedWidgetSnapshot.Post
    let store: WidgetStore?
    let accent: Color
    let symbolSize: CGFloat
    var symbolAlignment: Alignment = .center

    var body: some View {
        if let image = post.imageURL, let store, let photo = UIImage(contentsOfFile: store.feedImageURL(for: image).path) {
            Image(uiImage: photo).resizable().scaledToFill()
        } else {
            ZStack(alignment: symbolAlignment) {
                Rectangle().fill(accent.gradient.opacity(0.85))
                Image(systemName: "fork.knife").font(.system(size: symbolSize, weight: .semibold)).foregroundStyle(.white.opacity(0.9))
                    .padding(symbolAlignment == .center ? 0 : 16)
            }
        }
    }
}

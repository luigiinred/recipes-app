import Foundation

public struct YouTubeVideo: Sendable {
    public var id: String
    public var title: String
    public var channel: String
    public var description: String
    public var captions: [CaptionSegment]
    public var thumbnailURL: String?

    public var transcript: String? {
        captions.isEmpty ? nil : captions.map(\.text).joined(separator: " ")
    }

    public init(id: String, title: String, channel: String, description: String, captions: [CaptionSegment] = [], thumbnailURL: String? = nil) {
        self.id = id
        self.title = title
        self.channel = channel
        self.description = description
        self.captions = captions
        self.thumbnailURL = thumbnailURL
    }

    public var watchURL: String { "https://www.youtube.com/watch?v=\(id)" }
}

public enum YouTubeImporter {
    public static func videoID(from url: URL) -> String? {
        guard let host = url.host?.lowercased() else { return nil }
        let parts = url.pathComponents.filter { $0 != "/" }
        func valid(_ id: String?) -> String? {
            guard let id, id.range(of: #"^[A-Za-z0-9_-]{11}$"#, options: .regularExpression) != nil else { return nil }
            return id
        }
        if host == "youtu.be" { return valid(parts.first) }
        guard host == "youtube.com" || host.hasSuffix(".youtube.com") || host.hasSuffix(".youtube-nocookie.com") else { return nil }
        if parts.first == "watch" {
            return valid(URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems?.first { $0.name == "v" }?.value)
        }
        if ["shorts", "embed", "live", "v"].contains(parts.first ?? ""), parts.count > 1 { return valid(parts[1]) }
        return nil
    }

    public static func importResult(from url: URL, progress: ImportProgress? = nil) async throws -> ImportResult {
        guard let id = videoID(from: url) else { throw RecipeError.invalid("That isn't a YouTube video link.") }
        progress?(.plan(["Finding the video and captions", "Reading the recipe", "Writing it up with the on-device model", "Downloading the photo"]))
        TranscriptRecipeExtractor.prewarm()
        progress?(.began(0))
        let video = try await fetchVideo(id: id)
        progress?(.finished(0))
        progress?(.began(3))
        async let thumbnail = RecipeImageProcessing.download(video.thumbnailURL)

        progress?(.began(1))
        var (recipe, complete) = build(from: video, extracted: nil)
        progress?(.finished(1))
        var aiNote: String?
        if !complete, let transcript = video.transcript, AppleIntelligence.status.isAvailable {
            progress?(.began(2))
            switch await TranscriptRecipeExtractor.run(title: video.title, transcript: transcript) {
            case .extracted(let extracted): (recipe, complete) = build(from: video, extracted: extracted)
            case .unavailable(let status): aiNote = status.explanation
            case .failed(let reason): aiNote = "Apple Intelligence couldn't write the recipe: \(reason)"
            }
            progress?(.finished(2))
        } else {
            if !complete, video.transcript != nil { aiNote = AppleIntelligence.status.explanation }
            progress?(.skipped(2))
        }
        let image = await thumbnail
        progress?(.finished(3))
        var message: String?
        if !complete {
            message = video.transcript == nil
                ? "This video's description doesn't include a recipe, and it has no captions to read. Add the ingredients and steps below."
                : "This video's description doesn't include a full recipe. Check the ingredients and steps below against the video."
            if let aiNote { message = (message ?? "") + " " + aiNote }
        }
        return ImportResult(
            recipe: recipe, imageData: image, isComplete: complete,
            sourceText: complete ? nil : (video.transcript ?? cleanDescription(video.description)),
            sourceTitle: video.transcript == nil ? "Video description" : "Video captions", message: message
        )
    }

    public static func build(from video: YouTubeVideo, extracted: TranscriptRecipeExtractor.Extracted?) -> (Recipe, Bool) {
        let cleaned = cleanDescription(video.description)
        let parsed = RecipeTextParser.parse("Title\n" + cleaned, requiresHeadings: true)
        var recipe = parsed
        recipe.title = RecipeStandards.importedTitle(video.title)
        recipe.sourceURL = video.watchURL
        recipe.imageURL = video.thumbnailURL

        if let extracted {
            if recipe.ingredients.count < 2 { recipe.ingredients = extracted.ingredients }
            if recipe.steps.isEmpty { recipe.steps = extracted.steps }
            if recipe.servings == nil { recipe.servings = extracted.servings }
            if recipe.summary.isEmpty { recipe.summary = extracted.summary }
        }
        recipe.tags = ["YouTube"] + RecipeTags.suggest(for: recipe)
        if recipe.summary.count > 300 { recipe.summary = String(recipe.summary.prefix(297)) + "…" }
        if recipe.summary.isEmpty, !video.channel.isEmpty { recipe.summary = "From \(video.channel) on YouTube." }

        recipe.stepTimestamps = StepTimestamper.align(steps: recipe.steps, captions: video.captions)
        let complete = recipe.ingredients.count >= 2 && !recipe.steps.isEmpty
        if !complete { recipe.notes = String(cleaned.prefix(2000)) }
        return (recipe, complete)
    }

    /// Step start times for a recipe imported from a video; nil when there is no video or no captions.
    public static func timestamps(for recipe: Recipe) async -> [Int?]? {
        guard let id = recipe.youTubeVideoID else { return nil }
        let captions = await fetchCaptions(id: id)
        guard !captions.isEmpty else { return nil }
        return StepTimestamper.align(steps: recipe.steps, captions: captions)
    }

    /// Drops links, chapter timestamps, hashtags and sign-offs so the recipe text is what's left.
    public static func cleanDescription(_ text: String) -> String {
        let noise = ["subscribe", "follow me", "follow us", "instagram", "tiktok", "facebook", "twitter", "business inquir",
                     "music by", "music:", "sponsored", "affiliate", "patreon", "merch", "newsletter", "cookbook"]
        let lines = text.split(whereSeparator: \.isNewline).map { $0.trimmingCharacters(in: .whitespaces) }
        return lines.filter { line in
            if line.isEmpty { return false }
            if line.range(of: #"^\(?\d{1,2}:\d{2}"#, options: .regularExpression) != nil { return false }
            if line.range(of: #"^(https?://|www\.)\S+$"#, options: .regularExpression) != nil { return false }
            if line.range(of: #"^(#\w+\s*)+$"#, options: .regularExpression) != nil { return false }
            let lowered = line.lowercased()
            return !noise.contains { lowered.contains($0) }
        }.joined(separator: "\n")
    }

    private struct Client {
        let body: [String: Any]
        let userAgent: String

        static let android = Client(
            body: ["clientName": "ANDROID", "clientVersion": "20.10.38", "androidSdkVersion": 34, "hl": "en", "gl": "US"],
            userAgent: "com.google.android.youtube/20.10.38 (Linux; U; Android 14) gzip"
        )
        static let ios = Client(
            body: ["clientName": "IOS", "clientVersion": "20.10.4", "deviceModel": "iPhone16,2", "hl": "en", "gl": "US"],
            userAgent: "com.google.ios.youtube/20.10.4 (iPhone16,2; U; CPU iOS 18_3_2 like Mac OS X;)"
        )
    }

    private static func player(id: String, client: Client) async throws -> [String: Any]? {
        var request = URLRequest(url: URL(string: "https://www.youtube.com/youtubei/v1/player?prettyPrint=false")!, timeoutInterval: 20)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(client.userAgent, forHTTPHeaderField: "User-Agent")
        request.httpBody = try JSONSerialization.data(withJSONObject: [
            "context": ["client": client.body], "videoId": id, "contentCheckOk": true, "racyCheckOk": true,
        ] as [String: Any])
        let (data, _) = try await URLSession.shared.data(for: request)
        return try? JSONSerialization.jsonObject(with: data) as? [String: Any]
    }

    private static func captionTracks(_ json: [String: Any]?) -> [[String: Any]] {
        ((json?["captions"] as? [String: Any])?["playerCaptionsTracklistRenderer"] as? [String: Any])?["captionTracks"] as? [[String: Any]] ?? []
    }

    /// Timed captions of a video, preferring a human-written English track over auto-generated ones.
    public static func fetchCaptions(id: String) async -> [CaptionSegment] {
        await fetchCaptions(id: id, clients: [.android, .ios])
    }

    private static func fetchCaptions(id: String, clients: [Client]) async -> [CaptionSegment] {
        for client in clients {
            guard let json = try? await player(id: id, client: client) else { continue }
            let segments = await captions(from: captionTracks(json), userAgent: client.userAgent)
            if !segments.isEmpty { return segments }
        }
        return []
    }

    public static func fetchTranscript(id: String) async -> String? {
        let segments = await fetchCaptions(id: id)
        return segments.isEmpty ? nil : segments.map(\.text).joined(separator: " ")
    }

    public static func fetchVideo(id: String) async throws -> YouTubeVideo {
        guard let json = try await player(id: id, client: .android),
              let details = json["videoDetails"] as? [String: Any],
              let title = details["title"] as? String else {
            throw RecipeError.invalid("Couldn't read that YouTube video. It may be private or unavailable.")
        }
        let thumbnails = (details["thumbnail"] as? [String: Any])?["thumbnails"] as? [[String: Any]]
        let thumbnail = (thumbnails?.last?["url"] as? String) ?? "https://i.ytimg.com/vi/\(id)/hqdefault.jpg"

        var segments = await captions(from: captionTracks(json), userAgent: Client.android.userAgent)
        if segments.isEmpty { segments = await fetchCaptions(id: id, clients: [.ios]) }

        return YouTubeVideo(
            id: id, title: title, channel: details["author"] as? String ?? "",
            description: details["shortDescription"] as? String ?? "", captions: segments, thumbnailURL: thumbnail
        )
    }

    private static func captions(from tracks: [[String: Any]], userAgent: String) async -> [CaptionSegment] {
        func isEnglish(_ track: [String: Any]) -> Bool { (track["languageCode"] as? String)?.hasPrefix("en") == true }
        func isAutomatic(_ track: [String: Any]) -> Int { track["kind"] == nil ? 0 : 1 }
        let ranked = tracks.filter(isEnglish).sorted { isAutomatic($0) < isAutomatic($1) } + tracks.filter { !isEnglish($0) }
        for track in ranked.prefix(2) {
            guard let base = track["baseUrl"] as? String, let url = URL(string: base) else { continue }
            var request = URLRequest(url: url, timeoutInterval: 20)
            request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
            guard let (data, _) = try? await URLSession.shared.data(for: request) else { continue }
            let segments = parseCaptionSegments(String(decoding: data, as: UTF8.self))
            if !segments.isEmpty { return segments }
        }
        return []
    }

    static func parseCaptionSegments(_ xml: String) -> [CaptionSegment] {
        guard let regex = try? NSRegularExpression(pattern: #"<(text|p)\b([^>]*)>(.*?)</\1>"#, options: [.dotMatchesLineSeparators]) else { return [] }
        func attribute(_ name: String, in attributes: String) -> Double? {
            guard let range = attributes.range(of: "\(name)=\"([0-9.]+)\"", options: .regularExpression),
                  let value = attributes[range].split(separator: "\"").dropFirst().first else { return nil }
            return Double(value)
        }
        return regex.matches(in: xml, range: NSRange(xml.startIndex..., in: xml)).compactMap { match in
            guard let attributesRange = Range(match.range(at: 2), in: xml), let innerRange = Range(match.range(at: 3), in: xml) else { return nil }
            let attributes = String(xml[attributesRange])
            let isMilliseconds = xml[Range(match.range(at: 1), in: xml)!] == "p"
            guard let start = attribute(isMilliseconds ? "t" : "start", in: attributes) else { return nil }
            let duration = attribute(isMilliseconds ? "d" : "dur", in: attributes) ?? 0
            let text = RecipeImporter.clean(RecipeImporter.clean(String(xml[innerRange]))).replacingOccurrences(of: "\n", with: " ")
            guard !text.isEmpty else { return nil }
            let scale = isMilliseconds ? 1000.0 : 1.0
            return CaptionSegment(start: start / scale, duration: duration / scale, text: text)
        }
    }

    static func parseCaptions(_ xml: String) -> String {
        guard let regex = try? NSRegularExpression(pattern: #"<(text|p)\b[^>]*>(.*?)</\1>"#, options: [.dotMatchesLineSeparators]) else { return "" }
        let range = NSRange(xml.startIndex..., in: xml)
        let pieces = regex.matches(in: xml, range: range).compactMap { match -> String? in
            guard let inner = Range(match.range(at: 2), in: xml) else { return nil }
            let piece = RecipeImporter.clean(RecipeImporter.clean(String(xml[inner]))).replacingOccurrences(of: "\n", with: " ")
            return piece.isEmpty ? nil : piece
        }
        return pieces.joined(separator: " ")
    }
}

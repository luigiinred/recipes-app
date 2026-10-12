import Foundation

public struct CaptionSegment: Hashable, Sendable {
    public var start: Double
    public var duration: Double
    public var text: String

    public init(start: Double, duration: Double, text: String) {
        self.start = start
        self.duration = duration
        self.text = text
    }
}

/// Finds where in a video each recipe step is spoken, by matching step words against the captions.
public enum StepTimestamper {
    private static let stopwords: Set<String> = [
        "the", "and", "for", "with", "that", "this", "then", "until", "into", "from", "your", "you", "are", "have", "will",
        "can", "just", "about", "some", "more", "all", "any", "its", "out", "off", "over", "also", "very", "when", "what",
        "them", "they", "their", "there", "here", "like", "now", "get", "got", "going", "gonna", "want", "need", "make",
        "add", "put", "take", "let", "well", "okay", "one", "two", "bit", "little", "really",
    ]

    public static func align(steps: [String], captions: [CaptionSegment], windowSeconds: Double = 14, minimumScore: Double = 0.12) -> [Int?] {
        let windows = makeWindows(captions, seconds: windowSeconds)
        guard !windows.isEmpty else { return steps.map { _ in nil } }

        let windowTokens = windows.map { tokens($0.text) }
        var documentFrequency: [String: Int] = [:]
        for set in windowTokens { for token in set { documentFrequency[token, default: 0] += 1 } }
        func weight(_ token: String) -> Double { log(1 + Double(windows.count) / Double(documentFrequency[token] ?? 1)) }

        var result: [Int?] = []
        var floor = 0
        for step in steps {
            let stepTokens = tokens(step)
            let stepNorm = stepTokens.reduce(0.0) { $0 + weight($1) }
            guard !stepTokens.isEmpty, stepNorm > 0 else { result.append(nil); continue }
            var best: (index: Int, score: Double)?
            for index in floor..<windows.count {
                let shared = stepTokens.intersection(windowTokens[index]).reduce(0.0) { $0 + weight($1) }
                guard shared > 0 else { continue }
                let windowNorm = windowTokens[index].reduce(0.0) { $0 + weight($1) }
                let score = shared / (stepNorm * windowNorm).squareRoot()
                if best == nil || score > best!.score { best = (index, score) }
            }
            if let best, best.score >= minimumScore {
                result.append(max(0, Int(windows[best.index].start) - 2))
                floor = best.index
            } else {
                result.append(nil)
            }
        }
        return result
    }

    private static func makeWindows(_ captions: [CaptionSegment], seconds: Double) -> [CaptionSegment] {
        var windows: [CaptionSegment] = []
        var current: CaptionSegment?
        for caption in captions.sorted(by: { $0.start < $1.start }) {
            if var open = current {
                if caption.start - open.start >= seconds {
                    windows.append(open)
                    current = caption
                } else {
                    open.text += " " + caption.text
                    open.duration = caption.start + caption.duration - open.start
                    current = open
                }
            } else {
                current = caption
            }
        }
        if let current { windows.append(current) }
        return windows
    }

    private static func tokens(_ text: String) -> Set<String> {
        let words = text.lowercased().split { !$0.isLetter }.map(String.init)
        return Set(words.compactMap { word -> String? in
            guard word.count > 2, !stopwords.contains(word) else { return nil }
            return stem(word)
        })
    }

    private static func stem(_ word: String) -> String {
        for suffix in ["ing", "ed", "es", "s"] where word.hasSuffix(suffix) && word.count - suffix.count >= 3 {
            return String(word.dropLast(suffix.count))
        }
        return word
    }
}

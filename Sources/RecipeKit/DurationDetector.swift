import Foundation

public struct DetectedDuration: Hashable, Sendable {
    public let text: String
    public let seconds: Int

    public init(text: String, seconds: Int) {
        self.text = text
        self.seconds = seconds
    }
}

public enum DurationDetector {
    private static let primary = try! NSRegularExpression(
        pattern: #"(\d+(?:[.,]\d+)?)(?:\s*(?:-|–|to)\s*(\d+(?:[.,]\d+)?))?\s*(hours?|hrs?|minutes?|mins?|seconds?|secs?)\b"#,
        options: .caseInsensitive
    )
    private static let follow = try! NSRegularExpression(
        pattern: #"^\s*(?:and\s+)?(\d+)\s*(minutes?|mins?|seconds?|secs?)\b"#,
        options: .caseInsensitive
    )

    public static func find(in text: String) -> [DetectedDuration] {
        let ns = text as NSString
        var results: [DetectedDuration] = []
        var cursor = 0
        for match in primary.matches(in: text, range: NSRange(location: 0, length: ns.length)) {
            guard match.range.location >= cursor else { continue }
            let low = number(ns.substring(with: match.range(at: 1)))
            let high = match.range(at: 2).location != NSNotFound ? number(ns.substring(with: match.range(at: 2))) : low
            var seconds = high * multiplier(ns.substring(with: match.range(at: 3)))
            var end = match.range.location + match.range.length
            let rest = ns.substring(from: end)
            if let extra = follow.firstMatch(in: rest, range: NSRange(location: 0, length: (rest as NSString).length)) {
                seconds += number((rest as NSString).substring(with: extra.range(at: 1)))
                    * multiplier((rest as NSString).substring(with: extra.range(at: 2)))
                end += extra.range.length
            }
            cursor = end
            guard seconds > 0 else { continue }
            let label = ns.substring(with: NSRange(location: match.range.location, length: end - match.range.location))
            results.append(DetectedDuration(text: label, seconds: Int(seconds.rounded())))
        }
        return results
    }

    private static func number(_ text: String) -> Double {
        Double(text.replacingOccurrences(of: ",", with: ".")) ?? 0
    }

    private static func multiplier(_ unit: String) -> Double {
        switch unit.lowercased().first {
        case "h": 3600
        case "m": 60
        default: 1
        }
    }
}

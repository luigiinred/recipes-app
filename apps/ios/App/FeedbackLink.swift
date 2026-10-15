import Foundation

enum FeedbackKind {
    case bug, feature

    var label: String {
        switch self {
        case .bug: "bug"
        case .feature: "enhancement"
        }
    }

    var title: String {
        switch self {
        case .bug: "Bug: "
        case .feature: "Idea: "
        }
    }

    var prompts: [String] {
        switch self {
        case .bug: ["What happened?", "What did you expect?", "Steps to reproduce"]
        case .feature: ["What would you like to change or add?", "Why would it help?"]
        }
    }
}

enum FeedbackLink {
    static let issues = URL(string: "https://github.com/luigiinred/recipes-app/issues/new")!

    static func url(for kind: FeedbackKind, environment: String = environment) -> URL {
        let body = kind.prompts.map { "**\($0)**\n\n" }.joined() + "---\n\(environment)"
        var components = URLComponents(url: issues, resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "labels", value: kind.label),
            URLQueryItem(name: "title", value: kind.title),
            URLQueryItem(name: "body", value: body),
        ]
        return components.url!
    }

    static var environment: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "?"
        let build = info?["CFBundleVersion"] as? String ?? "?"
        #if os(iOS)
        let platform = "iOS"
        #else
        let platform = "macOS"
        #endif
        return "Recipes \(version) (\(build)) · \(platform) \(ProcessInfo.processInfo.operatingSystemVersionString)"
    }
}

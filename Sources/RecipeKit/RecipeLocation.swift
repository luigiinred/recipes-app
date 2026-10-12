import Foundation

public enum RecipeLocation {
    public static let containerIdentifier = "iCloud.com.garrabrant.recipes"

    public static var macICloudContainer: URL {
        URL(fileURLWithPath: NSHomeDirectory())
            .appendingPathComponent("Library/Mobile Documents")
            .appendingPathComponent(containerIdentifier.replacingOccurrences(of: ".", with: "~"))
    }

    public static var macICloudRoot: URL {
        macICloudContainer.appendingPathComponent("Documents")
    }

    public static var localRoot: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent("Recipes")
    }

    public struct Resolved: Sendable {
        public let root: URL
        public let isICloud: Bool
        public var library: Library { Library(root: root) }
    }

    /// Blocking: call off the main thread.
    public static func resolveForApp() -> Resolved {
        if let path = ProcessInfo.processInfo.environment["RECIPES_DIR"], !path.isEmpty {
            return Resolved(root: URL(fileURLWithPath: (path as NSString).expandingTildeInPath, isDirectory: true), isICloud: false)
        }
        if let container = FileManager.default.url(forUbiquityContainerIdentifier: containerIdentifier) {
            return Resolved(root: container.appendingPathComponent("Documents"), isICloud: true)
        }
        return Resolved(root: localRoot, isICloud: false)
    }

    public static func resolveForCLI(override: String?, environment: [String: String]) -> Resolved {
        if let path = override ?? environment["RECIPES_DIR"], !path.isEmpty {
            let url = URL(fileURLWithPath: (path as NSString).expandingTildeInPath, isDirectory: true)
            return Resolved(root: url, isICloud: false)
        }
        if FileManager.default.fileExists(atPath: macICloudContainer.path) {
            return Resolved(root: macICloudRoot, isICloud: true)
        }
        return Resolved(root: localRoot, isICloud: false)
    }
}

import Foundation

public enum RecipeLocation {
    public static let containerIdentifier = "iCloud.com.garrabrant.recipes"
    public static let folderName = "Recipes"

    public static var macICloudContainer: URL {
        URL(fileURLWithPath: NSHomeDirectory())
            .appendingPathComponent("Library/Mobile Documents")
            .appendingPathComponent(containerIdentifier.replacingOccurrences(of: ".", with: "~"))
    }

    public static var macICloudDirectory: URL {
        macICloudContainer
            .appendingPathComponent("Documents")
            .appendingPathComponent(folderName)
    }

    public static var localDirectory: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent("Recipes").appendingPathComponent(folderName)
    }

    public struct Resolved: Sendable {
        public let directory: URL
        public let isICloud: Bool
    }

    /// Blocking: call off the main thread.
    public static func resolveForApp() -> Resolved {
        if let container = FileManager.default.url(forUbiquityContainerIdentifier: containerIdentifier) {
            let directory = container.appendingPathComponent("Documents").appendingPathComponent(folderName)
            return Resolved(directory: directory, isICloud: true)
        }
        return Resolved(directory: localDirectory, isICloud: false)
    }

    public static func resolveForCLI(override: String?, environment: [String: String]) -> Resolved {
        if let path = override ?? environment["RECIPES_DIR"], !path.isEmpty {
            let url = URL(fileURLWithPath: (path as NSString).expandingTildeInPath, isDirectory: true)
            return Resolved(directory: url, isICloud: false)
        }
        if FileManager.default.fileExists(atPath: macICloudContainer.path) {
            return Resolved(directory: macICloudDirectory, isICloud: true)
        }
        return Resolved(directory: localDirectory, isICloud: false)
    }
}

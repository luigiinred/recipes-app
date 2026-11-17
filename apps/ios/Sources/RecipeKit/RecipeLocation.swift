import Foundation

public enum RecipeLocation {
    /// `RECIPES_ICLOUD_CONTAINER`, else the `RecipesICloudContainer` Info.plist key the app target sets from `.env`.
    public static var containerIdentifier: String? {
        if let id = ProcessInfo.processInfo.environment["RECIPES_ICLOUD_CONTAINER"], !id.isEmpty { return id }
        let id = Bundle.main.object(forInfoDictionaryKey: "RecipesICloudContainer") as? String
        return id?.hasPrefix("$(") == false && id?.isEmpty == false ? id : nil
    }

    /// Without a configured identifier, the one `iCloud~…~recipes` folder that holds a library.
    public static var macICloudContainer: URL? {
        let base = URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Library/Mobile Documents")
        if let id = containerIdentifier {
            return base.appendingPathComponent(id.replacingOccurrences(of: ".", with: "~"))
        }
        let names = (try? FileManager.default.contentsOfDirectory(atPath: base.path)) ?? []
        let libraries = names
            .filter { $0.hasPrefix("iCloud~") && $0.hasSuffix("~recipes") }
            .map { base.appendingPathComponent($0) }
            .filter { FileManager.default.fileExists(atPath: $0.appendingPathComponent("Documents/Recipes").path) }
        return libraries.count == 1 ? libraries[0] : nil
    }

    public static var macICloudRoot: URL? {
        macICloudContainer?.appendingPathComponent("Documents")
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

    private static let rememberedRootKey = "lastLibraryRoot"
    private static let rememberedICloudKey = "lastLibraryIsICloud"

    /// Where the app's library was last time, when it's still there, so it opens before iCloud answers where it is now.
    public static func rememberedForApp(defaults: UserDefaults = .standard) -> Resolved? {
        guard ProcessInfo.processInfo.environment["RECIPES_DIR"]?.isEmpty ?? true,
              let path = defaults.string(forKey: rememberedRootKey), FileManager.default.fileExists(atPath: path) else { return nil }
        return Resolved(root: URL(fileURLWithPath: path, isDirectory: true), isICloud: defaults.bool(forKey: rememberedICloudKey))
    }

    public static func remember(_ resolved: Resolved, defaults: UserDefaults = .standard) {
        guard ProcessInfo.processInfo.environment["RECIPES_DIR"]?.isEmpty ?? true else { return }
        defaults.set(resolved.root.path, forKey: rememberedRootKey)
        defaults.set(resolved.isICloud, forKey: rememberedICloudKey)
    }

    /// Blocking: call off the main thread.
    public static func resolveForApp() -> Resolved {
        if let path = ProcessInfo.processInfo.environment["RECIPES_DIR"], !path.isEmpty {
            return Resolved(root: URL(fileURLWithPath: (path as NSString).expandingTildeInPath, isDirectory: true), isICloud: false)
        }
        if let id = containerIdentifier, let container = FileManager.default.url(forUbiquityContainerIdentifier: id) {
            return Resolved(root: container.appendingPathComponent("Documents"), isICloud: true)
        }
        return Resolved(root: localRoot, isICloud: false)
    }

    public static func resolveForCLI(override: String?, environment: [String: String]) -> Resolved {
        if let path = override ?? environment["RECIPES_DIR"], !path.isEmpty {
            let url = URL(fileURLWithPath: (path as NSString).expandingTildeInPath, isDirectory: true)
            return Resolved(root: url, isICloud: false)
        }
        if let container = macICloudContainer, let root = macICloudRoot, FileManager.default.fileExists(atPath: container.path) {
            return Resolved(root: root, isICloud: true)
        }
        return Resolved(root: localRoot, isICloud: false)
    }
}

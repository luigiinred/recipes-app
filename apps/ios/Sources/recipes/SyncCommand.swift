import ArgumentParser
import Foundation
import RecipeKit

struct SyncCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "sync",
        abstract: "Sync the library folder with a self-hosted Recipes server.",
        discussion: """
        Uploads what changed here, downloads what changed on the server, and carries deletions both ways. \
        When both sides edited a recipe, the later edit wins. Create an access token in the server's web UI \
        (Settings), then set RECIPES_SERVER and RECIPES_TOKEN so the token stays out of your shell history.
        """
    )

    @OptionGroup var library: LibraryOptions
    @Option(name: .long, help: "Server address, such as https://recipes.example.com. Defaults to RECIPES_SERVER.")
    var server: String?
    @Flag(name: .long, help: "Go ahead even if the pass would delete most of the library.")
    var allowMassDeletion = false
    @Flag(name: .long, help: "Output the result as JSON.")
    var json = false

    func run() async throws {
        let environment = ProcessInfo.processInfo.environment
        guard let address = server ?? environment["RECIPES_SERVER"], let url = URL(string: address), url.scheme?.hasPrefix("http") == true else {
            throw ValidationError("Give the server address with --server or RECIPES_SERVER (http:// or https://).")
        }
        guard let token = environment["RECIPES_TOKEN"], !token.isEmpty else {
            throw ValidationError("Set RECIPES_TOKEN to an access token from the server's Settings page.")
        }
        let root = library.resolved.root
        let report = try await ServerSync(root: root, server: url, token: token).sync(allowMassDeletion: allowMassDeletion)
        if json {
            try printJSON(report)
        } else {
            print("Synced \(root.path) with \(url.absoluteString)")
            print("  uploaded \(report.uploaded), downloaded \(report.downloaded), deleted here \(report.deletedLocally), deleted on server \(report.deletedOnServer)")
            if report.conflicts > 0 { print("  \(report.conflicts) edited on both sides (the later edit was kept)") }
            if report.deferred > 0 { print("  \(report.deferred) changed on the server mid-pass; run sync again") }
        }
    }
}

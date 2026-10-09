import RecipeKit
import SwiftUI

@MainActor
final class ShareModel: ObservableObject {
    enum State { case saving, saved(String), failed(String) }
    @Published var state = State.saving

    func run(url: URL?) async {
        guard let url else {
            state = .failed("No web page to import.")
            return
        }
        do {
            let recipe = try await RecipeImporter.recipe(from: url)
            let resolved = await Task.detached { RecipeLocation.resolveForApp() }.value
            let saved = try RecipeStore(directory: resolved.directory).save(recipe)
            state = .saved(saved.title)
        } catch {
            state = .failed(error.localizedDescription)
        }
    }
}

struct ShareView: View {
    @StateObject private var model = ShareModel()
    let loadURL: () async -> URL?
    let finish: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            switch model.state {
            case .saving:
                ProgressView()
                Text("Saving recipe…")
            case .saved(let title):
                Image(systemName: "checkmark.circle.fill").font(.system(size: 44)).foregroundStyle(.green)
                Text("Saved \"\(title)\"").multilineTextAlignment(.center)
                Text("It will sync to your other devices through iCloud.").font(.caption).foregroundStyle(.secondary)
            case .failed(let message):
                Image(systemName: "exclamationmark.triangle.fill").font(.system(size: 44)).foregroundStyle(.orange)
                Text(message).multilineTextAlignment(.center)
            }
            if case .saving = model.state {} else {
                Button("Done", action: finish).keyboardShortcut(.defaultAction)
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .task {
            await model.run(url: await loadURL())
            if case .saved = model.state {
                try? await Task.sleep(for: .seconds(1.2))
                finish()
            }
        }
    }
}

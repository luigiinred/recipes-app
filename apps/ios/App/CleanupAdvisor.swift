import RecipeKit
import SwiftUI

/// Finds recipes that could be tidied, when one is opened or across the library in the background, and offers the change.
@MainActor
@Observable
final class CleanupAdvisor {
    static let shared = CleanupAdvisor()

    private struct Suggestion {
        let fingerprint: String
        let cleanup: RecipeCleanup
    }

    private var suggestions: [UUID: Suggestion] = [:]
    private var checking: Set<UUID> = []
    private var scanTask: Task<Void, Never>?
    private(set) var scanProgress: (done: Int, total: Int)?

    private static let reviewedKey = "cleanupReviewed"
    /// Recipe ID to the fingerprint last found tidy or dismissed, so a recipe is only offered again after it changes.
    private var reviewed: [String: String] = UserDefaults.standard.dictionary(forKey: reviewedKey) as? [String: String] ?? [:]

    static var suggestsOnOpen: Bool {
        UserDefaults.standard.object(forKey: AppSettings.Key.suggestCleanups) as? Bool ?? true
    }

    func suggestion(for recipe: Recipe) -> RecipeCleanup? {
        guard let found = suggestions[recipe.id], found.fingerprint == recipe.cleanupFingerprint else { return nil }
        return found.cleanup
    }

    /// Recipes with a cleanup waiting, in library order.
    func recipesToTidy(in recipes: [Recipe]) -> [Recipe] {
        recipes.filter { suggestion(for: $0) != nil }
    }

    func check(_ recipe: Recipe) async {
        guard !recipe.isIdea else { return }
        let fingerprint = recipe.cleanupFingerprint
        guard reviewed[recipe.id.uuidString] != fingerprint, suggestions[recipe.id]?.fingerprint != fingerprint,
              !checking.contains(recipe.id) else { return }
        checking.insert(recipe.id)
        defer { checking.remove(recipe.id) }
        let cleanup = await RecipeCleanup.suggest(for: recipe)
        if cleanup.isEmpty {
            markReviewed(recipe.id, fingerprint)
        } else {
            withAnimation(.snappy) { suggestions[recipe.id] = Suggestion(fingerprint: fingerprint, cleanup: cleanup) }
        }
    }

    /// Checks again even after a dismissal, for the Clean Up menu item.
    func checkNow(_ recipe: Recipe) async {
        reviewed[recipe.id.uuidString] = nil
        ToastCenter.shared.show("Checking “\(recipe.title)”…", symbol: "sparkles")
        await check(recipe)
        if suggestion(for: recipe) == nil { ToastCenter.shared.show("“\(recipe.title)” already looks tidy", symbol: "sparkles") }
        else { ToastCenter.shared.dismiss() }
    }

    func dismiss(_ recipe: Recipe) {
        markReviewed(recipe.id, recipe.cleanupFingerprint)
        withAnimation(.snappy) { suggestions[recipe.id] = nil }
    }

    func apply(to recipe: Recipe, in library: RecipeLibrary) async {
        guard let cleanup = suggestion(for: recipe) else { return }
        withAnimation(.snappy) { suggestions[recipe.id] = nil }
        markReviewed(recipe.id, cleanup.recipe.cleanupFingerprint)
        await library.save(cleanup.recipe)
        ToastCenter.shared.show("Cleaned up “\(recipe.title)”", symbol: "sparkles") { [weak self] in
            self?.markReviewed(recipe.id, recipe.cleanupFingerprint)
            await library.save(recipe)
        }
    }

    /// Checks each recipe in turn, one at a time so the on-device model never competes with the app.
    func scan(_ recipes: [Recipe]) {
        scanTask?.cancel()
        let candidates = recipes.filter { !$0.isIdea && reviewed[$0.id.uuidString] != $0.cleanupFingerprint }
        guard !candidates.isEmpty else {
            scanProgress = nil
            return
        }
        scanProgress = (0, candidates.count)
        scanTask = Task(priority: .background) { [weak self] in
            for (index, recipe) in candidates.enumerated() {
                guard !Task.isCancelled, let self else { return }
                await self.check(recipe)
                self.scanProgress = (index + 1, candidates.count)
                try? await Task.sleep(for: .milliseconds(250))
            }
            self?.scanProgress = nil
        }
    }

    func stopScanning() {
        scanTask?.cancel()
        scanTask = nil
        scanProgress = nil
    }

    private func markReviewed(_ id: UUID, _ fingerprint: String) {
        reviewed[id.uuidString] = fingerprint
        UserDefaults.standard.set(reviewed, forKey: Self.reviewedKey)
    }
}

/// The offer at the bottom of a recipe page: what a cleanup would change, Clean Up, and a way to say no.
struct CleanupSuggestionCard: View {
    @EnvironmentObject private var library: RecipeLibrary
    @Environment(\.appAccent) private var accent
    let recipe: Recipe
    let cleanup: RecipeCleanup

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: "sparkles").appFont(.title3).foregroundStyle(accent).accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text("Clean up this recipe?").appFont(.subheadline, weight: .semibold)
                Text(cleanup.summary).appFont(.caption).foregroundStyle(.secondary).lineLimit(2)
            }
            Spacer(minLength: 4)
            Button("Clean Up") { Task { await CleanupAdvisor.shared.apply(to: recipe, in: library) } }
                .appFont(.subheadline, weight: .semibold)
                .buttonStyle(.borderedProminent)
                .tint(accent)
            Button { CleanupAdvisor.shared.dismiss(recipe) } label: { Image(systemName: "xmark") }
                .buttonStyle(.borderless)
                .foregroundStyle(.secondary)
                .accessibilityLabel("Not Now")
        }
        .padding(.leading, 16)
        .padding(.trailing, 14)
        .padding(.vertical, 12)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .padding(.horizontal, 16)
        .padding(.bottom, 12)
        .frame(maxWidth: 560)
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }
}

/// Recipes the background check found, each with its cleanup to apply or dismiss.
struct RecipesToTidyView: View {
    @EnvironmentObject private var library: RecipeLibrary
    private let advisor = CleanupAdvisor.shared

    var body: some View {
        let recipes = advisor.recipesToTidy(in: library.recipes)
        List {
            ForEach(recipes) { recipe in
                if let cleanup = advisor.suggestion(for: recipe) {
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(recipe.title).appFont(.body, weight: .medium)
                            Text(cleanup.summary).appFont(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button("Clean Up") { Task { await advisor.apply(to: recipe, in: library) } }
                            .buttonStyle(.bordered)
                    }
                    .swipeActions { Button("Dismiss", role: .destructive) { advisor.dismiss(recipe) } }
                }
            }
        }
        .overlay {
            if recipes.isEmpty {
                ContentUnavailableView("Everything Looks Tidy", systemImage: "sparkles",
                                       description: Text("Recipes that could be cleaned up show here as they're checked."))
            }
        }
        .navigationTitle("Recipes to Tidy")
    }
}

extension View {
    /// Runs the background cleanup check while it's turned on and the app is in front.
    func cleanupScanning() -> some View { modifier(CleanupScanning()) }
}

private struct CleanupScanning: ViewModifier {
    @EnvironmentObject private var library: RecipeLibrary
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage(AppSettings.Key.suggestCleanups) private var suggestsCleanups = true
    @AppStorage(AppSettings.Key.scanForCleanups) private var scansLibrary = false

    func body(content: Content) -> some View {
        content.task(id: suggestsCleanups && scansLibrary && library.isLoaded && scenePhase == .active) {
            if suggestsCleanups, scansLibrary, library.isLoaded, scenePhase == .active {
                CleanupAdvisor.shared.scan(library.recipes)
            } else {
                CleanupAdvisor.shared.stopScanning()
            }
        }
    }
}

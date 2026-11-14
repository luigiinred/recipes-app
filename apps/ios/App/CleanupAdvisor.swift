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
    private var scanToken: UUID?
    private(set) var scanProgress: (done: Int, total: Int)?

    private static let reviewedKey = "cleanupReviewed"
    /// Recipe ID to the fingerprint last found tidy or dismissed, so a recipe is only offered again after it changes.
    private var reviewed: [String: String] = UserDefaults.standard.dictionary(forKey: reviewedKey) as? [String: String] ?? [:]

    static var suggestsOnOpen: Bool {
        UserDefaults.standard.object(forKey: AppSettings.Key.suggestCleanups) as? Bool ?? true
    }

    /// The cleanup waiting for a recipe, with only the kinds of change switched on in AI Improvements.
    func suggestion(for recipe: Recipe) -> RecipeCleanup? {
        guard let found = suggestions[recipe.id], found.fingerprint == recipe.cleanupFingerprint else { return nil }
        let filtered = found.cleanup.keeping { CleanupKind($0).isOn }
        return filtered.isEmpty ? nil : filtered
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

    /// Saves only the changes the user kept; keeping none counts as a dismissal.
    func apply(_ accepted: Set<RecipeCleanup.Change.Kind>, to recipe: Recipe, in library: RecipeLibrary) async {
        guard let cleanup = suggestion(for: recipe) else { return }
        guard !accepted.isEmpty else {
            dismiss(recipe)
            return
        }
        let cleaned = cleanup.applying(accepted)
        withAnimation(.snappy) { suggestions[recipe.id] = nil }
        markReviewed(recipe.id, cleaned.cleanupFingerprint)
        await library.save(cleaned)
        let count = accepted.count
        ToastCenter.shared.show("Made \(count) \(count == 1 ? "change" : "changes") to “\(recipe.title)”", symbol: "sparkles") { [weak self] in
            self?.markReviewed(recipe.id, recipe.cleanupFingerprint)
            await library.save(recipe)
        }
    }

    /// Checks each recipe in turn, one at a time so the on-device model never competes with the app.
    /// Recipes not yet checked in their current form: new ones, and any changed since they were last checked or dismissed.
    func waiting(in recipes: [Recipe]) -> [Recipe] {
        recipes.filter { recipe in
            let fingerprint = recipe.cleanupFingerprint
            return !recipe.isIdea && reviewed[recipe.id.uuidString] != fingerprint && suggestions[recipe.id]?.fingerprint != fingerprint
        }
    }

    /// Works through the queue one recipe at a time, reading it afresh each turn so new and edited recipes join the same pass.
    func scan(_ recipes: @escaping @MainActor () -> [Recipe]) {
        guard scanTask == nil else { return }
        let token = UUID()
        scanToken = token
        scanTask = Task(priority: .background) { [weak self] in
            var tried = Set<String>()
            var done = 0
            while !Task.isCancelled, let self {
                let queue = self.waiting(in: recipes()).filter { !tried.contains($0.id.uuidString + $0.cleanupFingerprint) }
                guard let next = queue.first else { break }
                self.scanProgress = (done, done + queue.count)
                tried.insert(next.id.uuidString + next.cleanupFingerprint)
                await self.check(next)
                done += 1
                try? await Task.sleep(for: .milliseconds(250))
            }
            guard let self, self.scanToken == token else { return }
            self.scanProgress = nil
            self.scanTask = nil
        }
    }

    func stopScanning() {
        scanTask?.cancel()
        scanTask = nil
        scanToken = nil
        scanProgress = nil
    }

    private func markReviewed(_ id: UUID, _ fingerprint: String) {
        reviewed[id.uuidString] = fingerprint
        UserDefaults.standard.set(reviewed, forKey: Self.reviewedKey)
    }
}

/// The offer at the bottom of a recipe page: what a cleanup would change, and Review to see each change before keeping it.
struct CleanupSuggestionCard: View {
    @Environment(\.appAccent) private var accent
    let recipe: Recipe
    let cleanup: RecipeCleanup
    @State private var reviewing = false

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: "sparkles").appFont(.title3).foregroundStyle(accent).accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text("Suggested cleanup").appFont(.subheadline, weight: .semibold)
                Text(cleanup.summary).appFont(.caption).foregroundStyle(.secondary).lineLimit(2)
            }
            Spacer(minLength: 4)
            Button("Review") { reviewing = true }
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
        .sheet(isPresented: $reviewing) { CleanupReviewSheet(recipe: recipe, cleanup: cleanup) }
    }
}

/// Every change a cleanup would make, as before and after, each with a checkbox; only the checked ones are saved.
struct CleanupReviewSheet: View {
    @EnvironmentObject private var library: RecipeLibrary
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appAccent) private var accent
    let recipe: Recipe
    let cleanup: RecipeCleanup
    @State private var accepted: Set<RecipeCleanup.Change.Kind>

    init(recipe: Recipe, cleanup: RecipeCleanup) {
        self.recipe = recipe
        self.cleanup = cleanup
        _accepted = State(initialValue: Set(cleanup.changes.map(\.id)))
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text(cleanup.summary).foregroundStyle(.secondary)
                    Button(accepted.count == cleanup.changes.count ? "Deselect All" : "Select All") {
                        accepted = accepted.count == cleanup.changes.count ? [] : Set(cleanup.changes.map(\.id))
                    }
                }
                ForEach(groups, id: \.title) { group in
                    Section(group.title) {
                        ForEach(group.changes) { change in ChangeRow(change: change, isOn: binding(change.id)) }
                    }
                }
            }
            .navigationTitle("Review Cleanup")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { CancelButton() }
                ToolbarItem(placement: .confirmationAction) {
                    Button(accepted.count == cleanup.changes.count ? "Apply All" : "Apply \(accepted.count)") {
                        Task { await CleanupAdvisor.shared.apply(accepted, to: recipe, in: library) }
                        dismiss()
                    }
                    .disabled(accepted.isEmpty)
                }
            }
        }
        .tint(accent)
    }

    private var groups: [(title: String, changes: [RecipeCleanup.Change])] {
        let ingredients = cleanup.changes.filter { if case .ingredient = $0.kind { true } else { false } }
        let sections = cleanup.changes.filter { $0.kind == .sections }
        let steps = cleanup.changes.filter { if case .step = $0.kind { true } else { false } }
        let notes = cleanup.changes.filter { $0.kind == .notes }
        return [("Ingredients", ingredients), ("Sections", sections), ("Steps", steps), ("Notes", notes)].filter { !$0.1.isEmpty }
    }

    private func binding(_ kind: RecipeCleanup.Change.Kind) -> Binding<Bool> {
        Binding(get: { accepted.contains(kind) }, set: { if $0 { accepted.insert(kind) } else { accepted.remove(kind) } })
    }
}

private struct ChangeRow: View {
    @Environment(\.appAccent) private var accent
    let change: RecipeCleanup.Change
    @Binding var isOn: Bool

    var body: some View {
        Button { isOn.toggle() } label: {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: isOn ? "checkmark.circle.fill" : "circle")
                    .appFont(.title3)
                    .foregroundStyle(isOn ? AnyShapeStyle(accent) : AnyShapeStyle(.tertiary))
                VStack(alignment: .leading, spacing: 8) {
                    Text(change.title).appFont(.caption, weight: .semibold).foregroundStyle(.secondary)
                    if change.before.count == 1, change.after.count == 1 {
                        diffLine(change.before[0], change.after[0])
                    } else {
                        side("Before", change.before, removed: true)
                        side("After", change.after, removed: false)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .contentShape(Rectangle())
            .opacity(isOn ? 1 : 0.55)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }

    /// One line changed in place: removed words struck through, added words in the accent.
    private func diffLine(_ before: String, _ after: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(attributed(before, after, showing: .before))
                .padding(.horizontal, 10).padding(.vertical, 6)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.red.opacity(0.08), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            Text(attributed(before, after, showing: .after))
                .padding(.horizontal, 10).padding(.vertical, 6)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(accent.opacity(0.1), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
    }

    private enum Side { case before, after }

    private func attributed(_ before: String, _ after: String, showing side: Side) -> AttributedString {
        var result = AttributedString()
        for piece in WordDiff.pieces(from: before, to: after) {
            var word: AttributedString
            switch (piece, side) {
            case (.same(let text), _):
                word = AttributedString(text)
            case (.removed(let text), .before):
                word = AttributedString(text)
                word.strikethroughStyle = .single
                word.foregroundColor = .red
            case (.added(let text), .after):
                word = AttributedString(text)
                word.foregroundColor = accent
                word.inlinePresentationIntent = .stronglyEmphasized
            default:
                continue
            }
            if !result.characters.isEmpty { result += AttributedString(" ") }
            result += word
        }
        return result
    }

    private func side(_ label: String, _ lines: [String], removed: Bool) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label.uppercased()).appFont(.caption2, weight: .bold).foregroundStyle(removed ? Color.red.opacity(0.8) : accent)
            if lines.isEmpty {
                Text("Nothing").italic().foregroundStyle(.secondary)
            }
            ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
                if line.hasPrefix("# ") {
                    Text(line.dropFirst(2)).appFont(.footnote, weight: .semibold).foregroundStyle(accent).padding(.top, 4)
                } else {
                    Text(line).foregroundStyle(removed ? .secondary : .primary)
                        .strikethrough(removed && lines.count == 1, color: .red.opacity(0.6))
                }
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background((removed ? Color.red.opacity(0.06) : accent.opacity(0.08)), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

/// Recipes the background check found, each with its cleanup to apply or dismiss.
struct RecipesToTidyView: View {
    @EnvironmentObject private var library: RecipeLibrary
    private let advisor = CleanupAdvisor.shared
    @State private var reviewing: Recipe?

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
                        Button("Review") { reviewing = recipe }
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
        .sheet(item: $reviewing) { recipe in
            if let cleanup = advisor.suggestion(for: recipe) { CleanupReviewSheet(recipe: recipe, cleanup: cleanup) }
        }
    }
}

extension View {
    /// Runs the background cleanup check while it's turned on and the app is in front.
    func cleanupScanning() -> some View { modifier(CleanupScanning()) }
}

private struct ScanKey: Equatable {
    let on: Bool
    let hasWaiting: Bool
}

private struct CleanupScanning: ViewModifier {
    @EnvironmentObject private var library: RecipeLibrary
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage(AppSettings.Key.suggestCleanups) private var suggestsCleanups = true
    @AppStorage(AppSettings.Key.scanForCleanups) private var scansLibrary = true

    func body(content: Content) -> some View {
        content.task(id: ScanKey(on: suggestsCleanups && scansLibrary && library.isLoaded && scenePhase == .active,
                                 hasWaiting: !CleanupAdvisor.shared.waiting(in: library.recipes).isEmpty)) {
            if suggestsCleanups, scansLibrary, library.isLoaded, scenePhase == .active {
                try? await Task.sleep(for: .seconds(2))
                guard !Task.isCancelled else { return }
                CleanupAdvisor.shared.scan { [library] in library.recipes }
            } else {
                CleanupAdvisor.shared.stopScanning()
            }
        }
    }
}

/// A kind of change a cleanup can offer, each with its own switch in AI Improvements.
enum CleanupKind: String, CaseIterable, Identifiable {
    case ingredients, sections, steps, notes

    init(_ kind: RecipeCleanup.Change.Kind) {
        switch kind {
        case .ingredient: self = .ingredients
        case .sections: self = .sections
        case .step: self = .steps
        case .notes: self = .notes
        }
    }

    var id: String { rawValue }
    var key: String { "cleanup.\(rawValue)" }
    var isOn: Bool { UserDefaults.standard.object(forKey: key) as? Bool ?? true }

    var title: String {
        switch self {
        case .ingredients: "Tidy ingredients"
        case .sections: "Ingredient sections"
        case .steps: "Split and tidy steps"
        case .notes: "Move loose text into Notes"
        }
    }

    var detail: String {
        switch self {
        case .ingredients: "Write amounts and units one way, like “1/2 cup” and “2 tbsp”."
        case .sections: "Turn labels like “Dressing:” into sections, and rarely group a salad and its dressing."
        case .steps: "Break run-together and numbered steps apart, and tidy their wording."
        case .notes: "Text before the steps, like tips, goes to Notes."
        }
    }

    var symbol: String {
        switch self {
        case .ingredients: "list.bullet"
        case .sections: "square.stack.3d.up"
        case .steps: "list.number"
        case .notes: "note.text"
        }
    }
}

/// Everything about AI improvements in one place: the switches, the background queue, and the recipes waiting.
struct AIImprovementsPage: View {
    @EnvironmentObject private var library: RecipeLibrary
    @AppStorage(AppSettings.Key.suggestCleanups) private var suggestsCleanups = true
    @AppStorage(AppSettings.Key.scanForCleanups) private var scansLibrary = true
    private let advisor = CleanupAdvisor.shared

    var body: some View {
        let tidy = advisor.recipesToTidy(in: library.recipes)
        let waiting = advisor.waiting(in: library.recipes)
        Form {
            Section {
                Toggle(isOn: $suggestsCleanups) { Label("Suggest Improvements", systemImage: "sparkles") }
                Toggle(isOn: $scansLibrary) { Label("Check in the Background", systemImage: "arrow.triangle.2.circlepath") }
                    .disabled(!suggestsCleanups)
            } footer: {
                Text("Improvements are only ever suggested: each one is shown as a before and after for you to keep or skip. "
                     + "The background check works through every recipe while the app is open, and checks a recipe again whenever you change it.")
            }
            Section("Improvements") {
                ForEach(CleanupKind.allCases) { CleanupKindToggle(kind: $0) }
            }
            .disabled(!suggestsCleanups)
            Section {
                NavigationLink { RecipesToTidyView() } label: {
                    LabeledContent { Text("\(tidy.count)").monospacedDigit() } label: { Label("Recipes to Tidy", systemImage: "wand.and.stars") }
                }
                NavigationLink { WaitingRecipesView() } label: {
                    LabeledContent { Text("\(waiting.count)").monospacedDigit() } label: { Label("Waiting to Be Checked", systemImage: "hourglass") }
                }
                if let progress = advisor.scanProgress {
                    LabeledContent("Checking now") { Text("\(progress.done) of \(progress.total)").monospacedDigit() }
                }
            } header: {
                Text("Your recipes")
            } footer: {
                if !AppleIntelligence.status.isAvailable {
                    Text("Without Apple Intelligence, ingredients, labels and numbered steps are still tidied. Grouping ingredients and splitting long steps need it. " + AppleIntelligence.status.explanation)
                }
            }
        }
        .formStyle(.grouped)
        .settingsPage("AI Improvements")
    }
}

private struct CleanupKindToggle: View {
    let kind: CleanupKind
    @AppStorage private var isOn: Bool

    init(kind: CleanupKind) {
        self.kind = kind
        _isOn = AppStorage(wrappedValue: true, kind.key)
    }

    var body: some View {
        Toggle(isOn: $isOn) {
            Label {
                VStack(alignment: .leading, spacing: 2) {
                    Text(kind.title)
                    Text(kind.detail).appFont(.caption).foregroundStyle(.secondary)
                }
            } icon: {
                Image(systemName: kind.symbol)
            }
        }
    }
}

/// Recipes the background check hasn't reached yet, in the order it will check them.
private struct WaitingRecipesView: View {
    @EnvironmentObject private var library: RecipeLibrary

    var body: some View {
        let waiting = CleanupAdvisor.shared.waiting(in: library.recipes)
        List(waiting) { recipe in
            Text(recipe.title)
        }
        .overlay {
            if waiting.isEmpty {
                ContentUnavailableView("All Checked", systemImage: "checkmark.circle",
                                       description: Text("Every recipe has been checked. New and changed recipes show up here until they are."))
            }
        }
        .navigationTitle("Waiting to Be Checked")
    }
}

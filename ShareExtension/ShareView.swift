import RecipeKit
import SwiftUI

@MainActor
final class ShareModel: ObservableObject {
    enum State { case loading, review, saving, saved(String, note: String?), failed(String) }

    @Published var state = State.loading
    @Published var title = ""
    @Published var selected: Set<String> = []
    @Published var newCategory = ""
    @Published private(set) var existing: [String] = []
    @Published private(set) var photo: CGImage?
    @Published private(set) var note: String?

    private var result: ImportResult?
    private var library: Library?

    func load(url: URL?) async {
        guard let url else {
            state = .failed("No web page to import.")
            return
        }
        do {
            let result = try await RecipeImporter.importResult(from: url)
            let library = await Task.detached { RecipeLocation.resolveForApp().library }.value
            let recipes = await Task.detached { (try? library.recipes.list()) ?? [] }.value
            self.result = result
            self.library = library
            title = result.recipe.title
            existing = Array(Set(recipes.flatMap(\.tags))).sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
            selected = Set(result.recipe.tags)
            photo = result.imageData.flatMap { RecipeImageProcessing.thumbnail(from: $0, maxPixelSize: 240) }
            note = result.isComplete ? nil : "No full recipe was found. You can finish it in Recipes."
            state = .review
        } catch {
            state = .failed(error.localizedDescription)
        }
    }

    func save() async {
        guard var result, let library else { return }
        state = .saving
        let typed = newCategory.split(separator: ",").map { CategoryTree.normalized(String($0)) }.filter { !$0.isEmpty }
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        result.recipe.title = trimmed.isEmpty ? result.recipe.title : trimmed
        result.recipe.tags = selected.sorted() + typed.filter { !selected.contains($0) }
        let outcome = await Task.detached { [result] in Result { try library.add(result) } }.value
        switch outcome {
        case .success(let saved): state = .saved(saved.title, note: note)
        case .failure(let error): state = .failed(error.localizedDescription)
        }
    }

    func toggle(_ category: String) {
        if !selected.insert(category).inserted { selected.remove(category) }
    }
}

struct ShareView: View {
    @StateObject private var model = ShareModel()
    let loadURL: () async -> URL?
    let finish: () -> Void
    let cancel: () -> Void

    var body: some View {
        Group {
            switch model.state {
            case .loading:
                VStack(spacing: 12) { ProgressView(); Text("Reading recipe…") }
            case .review:
                review
            case .saving:
                VStack(spacing: 12) { ProgressView(); Text("Saving…") }
            case .saved(let title, let note):
                VStack(spacing: 12) {
                    Image(systemName: "checkmark.circle.fill").font(.system(size: 44)).foregroundStyle(.green)
                    Text("Saved \"\(title)\"").multilineTextAlignment(.center)
                    Text(note ?? "It will sync to your other devices through iCloud.")
                        .font(.caption).foregroundStyle(note == nil ? Color.secondary : Color.orange).multilineTextAlignment(.center)
                    Button(action: finish) { Label("Done", systemImage: "checkmark") }.labelStyle(.iconOnly).buttonStyle(.borderedProminent).keyboardShortcut(.defaultAction)
                }
            case .failed(let message):
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle.fill").font(.system(size: 44)).foregroundStyle(.orange)
                    Text(message).multilineTextAlignment(.center)
                    Button(action: cancel) { Label("Done", systemImage: "checkmark") }.labelStyle(.iconOnly).buttonStyle(.borderedProminent).keyboardShortcut(.defaultAction)
                }
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .task { await model.load(url: await loadURL()) }
        .onChange(of: model.state.isSaved) { _, saved in
            guard saved, case .saved(_, let note) = model.state, note == nil else { return }
            Task {
                try? await Task.sleep(for: .seconds(1.0))
                finish()
            }
        }
    }

    private var review: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                if let photo = model.photo {
                    Image(decorative: photo, scale: 1).resizable().scaledToFill()
                        .frame(width: 72, height: 72).clipShape(RoundedRectangle(cornerRadius: 10))
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text("Title").font(.caption).foregroundStyle(.secondary)
                    TextField("Title", text: $model.title, axis: .vertical).textFieldStyle(.roundedBorder)
                }
            }
            if let note = model.note {
                Label(note, systemImage: "exclamationmark.triangle.fill").font(.caption).foregroundStyle(.orange)
            }
            Text("Categories").font(.caption).foregroundStyle(.secondary)
            ScrollView {
                ChipFlow {
                    ForEach(model.existing + model.selected.filter { !model.existing.contains($0) }.sorted(), id: \.self) { category in
                        let on = model.selected.contains(category)
                        Button { model.toggle(category) } label: {
                            Text(CategoryTree.displayName(category))
                                .font(.callout)
                                .padding(.horizontal, 12).padding(.vertical, 6)
                                .background(on ? Color.accentColor : Color.secondary.opacity(0.15), in: Capsule())
                                .foregroundStyle(on ? Color.white : Color.primary)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            TextField("New category (use / to nest)", text: $model.newCategory).textFieldStyle(.roundedBorder)
            HStack {
                Button(action: cancel) { Label("Cancel", systemImage: "xmark") }.labelStyle(.iconOnly)
                Spacer()
                Button { Task { await model.save() } } label: { Label("Save", systemImage: "checkmark") }
                    .labelStyle(.iconOnly)
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
                    .disabled(model.title.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
    }
}

extension ShareModel.State {
    var isSaved: Bool {
        if case .saved = self { return true }
        return false
    }
}

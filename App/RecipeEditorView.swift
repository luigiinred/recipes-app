import ImagePlayground
import PhotosUI
import RecipeKit
import SwiftUI

struct RecipeEditorView: View {
    @Environment(\.dismiss) private var dismiss
    let original: Recipe
    let scannedText: String?
    let scannedTextTitle: String
    let notice: String?
    let initialImage: Data?
    let onSave: (Recipe, ImageChange) -> Void

    @EnvironmentObject private var library: RecipeLibrary
    @State private var pickedItem: PhotosPickerItem?
    @State private var imageChange = ImageChange.unchanged

    @State private var isFavorite: Bool
    @State private var wantToCook: Bool
    @State private var title: String
    @State private var summary: String
    @State private var servings: String
    @State private var prep: String
    @State private var cook: String
    @State private var ingredients: [EditableLine]
    @State private var steps: [EditableLine]
    @FocusState private var focused: UUID?
    @State private var generatingImage = false
    @Environment(\.supportsImagePlayground) private var supportsImagePlayground
    @State private var tags: [String]
    @State private var source: String
    @State private var notes: String

    init(
        recipe: Recipe, scannedText: String? = nil, scannedTextTitle: String = "Scanned text", notice: String? = nil,
        initialImage: Data? = nil,
        onSave: @escaping (Recipe, ImageChange) -> Void
    ) {
        original = recipe
        self.scannedText = scannedText
        self.scannedTextTitle = scannedTextTitle
        self.notice = notice
        self.initialImage = initialImage
        self.onSave = onSave
        _imageChange = State(initialValue: initialImage.map(ImageChange.set) ?? .unchanged)
        _isFavorite = State(initialValue: recipe.isFavorite)
        _wantToCook = State(initialValue: recipe.wantToCook)
        _title = State(initialValue: recipe.title)
        _summary = State(initialValue: recipe.summary)
        _servings = State(initialValue: recipe.servings.map(String.init) ?? "")
        _prep = State(initialValue: recipe.prepMinutes.map(String.init) ?? "")
        _cook = State(initialValue: recipe.cookMinutes.map(String.init) ?? "")
        _ingredients = State(initialValue: recipe.ingredients.map { EditableLine(text: $0) })
        _steps = State(initialValue: recipe.steps.enumerated().map { index, text in
            EditableLine(text: text, time: recipe.timestamp(forStep: index).map(Recipe.clock) ?? "")
        })
        _tags = State(initialValue: recipe.tags)
        _source = State(initialValue: recipe.sourceURL ?? "")
        _notes = State(initialValue: recipe.notes)
    }

    var body: some View {
        NavigationStack {
            container {
                if let notice {
                    Section {
                        Label(notice, systemImage: "exclamationmark.triangle.fill").foregroundStyle(.orange)
                    }
                }
                photoSection
                if let scannedText {
                    Section {
                        DisclosureGroup(scannedTextTitle) {
                            Text(scannedText).font(.caption).foregroundStyle(.secondary).textSelection(.enabled)
                        }
                    } footer: {
                        if notice == nil { Text("Check the recipe below against the scan before saving.") }
                    }
                }
                Section {
                    TextField("Title", text: $title)
                    TextField("Summary", text: $summary, axis: .vertical)
                }
                Section {
                    LabeledContent("Servings") { TextField("", text: $servings).multilineTextAlignment(.trailing) }
                    LabeledContent("Prep minutes") { TextField("", text: $prep).multilineTextAlignment(.trailing) }
                    LabeledContent("Cook minutes") { TextField("", text: $cook).multilineTextAlignment(.trailing) }
                }
                Section {
                    Toggle(isOn: $isFavorite) { Label("Favorite", systemImage: "heart") }
                    Toggle(isOn: $wantToCook) { Label("Want to Cook", systemImage: "arrow.right.circle") }
                }
                Section {
                    TagEditor(tags: $tags)
                } header: {
                    Text("Categories")
                } footer: {
                    Text("Use a slash to nest a category, like Dinner/Pasta.")
                }
                Section("Ingredients") {
                    ForEach($ingredients) { $line in
                        row(line: $line, placeholder: "Ingredient", remove: { ingredients.removeAll { $0.id == line.id } })
                    }
                    .onDelete { ingredients.remove(atOffsets: $0) }
                    .onMove { ingredients.move(fromOffsets: $0, toOffset: $1) }
                    .alwaysReorderable()
                    addButton("Add Ingredient") { ingredients.append(newLine()) }
                }
                Section("Steps") {
                    ForEach($steps) { $line in
                        row(line: $line, placeholder: "Step", number: (steps.firstIndex { $0.id == line.id } ?? 0) + 1,
                            showsTime: isVideoRecipe, remove: { steps.removeAll { $0.id == line.id } })
                    }
                    .onDelete { steps.remove(atOffsets: $0) }
                    .onMove { steps.move(fromOffsets: $0, toOffset: $1) }
                    .alwaysReorderable()
                    addButton("Add Step") { steps.append(newLine()) }
                }
                Section {
                    TextField("Source URL", text: $source)
                    TextField("Notes", text: $notes, axis: .vertical)
                }
            }
            .navigationTitle(original.title.isEmpty ? "New Recipe" : "Edit Recipe")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { CancelButton() }
                ToolbarItem(placement: .confirmationAction) {
                    ConfirmButton(title: "Save", isDisabled: title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) { save() }
                }
            }
        }
        #if os(macOS)
        .frame(minWidth: 520, minHeight: 640)
        #endif
    }

    @ViewBuilder
    private func container<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        #if os(iOS)
        Form { content() }
        #else
        List { content() }.listStyle(.inset)
        #endif
    }

    private func newLine() -> EditableLine {
        let line = EditableLine(text: "")
        focused = line.id
        return line
    }

    private func addButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) { Label(title, systemImage: "plus.circle.fill") }
            .buttonStyle(.borderless)
            .foregroundStyle(Theme.accent)
    }

    private var isVideoRecipe: Bool {
        URL(string: source).flatMap(YouTubeImporter.videoID(from:)) != nil
    }

    private func row(
        line: Binding<EditableLine>, placeholder: String, number: Int? = nil, showsTime: Bool = false, remove: @escaping () -> Void
    ) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            if let number {
                Text("\(number)")
                    .font(.footnote.weight(.bold))
                    .foregroundStyle(.white)
                    .frame(width: 22, height: 22)
                    .background(Theme.accent, in: Circle())
            }
            TextField(placeholder, text: line.text, axis: .vertical)
                .focused($focused, equals: line.wrappedValue.id)
            if showsTime {
                TextField("m:ss", text: line.time)
                    .multilineTextAlignment(.trailing)
                    .font(.footnote.monospacedDigit())
                    .foregroundStyle(Theme.accent)
                    .frame(width: 52)
                    .accessibilityLabel("Video timestamp")
            }
            #if os(macOS)
            Button(role: .destructive, action: remove) { Image(systemName: "minus.circle") }
                .buttonStyle(.borderless)
                .foregroundStyle(.secondary)
                .accessibilityLabel("Remove")
            #endif
        }
        .contextMenu { Button("Delete", role: .destructive, action: remove) }
    }

    private var photoSection: some View {
        Section("Photo") {
            HStack(spacing: 14) {
                photoPreview
                    .frame(width: 96, height: 72)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                VStack(alignment: .leading, spacing: 8) {
                    PhotosPicker(selection: $pickedItem, matching: .images) {
                        Label(hasPhoto ? "Change Photo" : "Add Photo", systemImage: "photo")
                    }
                    if supportsImagePlayground {
                        Button { generatingImage = true } label: { Label("Create with Image Playground", systemImage: "apple.image.playground") }
                            .buttonStyle(.borderless)
                    }
                    if hasPhoto {
                        Button("Remove Photo", role: .destructive) { imageChange = .remove }
                            .buttonStyle(.borderless)
                    }
                }
            }
        }
        .recipeImageGenerator(isPresented: $generatingImage, recipe: assembled()) { imageChange = .set($0) }
        .onChange(of: pickedItem) { _, item in
            guard let item else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self),
                   let jpeg = RecipeImageProcessing.jpegData(from: data) {
                    imageChange = .set(jpeg)
                }
                pickedItem = nil
            }
        }
    }

    private var hasPhoto: Bool {
        switch imageChange {
        case .set: true
        case .remove: false
        case .unchanged: library.hasImage(original.id)
        }
    }

    @ViewBuilder
    private var photoPreview: some View {
        if case .set(let data) = imageChange, let image = RecipeImageProcessing.thumbnail(from: data, maxPixelSize: 400) {
            Image(decorative: image, scale: 1).resizable().scaledToFill()
        } else if case .remove = imageChange {
            Color.secondary.opacity(0.12).overlay(Image(systemName: "photo").foregroundStyle(.secondary))
        } else if library.hasImage(original.id) {
            RecipeImageView(recipe: original)
        } else {
            Color.secondary.opacity(0.12).overlay(Image(systemName: "photo").foregroundStyle(.secondary))
        }
    }

    private func cleaned(_ lines: [EditableLine]) -> [String] {
        lines.map { $0.text.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
    }

    private func keptSteps() -> [(text: String, seconds: Int?)] {
        steps.compactMap { line in
            let text = line.text.trimmingCharacters(in: .whitespacesAndNewlines)
            return text.isEmpty ? nil : (text, Recipe.seconds(fromClock: line.time))
        }
    }

    private func assembled() -> Recipe {
        var recipe = original
        recipe.title = title
        recipe.summary = summary
        recipe.servings = Int(servings)
        recipe.prepMinutes = Int(prep)
        recipe.cookMinutes = Int(cook)
        recipe.ingredients = cleaned(ingredients)
        let kept = keptSteps()
        recipe.steps = kept.map(\.text)
        recipe.stepTimestamps = kept.contains { $0.seconds != nil } ? kept.map(\.seconds) : []
        recipe.tags = tags
        let trimmedSource = source.trimmingCharacters(in: .whitespaces)
        recipe.sourceURL = trimmedSource.isEmpty ? nil : trimmedSource
        recipe.notes = notes
        recipe.isFavorite = isFavorite
        recipe.wantToCook = wantToCook
        return recipe
    }

    private func save() {
        onSave(assembled(), imageChange)
        dismiss()
    }
}

struct EditableLine: Identifiable, Hashable {
    let id = UUID()
    var text: String
    var time = ""
}

extension DynamicViewContent {
    /// Shows reorder handles and delete controls on these rows without a separate Edit button.
    @ViewBuilder
    func alwaysReorderable() -> some View {
        #if os(iOS)
        environment(\.editMode, .constant(.active))
        #else
        self
        #endif
    }
}

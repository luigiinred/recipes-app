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
    let onSave: (Recipe, ImageChange, StepImageChanges) -> Void
    /// Set where the editor isn't in a sheet it can dismiss, such as the share extension.
    var onCancel: (() -> Void)?

    @EnvironmentObject private var library: RecipeLibrary
    @State private var pickedItem: PhotosPickerItem?
    @State private var imageChange = ImageChange.unchanged

    @State private var isFavorite: Bool
    @State private var wantToCook: Bool
    @State private var rating: Int?
    @AppStorage(AppSettings.Key.ratingStyle) private var ratingStyleRaw = RatingStyle.favorites.rawValue
    @State private var title: String
    @State private var summary: String
    @State private var servings: String
    @State private var prep: String
    @State private var cook: String
    @State private var ingredients: [EditableIngredient]
    @State private var isGrouping = false
    @State private var groupingMessage: String?
    @State private var steps: [EditableLine]
    @FocusState private var focused: UUID?
    @State private var generatingImage = false
    @Environment(\.supportsImagePlayground) private var supportsImagePlayground
    @State private var tags: [String]
    @State private var source: String
    @State private var notes: String

    init(
        recipe: Recipe, scannedText: String? = nil, scannedTextTitle: String = "Scanned text", notice: String? = nil,
        initialImage: Data? = nil, initialStepImages: [Data?] = [], onCancel: (() -> Void)? = nil,
        onSave: @escaping (Recipe, ImageChange, StepImageChanges) -> Void
    ) {
        self.onCancel = onCancel
        original = recipe
        self.scannedText = scannedText
        self.scannedTextTitle = scannedTextTitle
        self.notice = notice
        self.initialImage = initialImage
        self.onSave = onSave
        _imageChange = State(initialValue: initialImage.map(ImageChange.set) ?? .unchanged)
        _isFavorite = State(initialValue: recipe.isFavorite)
        _wantToCook = State(initialValue: recipe.wantToCook)
        _rating = State(initialValue: recipe.rating)
        _title = State(initialValue: recipe.title)
        _summary = State(initialValue: recipe.summary)
        _servings = State(initialValue: recipe.servings.map(String.init) ?? "")
        _prep = State(initialValue: recipe.prepMinutes.map(String.init) ?? "")
        _cook = State(initialValue: recipe.cookMinutes.map(String.init) ?? "")
        _ingredients = State(initialValue: Self.rows(for: recipe))
        _steps = State(initialValue: recipe.steps.enumerated().map { index, text in
            var line = EditableLine(text: text, time: recipe.timestamp(forStep: index).map(Recipe.clock) ?? "")
            line.imageID = recipe.stepImage(forStep: index)
            if initialStepImages.indices.contains(index), let data = initialStepImages[index] {
                line.imageID = UUID()
                line.newImage = data
            }
            return line
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
                    ForEach($ingredients) { $line in
                        ingredientRow(line: $line)
                    }
                    .onDelete { ingredients.remove(atOffsets: $0) }
                    .onMove { ingredients.move(fromOffsets: $0, toOffset: $1) }
                    .alwaysReorderable()
                    addButton("Add Ingredient") {
                        let line = EditableIngredient()
                        focused = line.id
                        ingredients.append(line)
                    }
                    addButton("Add Section") {
                        let line = EditableIngredient(heading: "")
                        focused = line.id
                        ingredients.append(line)
                    }
                    Button { Task { await groupIngredients() } } label: {
                        Label(isGrouping ? "Grouping…" : "Group with Apple Intelligence", systemImage: "sparkles")
                    }
                    .buttonStyle(.borderless)
                    .disabled(isGrouping || !AppleIntelligence.status.isAvailable || realIngredients.count < 4)
                } header: {
                    Text("Ingredients")
                } footer: {
                    if let groupingMessage {
                        Text(groupingMessage)
                    } else if !AppleIntelligence.status.isAvailable {
                        Text("Grouping needs Apple Intelligence. " + AppleIntelligence.status.explanation)
                    } else {
                        Text("Sections such as “Dough” and “Sauce” make a long list easier to scan. Drag a heading to move it.")
                    }
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
                    if (RatingStyle(rawValue: ratingStyleRaw) ?? .favorites) == .favorites {
                        Toggle(isOn: $isFavorite) { Label("Favorite", systemImage: "heart") }
                    } else {
                        LabeledContent { StarRatingView(rating: rating) { rating = $0 } } label: { Label("Rating", systemImage: "star") }
                    }
                    Toggle(isOn: $wantToCook) { Label("Up Next", systemImage: "text.line.first.and.arrowtriangle.forward") }
                }
                Section {
                    TagEditor(tags: $tags)
                } header: {
                    Text("Categories")
                } footer: {
                    Text("Keep categories generic: the main ingredient, vegetarian or vegan, and the course. Use a slash to nest one, like Dinner/Pasta.")
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
                ToolbarItem(placement: .cancellationAction) {
                    if let onCancel {
                        Button(action: onCancel) { Label("Cancel", systemImage: "xmark") }.labelStyle(.iconOnly)
                    } else {
                        CancelButton()
                    }
                }
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

    private var realIngredients: [String] {
        ingredients.filter { !$0.isHeading }.map(\.text).filter { !$0.isEmpty }
    }

    /// The editor's rows: each section heading, then its ingredients.
    static func rows(for recipe: Recipe) -> [EditableIngredient] {
        recipe.ingredientGroups.flatMap { group -> [EditableIngredient] in
            let heading = group.title.map { [EditableIngredient(heading: $0)] } ?? []
            return heading + group.items.map { EditableIngredient(parsing: $0.text) }
        }
    }

    private func groupIngredients() async {
        isGrouping = true
        groupingMessage = nil
        defer { isGrouping = false }
        let outcome = await IngredientGrouper.group(
            title: title, ingredients: realIngredients, steps: steps.map(\.text).filter { !$0.isEmpty }
        )
        withAnimation(.snappy) {
            switch outcome {
            case .grouped(let list, let sections):
                ingredients = Self.rows(for: Recipe(title: title, ingredients: list, ingredientSections: sections))
                groupingMessage = "Grouped into \(sections.count) sections. Drag ingredients between sections to fix any mix-ups."
            case .unchanged:
                groupingMessage = "These ingredients all belong together, so no sections were added."
            case .unavailable(let status):
                groupingMessage = status.explanation
            case .failed(let reason):
                groupingMessage = "Couldn't group the ingredients: \(reason)"
            }
        }
    }

    private func ingredientRow(line: Binding<EditableIngredient>) -> some View {
        if line.wrappedValue.isHeading { return AnyView(headingRow(line: line)) }
        return AnyView(plainIngredientRow(line: line))
    }

    private func headingRow(line: Binding<EditableIngredient>) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "text.alignleft").foregroundStyle(Theme.accent).accessibilityHidden(true)
            TextField("Section name", text: line.item)
                .font(.headline)
                .focused($focused, equals: line.wrappedValue.id)
            #if os(macOS)
            Button(role: .destructive) { ingredients.removeAll { $0.id == line.wrappedValue.id } } label: { Image(systemName: "minus.circle") }
                .buttonStyle(.borderless)
                .foregroundStyle(.secondary)
                .accessibilityLabel("Remove")
            #endif
        }
        .contextMenu { Button("Delete Section", role: .destructive) { ingredients.removeAll { $0.id == line.wrappedValue.id } } }
    }

    private func plainIngredientRow(line: Binding<EditableIngredient>) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            TextField("Qty", text: line.quantity)
                .multilineTextAlignment(.trailing)
                #if os(iOS)
                .keyboardType(.numbersAndPunctuation)
                #endif
                .frame(width: 46)
            UnitMenu(unit: line.unit)
            TextField("Ingredient", text: line.item, axis: .vertical)
                .focused($focused, equals: line.wrappedValue.id)
            #if os(macOS)
            Button(role: .destructive) { ingredients.removeAll { $0.id == line.wrappedValue.id } } label: { Image(systemName: "minus.circle") }
                .buttonStyle(.borderless)
                .foregroundStyle(.secondary)
                .accessibilityLabel("Remove")
            #endif
        }
        .contextMenu { Button("Delete", role: .destructive) { ingredients.removeAll { $0.id == line.wrappedValue.id } } }
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
            if number != nil { StepPhotoButton(line: line) }
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
        .contextMenu {
            if line.wrappedValue.imageID != nil {
                Button("Remove Photo", systemImage: "photo.badge.minus") {
                    line.wrappedValue.imageID = nil
                    line.wrappedValue.newImage = nil
                }
            }
            Button("Delete", role: .destructive, action: remove)
        }
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

    private func keptSteps() -> [(text: String, seconds: Int?, line: EditableLine)] {
        steps.compactMap { line in
            let text = line.text.trimmingCharacters(in: .whitespacesAndNewlines)
            return text.isEmpty ? nil : (text, Recipe.seconds(fromClock: line.time), line)
        }
    }

    private func assembled() -> Recipe {
        var recipe = original
        recipe.title = title
        recipe.summary = summary
        recipe.servings = Int(servings)
        recipe.prepMinutes = Int(prep)
        recipe.cookMinutes = Int(cook)
        var texts: [String] = []
        var sections: [IngredientSection] = []
        for row in ingredients {
            if row.isHeading {
                sections.append(IngredientSection(title: row.item, start: texts.count))
            } else if !row.text.isEmpty {
                texts.append(row.text)
            }
        }
        recipe.ingredients = texts
        recipe.ingredientSections = RecipeStandards.standardSections(sections, ingredientCount: texts.count)
        let kept = keptSteps()
        recipe.steps = kept.map(\.text)
        recipe.stepTimestamps = kept.contains { $0.seconds != nil } ? kept.map(\.seconds) : []
        recipe.stepImages = kept.contains { $0.line.imageID != nil } ? kept.map(\.line.imageID) : []
        recipe.tags = tags
        let trimmedSource = source.trimmingCharacters(in: .whitespaces)
        recipe.sourceURL = trimmedSource.isEmpty ? nil : trimmedSource
        recipe.notes = notes
        recipe.isFavorite = isFavorite
        recipe.rating = rating
        recipe.wantToCook = wantToCook
        recipe.queuedAt = wantToCook ? (original.wantToCook ? original.queuedAt : Date()) : nil
        return recipe
    }

    private func save() {
        let recipe = assembled()
        var changes = StepImageChanges()
        for case let (_, _, line) in keptSteps() {
            if let id = line.imageID, let data = line.newImage { changes.added[id] = data }
        }
        let kept = Set(recipe.stepImages.compactMap { $0 })
        changes.removed = original.stepImages.compactMap { $0 }.filter { !kept.contains($0) }
        onSave(recipe, imageChange, changes)
        dismiss()
    }
}

struct EditableLine: Identifiable, Hashable {
    let id = UUID()
    var text: String
    var time = ""
    var imageID: UUID?
    var newImage: Data?
}

struct EditableIngredient: Identifiable, Hashable {
    let id = UUID()
    var quantity = ""
    var unit: IngredientUnit?
    var item = ""
    /// A section heading (its title is in `item`) rather than an ingredient.
    var isHeading = false

    init() {}

    init(heading: String) {
        item = heading
        isHeading = true
    }

    init(parsing text: String) {
        let parsed = Ingredient(parsing: text)
        quantity = parsed.quantity
        unit = parsed.unit
        item = parsed.item
    }

    /// Pasting a whole line such as "2 cups flour" into the item field still splits it into parts.
    var text: String {
        if quantity.trimmingCharacters(in: .whitespaces).isEmpty, unit == nil { return Ingredient(parsing: item).text }
        return Ingredient(quantity: quantity, unit: unit, item: item).text
    }
}

struct UnitMenu: View {
    @Binding var unit: IngredientUnit?

    var body: some View {
        Menu {
            Picker("Unit", selection: $unit) {
                Text("No unit").tag(IngredientUnit?.none)
                ForEach(IngredientUnit.Group.allCases, id: \.self) { group in
                    Section(group.rawValue) {
                        ForEach(IngredientUnit.units(in: group)) { Text($0.title).tag(Optional($0)) }
                    }
                }
            }
        } label: {
            Text(unit?.abbreviation ?? "unit")
                .foregroundStyle(unit == nil ? Color.secondary : Theme.accent)
                .frame(minWidth: 54)
        }
        #if os(macOS)
        .menuStyle(.borderlessButton)
        .fixedSize()
        #endif
        .accessibilityLabel("Unit")
    }
}

struct StepPhotoButton: View {
    @Binding var line: EditableLine
    @State private var picked: PhotosPickerItem?

    var body: some View {
        PhotosPicker(selection: $picked, matching: .images) {
            thumbnail
                .frame(width: 36, height: 36)
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.borderless)
        .accessibilityLabel(line.imageID == nil ? "Add step photo" : "Change step photo")
        .onChange(of: picked) { _, item in
            guard let item else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self),
                   let jpeg = RecipeImageProcessing.jpegData(from: data, maxPixelSize: 1200) {
                    line.imageID = UUID()
                    line.newImage = jpeg
                }
                picked = nil
            }
        }
    }

    @ViewBuilder
    private var thumbnail: some View {
        if let data = line.newImage, let image = RecipeImageProcessing.thumbnail(from: data, maxPixelSize: 120) {
            Image(decorative: image, scale: 1).resizable().scaledToFill()
        } else if let id = line.imageID {
            StepImageView(id: id).scaledToFill()
        } else {
            Image(systemName: "photo.badge.plus").foregroundStyle(.secondary).frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
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

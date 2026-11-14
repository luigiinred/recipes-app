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
    /// Called after the recipe is deleted from here, so the page behind the editor can close.
    var onDelete: (() -> Void)?

    @EnvironmentObject private var library: RecipeLibrary
    @State private var confirmingDelete = false
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
    @State private var steps: [EditableLine]
    @FocusState private var focused: EditorField?
    @State private var generatingImage = false
    @Environment(\.supportsImagePlayground) private var supportsImagePlayground
    @State private var tags: [String]
    @State private var source: String
    @State private var notes: String

    init(
        recipe: Recipe, scannedText: String? = nil, scannedTextTitle: String = "Scanned text", notice: String? = nil,
        initialImage: Data? = nil, initialStepImages: [Data?] = [], onCancel: (() -> Void)? = nil, onDelete: (() -> Void)? = nil,
        onSave: @escaping (Recipe, ImageChange, StepImageChanges) -> Void
    ) {
        self.onCancel = onCancel
        self.onDelete = onDelete
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
                            Text(scannedText).appFont(.caption).foregroundStyle(.secondary).textSelection(.enabled)
                        }
                    } footer: {
                        if notice == nil { Text("Check the recipe below against the scan before saving.") }
                    }
                }
                Section {
                    PlainField("Title", text: $title).appFont(.title3, weight: .semibold)
                    PlainField("Summary", text: $summary, axis: .vertical)
                }
                Section {
                    LabeledContent("Servings") { PlainField("", text: $servings).multilineTextAlignment(.trailing) }
                    LabeledContent("Prep minutes") { PlainField("", text: $prep).multilineTextAlignment(.trailing) }
                    LabeledContent("Cook minutes") { PlainField("", text: $cook).multilineTextAlignment(.trailing) }
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
                        focused = .quantity(line.id)
                        ingredients.append(line)
                    }
                    addButton("Add Section") {
                        let line = EditableIngredient(heading: "")
                        focused = .line(line.id)
                        ingredients.append(line)
                    }
                } header: {
                    Text("Ingredients")
                } footer: {
                    Text("Add a section only for a distinct part of the meal, like a salad’s dressing. Drag a heading to move it.")
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
                    Toggle(isOn: $isFavorite) { Label("Favorite", systemImage: "heart") }
                    LabeledContent { StarRatingView(rating: rating) { rating = $0 } } label: { Label("Rating", systemImage: "star") }
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
                    PlainField("Source URL", text: $source)
                    PlainField("Notes", text: $notes, axis: .vertical)
                }
                if isSaved {
                    Section {
                        Button("Delete Recipe…", role: .destructive) { confirmingDelete = true }
                            .frame(maxWidth: .infinity)
                    }
                }
            }
            .confirmationDialog("Delete “\(original.title)”?", isPresented: $confirmingDelete, titleVisibility: .visible) {
                Button("Delete Recipe", role: .destructive) {
                    Task { await library.delete(original) }
                    onDelete?()
                    if let onCancel { onCancel() } else { dismiss() }
                }
            } message: {
                Text("This can't be undone. The recipe and its photo are removed from all your devices.")
            }
            .safeAreaInset(edge: .bottom, spacing: 0) { ingredientBar }
            .onChange(of: focused) { old, _ in tidyIngredient(leaving: old) }
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
        .frame(minWidth: 560, idealWidth: 600, minHeight: 640, idealHeight: 800)
        #endif
    }

    @ViewBuilder
    private func container<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        #if os(iOS)
        Form { content() }.scrollDismissesKeyboard(.immediately)
        #else
        Form { content() }.formStyle(.grouped)
        #endif
    }

    private func newLine() -> EditableLine {
        let line = EditableLine(text: "")
        focused = .line(line.id)
        return line
    }

    private func addButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) { Label(title, systemImage: "plus.circle.fill") }
            .buttonStyle(.borderless)
            .foregroundStyle(Theme.accent)
    }

    /// Only a recipe that is already in the library can be deleted; a new or imported draft is simply cancelled.
    private var isSaved: Bool { library.recipe(id: original.id) != nil }

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
            return heading + group.items.map { EditableIngredient(parsing: $0.text, customUnits: CustomUnits.all) }
        }
    }

    private func ingredientRow(line: Binding<EditableIngredient>) -> some View {
        if line.wrappedValue.isHeading { return AnyView(headingRow(line: line)) }
        return AnyView(plainIngredientRow(line: line))
    }

    private func headingRow(line: Binding<EditableIngredient>) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "text.alignleft").foregroundStyle(Theme.accent).accessibilityHidden(true)
            PlainField("Section name", text: line.item)
                .appFont(.headline)
                .focused($focused, equals: .line(line.wrappedValue.id))
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
        let id = line.wrappedValue.id
        return HStack(alignment: .firstTextBaseline, spacing: 8) {
            PlainField("Qty", text: line.quantity)
                .multilineTextAlignment(.trailing)
                #if os(iOS)
                .keyboardType(.numbersAndPunctuation)
                #endif
                .submitLabel(.next)
                .focused($focused, equals: .quantity(id))
                .onSubmit { focused = .unit(id) }
                .frame(width: 46)
                .accessibilityLabel("Quantity")
            PlainField("unit", text: line.unitText)
                #if os(iOS)
                .textInputAutocapitalization(.never)
                #endif
                .autocorrectionDisabled()
                .submitLabel(.next)
                .foregroundStyle(Theme.accent)
                .focused($focused, equals: .unit(id))
                .onSubmit { focused = .line(id) }
                .frame(width: 58)
                .accessibilityLabel("Unit")
            PlainField("Ingredient", text: line.item, axis: .vertical)
                .focused($focused, equals: .line(id))
            #if os(macOS)
            Button(role: .destructive) { ingredients.removeAll { $0.id == line.wrappedValue.id } } label: { Image(systemName: "minus.circle") }
                .buttonStyle(.borderless)
                .foregroundStyle(.secondary)
                .accessibilityLabel("Remove")
            #endif
        }
        .contextMenu { Button("Delete", role: .destructive) { ingredients.removeAll { $0.id == line.wrappedValue.id } } }
    }

    private var focusedIngredient: (index: Int, field: EditorField)? {
        guard let field = focused else { return nil }
        let id: UUID
        switch field {
        case .quantity(let line), .unit(let line): id = line
        case .line: return nil
        }
        return ingredients.firstIndex { $0.id == id }.map { ($0, field) }
    }

    @ViewBuilder
    private var ingredientBar: some View {
        if let focus = focusedIngredient {
            IngredientEntryBar(
                line: $ingredients[focus.index],
                field: focus.field,
                onNext: { focused = focus.field.next },
                onDone: { focused = nil }
            )
        }
    }

    /// Leaving a field writes it the standard way: "0.5" as "1/2", "Tablespoons" as "tbsp".
    private func tidyIngredient(leaving field: EditorField?) {
        switch field {
        case .quantity(let id):
            guard let index = ingredients.firstIndex(where: { $0.id == id }) else { return }
            let line = ingredients[index]
            let tidy = Ingredient.standardQuantity(line.quantity, unit: line.unit)
            if tidy != line.quantity { ingredients[index].quantity = tidy }
        case .unit(let id):
            guard let index = ingredients.firstIndex(where: { $0.id == id }) else { return }
            let line = ingredients[index]
            let tidy = line.unit?.abbreviation ?? line.unitText.trimmingCharacters(in: .whitespaces)
            if tidy != line.unitText { ingredients[index].unitText = tidy }
            let quantity = Ingredient.standardQuantity(line.quantity, unit: line.unit)
            if quantity != line.quantity { ingredients[index].quantity = quantity }
        default:
            break
        }
    }

    private func row(
        line: Binding<EditableLine>, placeholder: String, number: Int? = nil, showsTime: Bool = false, remove: @escaping () -> Void
    ) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            if let number {
                Text("\(number)")
                    .appFont(.footnote, weight: .bold)
                    .foregroundStyle(.white)
                    .frame(width: 22, height: 22)
                    .background(Theme.accent, in: Circle())
            }
            PlainField(placeholder, text: line.text, axis: .vertical)
                .focused($focused, equals: .line(line.wrappedValue.id))
            if number != nil { StepPhotoButton(line: line) }
            if showsTime {
                PlainField("m:ss", text: line.time)
                    .multilineTextAlignment(.trailing)
                    .appFont(.footnote).monospacedDigit()
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
        CustomUnits.remember(ingredients.compactMap(\.customUnit))
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

enum EditorField: Hashable {
    /// A step, a section heading, or an ingredient's item.
    case line(UUID)
    case quantity(UUID)
    case unit(UUID)

    var next: EditorField {
        switch self {
        case .quantity(let id): .unit(id)
        case .unit(let id), .line(let id): .line(id)
        }
    }
}

struct EditableIngredient: Identifiable, Hashable {
    let id = UUID()
    var quantity = ""
    /// A unit as typed: a known one such as "tbsp", or anything else, such as "knob".
    var unitText = ""
    var item = ""
    /// A section heading (its title is in `item`) rather than an ingredient.
    var isHeading = false

    init() {}

    init(heading: String) {
        item = heading
        isHeading = true
    }

    /// Units the parser doesn't know come back as the start of the item, so ones used before are split out again.
    init(parsing text: String, customUnits: [String] = []) {
        let parsed = Ingredient(parsing: text)
        quantity = parsed.quantity
        unitText = parsed.unit?.abbreviation ?? ""
        item = parsed.item
        guard parsed.unit == nil, !parsed.quantity.isEmpty else { return }
        let lowered = item.lowercased()
        if let custom = customUnits.sorted(by: { $0.count > $1.count }).first(where: { lowered.hasPrefix($0.lowercased() + " ") }) {
            unitText = String(item.prefix(custom.count))
            item = String(item.dropFirst(custom.count + 1))
        }
    }

    var unit: IngredientUnit? { IngredientUnit(alias: unitText.trimmingCharacters(in: .whitespaces)) }

    /// A typed unit the app doesn't know.
    var customUnit: String? {
        let typed = unitText.trimmingCharacters(in: .whitespaces)
        return typed.isEmpty || unit != nil ? nil : typed
    }

    /// Pasting a whole line such as "2 cups flour" into the item field still splits it into parts.
    var text: String {
        if quantity.trimmingCharacters(in: .whitespaces).isEmpty, unitText.trimmingCharacters(in: .whitespaces).isEmpty {
            return Ingredient(parsing: item).text
        }
        if let customUnit { return Ingredient(quantity: quantity, item: customUnit + " " + item).text }
        return Ingredient(quantity: quantity, unit: unit, item: item).text
    }
}

/// A text field whose placeholder stays inside the field. A grouped Mac form would otherwise turn it into a row label.
struct PlainField: View {
    let title: String
    @Binding var text: String
    var axis: Axis = .horizontal

    init(_ title: String, text: Binding<String>, axis: Axis = .horizontal) {
        self.title = title
        _text = text
        self.axis = axis
    }

    var body: some View {
        #if os(macOS)
        TextField("", text: $text, prompt: Text(title), axis: axis).labelsHidden()
        #else
        TextField(title, text: $text, axis: axis)
        #endif
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

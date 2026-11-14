import RecipeKit
import SwiftUI

extension View {
    /// Frames a recipe that isn't saved yet: Cancel in the navigation bar, any import notice on top, and Edit and Save floating at the bottom.
    func importPreviewChrome(notice: String?, isSaving: Bool, cancel: @escaping () -> Void, edit: @escaping () -> Void, save: @escaping () -> Void) -> some View {
        modifier(ImportPreviewChrome(notice: notice, isSaving: isSaving, cancel: cancel, edit: edit, save: save))
    }
}

private struct ImportPreviewChrome: ViewModifier {
    @Environment(\.appAccent) private var accent
    let notice: String?
    let isSaving: Bool
    let cancel: () -> Void
    let edit: () -> Void
    let save: () -> Void

    func body(content: Content) -> some View {
        content
            .safeAreaInset(edge: .top, spacing: 0) {
                if let notice {
                    Label(notice, systemImage: "exclamationmark.triangle.fill")
                        .appFont(.footnote, weight: .medium)
                        .foregroundStyle(.orange)
                        .padding(.horizontal, 14).padding(.vertical, 10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .padding(.horizontal, 16).padding(.vertical, 8)
                }
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                HStack(spacing: 12) {
                    Button(action: edit) { Label("Edit", systemImage: "pencil").padding(.horizontal, 6) }
                        .buttonStyle(.glass)
                    Button(action: save) {
                        Group {
                            if isSaving { ProgressView() } else { Label("Save Recipe", systemImage: "checkmark") }
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.glassProminent)
                    .disabled(isSaving)
                    .keyboardShortcut(.defaultAction)
                }
                .controlSize(.large)
                .tint(accent)
                .padding(.horizontal, 20)
                .padding(.top, 24)
                .padding(.bottom, 10)
                .frame(maxWidth: 520)
                .frame(maxWidth: .infinity)
                .background {
                    Rectangle().fill(.background)
                        .mask(LinearGradient(stops: [.init(color: .clear, location: 0), .init(color: .black, location: 0.45)], startPoint: .top, endPoint: .bottom))
                        .ignoresSafeArea()
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(action: cancel) { Label("Cancel", systemImage: "xmark") }.labelStyle(.iconOnly)
                }
            }
    }
}

/// A light, read-only recipe page for places without the full one, such as the share sheet.
struct RecipePreviewContent: View {
    @Environment(\.appAccent) private var accent
    let recipe: Recipe
    let imageData: Data?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                if let imageData, let image = RecipeImageProcessing.thumbnail(from: imageData, maxPixelSize: 1200) {
                    // An overlay, so a filled photo can't widen the page past the screen.
                    Color.clear
                        .frame(maxWidth: .infinity)
                        .frame(height: 220)
                        .overlay { Image(decorative: image, scale: 1).resizable().scaledToFill() }
                        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                }
                VStack(alignment: .leading, spacing: 8) {
                    Text(recipe.title.isEmpty ? "Untitled Recipe" : recipe.title).appFont(.largeTitle, weight: .bold)
                    if !recipe.summary.isEmpty { Text(recipe.summary).foregroundStyle(.secondary) }
                    if !facts.isEmpty {
                        Text(facts.joined(separator: "  ·  ")).appFont(.subheadline, weight: .semibold).foregroundStyle(accent)
                    }
                }
                if !recipe.ingredients.isEmpty {
                    section("Ingredients") {
                        ForEach(Array(recipe.ingredientGroups.enumerated()), id: \.offset) { _, group in
                            if let title = group.title {
                                Text(title).appFont(.headline).foregroundStyle(accent).padding(.top, 4)
                            }
                            ForEach(group.items, id: \.index) { Text(IngredientLine.styled($0.text)) }
                        }
                    }
                }
                if !recipe.steps.isEmpty {
                    section("Steps") {
                        ForEach(Array(recipe.steps.enumerated()), id: \.offset) { index, step in
                            HStack(alignment: .firstTextBaseline, spacing: 12) {
                                Text("\(index + 1)").appFont(.headline).foregroundStyle(accent).frame(minWidth: 20, alignment: .trailing)
                                Text(step)
                            }
                        }
                    }
                }
                if !recipe.notes.isEmpty {
                    section("Notes") { Text(recipe.notes).foregroundStyle(.secondary) }
                }
            }
            .padding(20)
            .frame(maxWidth: 720, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
    }

    private var facts: [String] {
        var facts: [String] = []
        if let servings = recipe.servings { facts.append("Serves \(servings)") }
        if let prep = recipe.prepMinutes, prep > 0 { facts.append("Prep \(prep) min") }
        if let cook = recipe.cookMinutes, cook > 0 { facts.append("Cook \(cook) min") }
        return facts
    }

    private func section(_ title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title.uppercased()).appFont(.caption, weight: .bold).tracking(1.2).foregroundStyle(.secondary)
            content()
        }
    }
}

#if !SHARE_EXTENSION
/// An import or scan before it's saved: the recipe page as it will look, Cancel, Edit for fixes, and Save.
struct ImportPreviewSheet: View {
    @EnvironmentObject private var library: RecipeLibrary
    @Environment(\.dismiss) private var dismiss
    let draft: ScanDraft
    let onSaved: (Recipe) -> Void
    @State private var editing = false
    @State private var isSaving = false

    var body: some View {
        NavigationStack {
            RecipeDetailView(recipe: draft.recipe, previewSave: {}, previewImage: draft.imageData, previewSaveInToolbar: false)
                .importPreviewChrome(notice: draft.notice, isSaving: isSaving, cancel: { dismiss() }, edit: { editing = true }, save: save)
        }
        .sheet(isPresented: $editing) {
            RecipeEditorView(recipe: draft.recipe, scannedText: draft.text, scannedTextTitle: draft.textTitle, notice: draft.notice,
                             initialImage: draft.imageData, initialStepImages: draft.stepImages) { saved, image, steps in
                Task {
                    await library.save(saved, image: image, steps: steps)
                    onSaved(saved)
                }
                dismiss()
            }
        }
    }

    private func save() {
        isSaving = true
        Task {
            let result = ImportResult(recipe: draft.recipe, imageData: draft.imageData, stepImageData: draft.stepImages)
            if let saved = await library.add(result) { onSaved(saved) }
            isSaving = false
            dismiss()
        }
    }
}
#endif

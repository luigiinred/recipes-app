import PhotosUI
import RecipeKit
import SwiftUI

struct IdeaDraft: Identifiable {
    let id = UUID()
    var photo: Data?
}

/// Jot down something to cook that has no recipe yet, like "Spaghetti" or "Frozen burgers".
struct NewIdeaSheet: View {
    @EnvironmentObject private var library: RecipeLibrary
    @Environment(\.dismiss) private var dismiss
    let onSaved: (Recipe) -> Void

    @State private var title = ""
    @State private var notes = ""
    @State private var imageData: Data?
    @State private var pickedItem: PhotosPickerItem?
    @State private var showingCamera = false
    @State private var isNaming = false

    init(photo: Data? = nil, onSaved: @escaping (Recipe) -> Void) {
        self.onSaved = onSaved
        _imageData = State(initialValue: photo.flatMap { RecipeImageProcessing.jpegData(from: $0) })
    }

    private var trimmedTitle: String { title.trimmingCharacters(in: .whitespacesAndNewlines) }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField(isNaming ? "Looking at your photo…" : "Spaghetti, frozen burgers, leftovers…", text: $title)
                        .overlay(alignment: .trailing) {
                            if isNaming { ProgressView().controlSize(.small) }
                        }
                }
                photoSection
                Section("Notes") {
                    TextField("Anything to remember", text: $notes, axis: .vertical)
                        .lineLimit(3...8)
                }
            }
            .formStyle(.grouped)
            .navigationTitle("New Idea")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { CancelButton() }
                ToolbarItem(placement: .confirmationAction) {
                    ConfirmButton(title: "Save", isDisabled: trimmedTitle.isEmpty) {
                        Task {
                            let idea = await library.addIdea(title: trimmedTitle, notes: notes.trimmingCharacters(in: .whitespacesAndNewlines), image: imageData)
                            onSaved(idea)
                        }
                        dismiss()
                    }
                }
            }
        }
        #if os(iOS)
        .fullScreenCover(isPresented: $showingCamera) {
            MealCamera(
                onFinish: { data in
                    showingCamera = false
                    usePhoto(data)
                },
                onCancel: { showingCamera = false }
            )
            .ignoresSafeArea()
        }
        #endif
        .onChange(of: pickedItem) { _, item in
            guard let item else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self) { usePhoto(data) }
                pickedItem = nil
            }
        }
        .task { nameFromPhoto() }
        #if os(macOS)
        .frame(minWidth: 380, minHeight: 280)
        #endif
    }

    private var photoSection: some View {
        Section("Photo") {
            HStack(spacing: 14) {
                photoPreview
                    .frame(width: 96, height: 72)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                VStack(alignment: .leading, spacing: 8) {
                    #if os(iOS)
                    if MealCamera.isAvailable {
                        Button { showingCamera = true } label: { Label("Take Photo", systemImage: "camera") }
                            .buttonStyle(.borderless)
                    }
                    #endif
                    PhotosPicker(selection: $pickedItem, matching: .images) {
                        Label(imageData == nil ? "Choose Photo" : "Change Photo", systemImage: "photo")
                    }
                    .buttonStyle(.borderless)
                    if imageData != nil {
                        Button("Remove Photo", role: .destructive) { imageData = nil }
                            .buttonStyle(.borderless)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var photoPreview: some View {
        if let imageData, let image = RecipeImageProcessing.thumbnail(from: imageData, maxPixelSize: 400) {
            Image(decorative: image, scale: 1).resizable().scaledToFill()
        } else {
            Color.secondary.opacity(0.12).overlay(Image(systemName: "photo").foregroundStyle(.secondary))
        }
    }

    private func usePhoto(_ data: Data) {
        guard let jpeg = RecipeImageProcessing.jpegData(from: data) else { return }
        imageData = jpeg
        nameFromPhoto()
    }

    /// Leaves a name the cook has already typed alone.
    private func nameFromPhoto() {
        guard trimmedTitle.isEmpty, !isNaming, let imageData else { return }
        isNaming = true
        Task {
            let name = await MealPhotoNamer.name(imageData: imageData)
            isNaming = false
            if trimmedTitle.isEmpty, let name { title = name }
        }
    }
}

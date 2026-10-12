import RecipeKit
import SwiftUI

struct ImportURLView: View {
    @Environment(\.dismiss) private var dismiss
    let onReview: (ImportResult) -> Void
    var onSaved: (Recipe) -> Void = { _ in }
    @EnvironmentObject private var library: RecipeLibrary
    @AppStorage(AppSettings.Key.reviewImports) private var reviewImports = true

    @State private var address = ""
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("https://", text: $address)
                        #if os(iOS)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        #endif
                        .onSubmit(importRecipe)
                } footer: {
                    Text("Paste a recipe page or a YouTube video. Pages need recipe data (most have it). Videos need the recipe in the description or captions.")
                }
                if let errorMessage {
                    Text(errorMessage).foregroundStyle(.red)
                }
            }
            .formStyle(.grouped)
            .navigationTitle("Import from Web or YouTube")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { CancelButton() }
                ToolbarItem(placement: .confirmationAction) {
                    if isLoading {
                        ProgressView().controlSize(.small)
                    } else {
                        ConfirmButton(title: "Import", isDisabled: address.isEmpty, action: importRecipe)
                    }
                }
            }
        }
        #if os(macOS)
        .frame(minWidth: 460, minHeight: 220)
        #endif
    }

    private func importRecipe() {
        guard !isLoading else { return }
        var text = address.trimmingCharacters(in: .whitespacesAndNewlines)
        if !text.contains("://") { text = "https://" + text }
        guard let url = URL(string: text), url.host != nil else {
            errorMessage = "That doesn't look like a web address."
            return
        }
        isLoading = true
        errorMessage = nil
        Task {
            do {
                let result = try await RecipeImporter.importResult(from: url)
                if !reviewImports, result.isComplete, let saved = await library.add(result) {
                    dismiss()
                    onSaved(saved)
                } else {
                    dismiss()
                    onReview(result)
                }
            } catch {
                errorMessage = error.localizedDescription
                isLoading = false
            }
        }
    }
}

import RecipeKit
import SwiftUI

struct ImportURLView: View {
    @Environment(\.dismiss) private var dismiss
    let onImport: (Recipe) -> Void

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
                    Text("Works with recipe pages that publish structured recipe data, which most do.")
                }
                if let errorMessage {
                    Text(errorMessage).foregroundStyle(.red)
                }
            }
            .formStyle(.grouped)
            .navigationTitle("Import from Web")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    if isLoading {
                        ProgressView().controlSize(.small)
                    } else {
                        Button("Import", action: importRecipe).disabled(address.isEmpty)
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
                let recipe = try await RecipeImporter.recipe(from: url)
                onImport(recipe)
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
                isLoading = false
            }
        }
    }
}

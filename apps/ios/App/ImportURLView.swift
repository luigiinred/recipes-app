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
    @StateObject private var progress = ImportProgressModel()
    @State private var errorMessage: String?
    @State private var offersAppleIntelligence = false

    var body: some View {
        NavigationStack {
            Form {
                if isLoading {
                    Section {
                        VStack(spacing: 12) {
                            TomatoWokLoader(height: 120).frame(maxWidth: .infinity)
                            Text(address).font(.footnote).foregroundStyle(.secondary).lineLimit(1).truncationMode(.middle)
                            ImportProgressView(model: progress)
                        }
                        .padding(.vertical, 4)
                    }
                    .transition(.opacity)
                } else {
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
                if offersAppleIntelligence { appleIntelligenceRow }
                }
            }
            .formStyle(.grouped)
            .animation(.snappy, value: isLoading)
            .navigationTitle("Import from Web or YouTube")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { CancelButton() }
                ToolbarItem(placement: .confirmationAction) {
                    ConfirmButton(title: "Import", isDisabled: address.isEmpty || isLoading, action: importRecipe)
                }
            }
        }
        #if os(macOS)
        .frame(minWidth: 460, minHeight: 260)
        #endif
    }

    private var appleIntelligenceRow: some View {
        let status = AppleIntelligence.status
        return Section {
            Button { importRecipe(usingAppleIntelligence: true) } label: {
                Label("Try with Apple Intelligence", systemImage: "apple.intelligence")
            }
            .disabled(!status.isAvailable)
        } footer: {
            Text(status.isAvailable
                 ? "Reads the page's text on this device and writes the recipe out for you to check."
                 : status.explanation)
        }
    }

    private func importRecipe() { importRecipe(usingAppleIntelligence: false) }

    private func importRecipe(usingAppleIntelligence: Bool) {
        guard !isLoading else { return }
        var text = address.trimmingCharacters(in: .whitespacesAndNewlines)
        if !text.contains("://") { text = "https://" + text }
        guard let url = URL(string: text), url.host != nil else {
            errorMessage = "That doesn't look like a web address."
            return
        }
        isLoading = true
        errorMessage = nil
        offersAppleIntelligence = false
        progress.reset()
        Task {
            do {
                let result = usingAppleIntelligence
                    ? try await RecipeImporter.importResultWithAppleIntelligence(from: url, progress: progress.report)
                    : try await RecipeImporter.importResult(from: url, progress: progress.report)
                if !reviewImports, result.isComplete, let saved = await library.add(result) {
                    dismiss()
                    onSaved(saved)
                } else {
                    dismiss()
                    onReview(result)
                }
            } catch {
                errorMessage = error.localizedDescription
                offersAppleIntelligence = (error as? RecipeError) == .invalid(RecipeImporter.noRecipeMessage)
                    || (usingAppleIntelligence && YouTubeImporter.videoID(from: url) == nil)
                isLoading = false
            }
        }
    }
}

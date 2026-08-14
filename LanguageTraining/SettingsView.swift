import SwiftUI
import Combine
import AppKit

struct SettingsView: View {
    @EnvironmentObject private var store: CardStore
    @EnvironmentObject private var settings: AppSettings

    @State private var errorMessage: String?
    @State private var successMessage: String?
    @State private var isExporting = false
    @State private var isImporting = false

    private let explanationLanguages = [
        "English",
        "Japanese",
        "Korean",
        "Simplified Chinese",
        "Traditional Chinese",
        "Vietnamese",
        "French",
        "Spanish",
        "German"
    ]

    var body: some View {
        Form {
            Section("OpenAI") {
                SecureField("API Key", text: $settings.apiKey)
                    .textContentType(.password)
                    .help("Saved in the macOS Keychain")

                TextField("Model", text: $settings.openAIModel)

                Picker("Explanation Language", selection: $settings.explanationLanguage) {
                    ForEach(explanationLanguages, id: \.self) { language in
                        Text(language).tag(language)
                    }
                }

                TextField("Base URL", text: $settings.openAIBaseURL)
                    .autocorrectionDisabled()

                Text("Default: https://api.openai.com")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if let previewURL = constructedURL {
                    LabeledContent("Endpoint") {
                        Text(previewURL)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                    }
                } else {
                    Text("Enter a valid https URL.")
                        .font(.caption)
                        .foregroundStyle(.red)
                }

                if let baseURLWarning {
                    Text(baseURLWarning)
                        .font(.caption)
                        .foregroundStyle(.orange)
                        .textSelection(.enabled)
                }
            }

            Section("Library") {
                Text("Export or import learning cards and audio as a ZIP archive. Import backs up existing data first.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                HStack {
                    Button(action: exportData) {
                        Label(isExporting ? "Exporting…" : "Export", systemImage: "square.and.arrow.up")
                    }
                    .disabled(isExporting || isImporting)

                    Button(action: importData) {
                        Label(isImporting ? "Importing…" : "Import", systemImage: "square.and.arrow.down")
                    }
                    .disabled(isExporting || isImporting)

                    Button(action: revealDataFolder) {
                        Label("Show in Finder", systemImage: "folder")
                    }
                }
            }

            if let errorMessage {
                Section {
                    Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.red)
                        .textSelection(.enabled)
                }
            }

            if let successMessage {
                Section {
                    Label(successMessage, systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                }
            }
        }
        .formStyle(.grouped)
        .frame(minWidth: 520, minHeight: 420)
        .padding(8)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    saveSettings()
                }
                .keyboardShortcut(.defaultAction)
            }
        }
    }

    private func saveSettings() {
        do {
            guard constructedURL != nil else {
                errorMessage = "Base URL must be a valid https URL."
                successMessage = nil
                return
            }
            try settings.save()
            errorMessage = nil
            successMessage = "Settings saved."
        } catch {
            successMessage = nil
            errorMessage = error.localizedDescription
        }
    }
    
    // MARK: - Actions
    
    private func exportData() {
        Task {
            isExporting = true
            errorMessage = nil
            successMessage = nil
            
            do {
                let url = try await DataManager.exportAllData()
                successMessage = "Exported: \(url.lastPathComponent)"
                NSWorkspace.shared.activateFileViewerSelecting([url])
            } catch DataManagerError.userCancelled {
            } catch {
                errorMessage = "Export failed: \(error.localizedDescription)"
            }
            
            isExporting = false
        }
    }
    
    private func importData() {
        Task {
            isImporting = true
            errorMessage = nil
            successMessage = nil
            
            do {
                let count = try await DataManager.importData()
                store.reloadData()
                successMessage = "Imported \(count) cards."
            } catch DataManagerError.userCancelled {
            } catch {
                errorMessage = "Import failed: \(error.localizedDescription)"
            }
            
            isImporting = false
        }
    }
    
    private func revealDataFolder() {
        do {
            try DataManager.revealDataFolder()
        } catch {
            errorMessage = "Could not open the folder: \(error.localizedDescription)"
        }
    }
    
    private var constructedURL: String? {
        let trimmed = settings.openAIBaseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let base = URL(string: trimmed) else { return nil }
        guard base.scheme?.lowercased() == "https" else { return nil }
        guard base.host?.isEmpty == false else { return nil }
        var urlString = base.absoluteString
        while urlString.hasSuffix("/") {
            urlString.removeLast()
        }
        urlString += "/v1/chat/completions"
        return urlString
    }

    private var baseURLWarning: String? {
        let trimmed = settings.openAIBaseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let base = URL(string: trimmed),
              base.scheme?.lowercased() == "https",
              let host = base.host?.lowercased(),
              host != "api.openai.com" else {
            return nil
        }
        return "This custom endpoint will receive your API key. Only use a provider you trust."
    }
}

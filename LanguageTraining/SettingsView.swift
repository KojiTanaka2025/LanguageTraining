import SwiftUI
import Combine

struct SettingsView: View {
    @EnvironmentObject private var settings: AppSettings
    @Environment(\.dismiss) private var dismiss

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
        VStack(alignment: .leading, spacing: 16) {
            Text("Settings")
                .font(.title2)
                .bold()

            Form {
                Section("OpenAI") {
                    SecureField("API Key (saved in Keychain)", text: $settings.apiKey)
                        .textContentType(.password)

                    TextField("Model", text: $settings.openAIModel)

                    Picker("Explanation Language", selection: $settings.explanationLanguage) {
                        ForEach(explanationLanguages, id: \.self) { language in
                            Text(language).tag(language)
                        }
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        TextField("Base URL", text: $settings.openAIBaseURL)
                            .autocorrectionDisabled()
                        
                        Text("Example: https://api.openai.com")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        
                        if let previewURL = constructedURL {
                            Text("Resolved endpoint: \(previewURL)")
                                .font(.caption)
                                .foregroundStyle(.blue)
                                .textSelection(.enabled)
                        } else {
                            Text("Invalid URL")
                                .font(.caption)
                                .foregroundStyle(.red)
                        }
                    }
                }
                
                Section("Data Management") {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Back up or share your learning card data.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        
                        HStack(spacing: 12) {
                            Button(action: exportData) {
                                Label(isExporting ? "Exporting..." : "Export Data", systemImage: "square.and.arrow.up")
                            }
                            .disabled(isExporting || isImporting)
                            
                            Button(action: importData) {
                                Label(isImporting ? "Importing..." : "Import Data", systemImage: "square.and.arrow.down")
                            }
                            .disabled(isExporting || isImporting)
                            
                            Button(action: revealDataFolder) {
                                Label("Show in Finder", systemImage: "folder")
                            }
                        }
                        .buttonStyle(.bordered)
                    }
                }
            }
            .formStyle(.grouped)

            if let errorMessage {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.red)
                    Text(errorMessage)
                        .foregroundStyle(.red)
                        .font(.callout)
                        .textSelection(.enabled)
                }
            }
            
            if let successMessage {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                    Text(successMessage)
                        .foregroundStyle(.green)
                        .font(.callout)
                }
            }

            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                Button("Save") {
                    do {
                        try settings.save()
                        dismiss()
                    } catch {
                        errorMessage = error.localizedDescription
                    }
                }
                .keyboardShortcut(.defaultAction)
            }
            
            // デバッグ情報
            Divider()
            Text("Tip: You usually do not need to change the Base URL. The default value works for OpenAI.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(20)
        .frame(width: 600)
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
                
                // Finderで表示
                NSWorkspace.shared.activateFileViewerSelecting([url])
            } catch DataManagerError.userCancelled {
                // ユーザーがキャンセル - 何もしない
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
                successMessage = "Imported \(count) cards."
                
                // データを再読み込みするために画面を閉じる
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    dismiss()
                }
            } catch DataManagerError.userCancelled {
                // ユーザーがキャンセル - 何もしない
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
        var urlString = base.absoluteString
        while urlString.hasSuffix("/") {
            urlString.removeLast()
        }
        urlString += "/v1/chat/completions"
        return urlString
    }
}

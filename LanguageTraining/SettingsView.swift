import SwiftUI
import Combine
import UniformTypeIdentifiers

#if os(macOS)
import AppKit
#endif

struct SettingsView: View {
    @EnvironmentObject private var store: CardStore
    @EnvironmentObject private var settings: AppSettings

    @State private var errorMessage: String?
    @State private var successMessage: String?
    @State private var isExporting = false
    @State private var isImporting = false
    @State private var isImportingFile = false
    @State private var isExportingFile = false
    @State private var isPickingFolder = false
    @State private var exportDocument = ExportedZipDocument(data: Data())
    @State private var isPresentingNewTag = false
    @State private var tagErrorMessage: String?

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
                    .help("Saved in the Keychain on this device")

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

            Section("iCloud Drive") {
                LabeledContent("Library") {
                    Text(store.isUsingiCloud ? "iCloud Drive" : "This device only")
                }
                Text("On iPhone, tap Choose Folder, then Browse → iCloud Drive → LanguageTraining, and tap Open. You can also select iCloud Drive itself; the app will use a LanguageTraining folder inside it.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("If both devices edit at the same time, the last save wins. After saving on one device, wait for iCloud Drive to finish syncing before editing on the other.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Button("Choose Folder…") {
                    isPickingFolder = true
                }
                #if os(iOS)
                if store.isUsingiCloud {
                    Button("Use This Device Only") {
                        AppStorage.clearSharedLibraryFolder()
                        store.reloadData()
                        successMessage = "This iPhone will keep its own library."
                    }
                }
                #endif
            }

            Section("Tags") {
                Text("Colored tags are stored in the library (cards.json) and sync with iCloud Drive. Assign them when saving, from each card’s dropdown, or from the Library context menu.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                ForEach(store.tags) { tag in
                    HStack(spacing: 10) {
                        Menu {
                            ForEach(LibraryTag.palette, id: \.self) { hex in
                                Button {
                                    updateTagColor(tag.name, hex)
                                } label: {
                                    Label {
                                        Text(hex)
                                    } icon: {
                                        if tag.colorHex == hex {
                                            Image(systemName: "checkmark")
                                        } else {
                                            TagSwatch(colorHex: hex, size: 10)
                                        }
                                    }
                                }
                            }
                        } label: {
                            TagSwatch(colorHex: tag.colorHex, size: 14)
                        }
                        .menuStyle(.borderlessButton)
                        .help("Change color")

                        Text(tag.name)
                        Spacer()
                        Button(role: .destructive) {
                            removeTag(tag.name)
                        } label: {
                            Image(systemName: "trash")
                        }
                        .buttonStyle(.borderless)
                        .help("Remove this tag and clear it from cards")
                    }
                }

                Button("New Tag…") {
                    isPresentingNewTag = true
                }

                if let tagErrorMessage {
                    Text(tagErrorMessage)
                        .font(.caption)
                        .foregroundStyle(.red)
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

                    #if os(macOS)
                    Button(action: revealDataFolder) {
                        Label("Show in Finder", systemImage: "folder")
                    }
                    #endif
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
        #if os(macOS)
        .frame(minWidth: 520, minHeight: 420)
        .padding(8)
        #endif
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    saveSettings()
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .fileImporter(isPresented: $isImportingFile, allowedContentTypes: [.zip]) { result in
            Task {
                await importPickedFile(result)
            }
        }
        #if os(iOS)
        .sheet(isPresented: $isPickingFolder) {
            DocumentFolderPicker(
                onPick: { url in
                    isPickingFolder = false
                    pickSharedFolder(url)
                },
                onCancel: {
                    isPickingFolder = false
                }
            )
            .ignoresSafeArea()
        }
        #else
        .fileImporter(isPresented: $isPickingFolder, allowedContentTypes: [.folder], allowsMultipleSelection: false) { result in
            switch result {
            case .success(let urls):
                if let url = urls.first {
                    pickSharedFolder(url)
                }
            case .failure(let error):
                errorMessage = "Could not use that folder: \(error.localizedDescription)"
                successMessage = nil
            }
        }
        #endif
        .fileExporter(
            isPresented: $isExportingFile,
            document: exportDocument,
            contentType: .zip,
            defaultFilename: "LanguageTraining_Export"
        ) { result in
            isExporting = false
            switch result {
            case .success:
                successMessage = "Exported the library."
            case .failure(let error):
                errorMessage = "Export failed: \(error.localizedDescription)"
            }
        }
        .sheet(isPresented: $isPresentingNewTag) {
            NewTagSheet(isPresented: $isPresentingNewTag) { name, colorHex in
                do {
                    guard try store.addTag(name: name, colorHex: colorHex) != nil else { return false }
                    tagErrorMessage = nil
                    return true
                } catch {
                    tagErrorMessage = error.localizedDescription
                    return false
                }
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

    private func updateTagColor(_ name: String, _ colorHex: String) {
        do {
            try store.updateTagColor(name: name, colorHex: colorHex)
            tagErrorMessage = nil
        } catch {
            tagErrorMessage = error.localizedDescription
        }
    }

    private func removeTag(_ name: String) {
        do {
            try store.removeTag(name: name, clearFromCards: true)
            if settings.lastSaveCategory == name {
                settings.lastSaveCategory = LibraryTag.builtInDefaults[0].name
            }
            tagErrorMessage = nil
        } catch {
            tagErrorMessage = error.localizedDescription
        }
    }

    private func exportData() {
        #if os(macOS)
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
        #else
        Task {
            isExporting = true
            errorMessage = nil
            successMessage = nil
            do {
                exportDocument = ExportedZipDocument(data: try await Task.detached(priority: .userInitiated) {
                    try LibraryArchive.exportZipData()
                }.value)
                isExportingFile = true
            } catch {
                errorMessage = "Export failed: \(error.localizedDescription)"
                isExporting = false
            }
        }
        #endif
    }

    private func importData() {
        #if os(macOS)
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
        #else
        errorMessage = nil
        successMessage = nil
        isImportingFile = true
        #endif
    }

    private func pickSharedFolder(_ url: URL) {
        do {
            try AppStorage.setSharedLibraryFolder(url)
            store.reloadData()
            errorMessage = nil
            successMessage = "Using the selected iCloud Drive folder."
        } catch {
            errorMessage = "Could not use that folder: \(error.localizedDescription)"
            successMessage = nil
        }
    }

    private func importPickedFile(_ result: Result<URL, Error>) async {
        isImporting = true
        errorMessage = nil
        successMessage = nil
        do {
            let url = try result.get()
            let count = try await Task.detached(priority: .userInitiated) {
                try LibraryArchive.importZip(from: url)
            }.value
            store.reloadData()
            successMessage = "Imported \(count) cards."
        } catch {
            errorMessage = "Import failed: \(error.localizedDescription)"
        }
        isImporting = false
    }

    #if os(macOS)
    private func revealDataFolder() {
        do {
            try DataManager.revealDataFolder()
        } catch {
            errorMessage = "Could not open the folder: \(error.localizedDescription)"
        }
    }
    #endif

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

struct ExportedZipDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.zip] }
    static var writableContentTypes: [UTType] { [.zip] }

    var data: Data

    init(data: Data) {
        self.data = data
    }

    init(configuration: ReadConfiguration) throws {
        self.data = configuration.file.regularFileContents ?? Data()
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}

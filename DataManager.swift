import Foundation
import AppKit
import UniformTypeIdentifiers

/// データのエクスポート/インポートを管理するユーティリティ
struct DataManager {
    
    // MARK: - エクスポート
    
    /// すべてのカードデータと音声ファイルをZIPアーカイブにエクスポート
    /// - Parameter savePanel: 保存場所を選択するNSSavePanel
    /// - Returns: 成功した場合はエクスポート先のURL
    static func exportAllData(using savePanel: NSSavePanel? = nil) async throws -> URL {
        // 保存先を選択
        let panel = savePanel ?? createExportSavePanel()
        
        guard await panel.begin() == .OK, let destinationURL = panel.url else {
            throw DataManagerError.userCancelled
        }
        
        // 一時ディレクトリを作成
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("LanguageTrainingExport_\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        
        defer {
            // クリーンアップ
            try? FileManager.default.removeItem(at: tempDir)
        }
        
        // データディレクトリのURLを取得
        let sourceDir = try AppStorage.dataDirectoryURL()
        
        // データが存在するか確認
        guard FileManager.default.fileExists(atPath: sourceDir.path) else {
            throw DataManagerError.noDataFound
        }
        
        // 一時ディレクトリにコピー
        let exportDataDir = tempDir.appendingPathComponent(AppStorage.appName, isDirectory: true)
        try FileManager.default.copyItem(at: sourceDir, to: exportDataDir)
        
        // README.txtを追加
        let readme = createReadmeText()
        let readmeURL = tempDir.appendingPathComponent("README.txt", isDirectory: false)
        try readme.write(to: readmeURL, atomically: true, encoding: .utf8)
        
        // ZIPアーカイブを作成
        try await createZipArchive(from: tempDir, to: destinationURL)
        
        return destinationURL
    }
    
    /// デスクトップにエクスポート（簡易版）
    static func exportToDesktop() async throws -> URL {
        let desktop = FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first!
        let timestamp = ISO8601DateFormatter().string(from: Date()).replacingOccurrences(of: ":", with: "-")
        let filename = "LanguageTraining_Export_\(timestamp).zip"
        let destinationURL = desktop.appendingPathComponent(filename)
        
        // 既存ファイルを削除
        if FileManager.default.fileExists(atPath: destinationURL.path) {
            try FileManager.default.removeItem(at: destinationURL)
        }
        
        return try await exportAllData(to: destinationURL)
    }
    
    private static func exportAllData(to destinationURL: URL) async throws -> URL {
        // 一時ディレクトリを作成
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("LanguageTrainingExport_\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        
        defer {
            try? FileManager.default.removeItem(at: tempDir)
        }
        
        // データディレクトリのURLを取得
        let sourceDir = try AppStorage.dataDirectoryURL()
        
        guard FileManager.default.fileExists(atPath: sourceDir.path) else {
            throw DataManagerError.noDataFound
        }
        
        // コピー
        let exportDataDir = tempDir.appendingPathComponent(AppStorage.appName, isDirectory: true)
        try FileManager.default.copyItem(at: sourceDir, to: exportDataDir)
        
        // README追加
        let readme = createReadmeText()
        let readmeURL = tempDir.appendingPathComponent("README.txt", isDirectory: false)
        try readme.write(to: readmeURL, atomically: true, encoding: .utf8)
        
        // ZIP作成
        try await createZipArchive(from: tempDir, to: destinationURL)
        
        return destinationURL
    }
    
    // MARK: - インポート
    
    /// ZIPアーカイブからカードデータをインポート
    /// - Parameter openPanel: ファイル選択用のNSOpenPanel
    /// - Returns: インポートしたカード数
    static func importData(using openPanel: NSOpenPanel? = nil) async throws -> Int {
        // ファイルを選択
        let panel = openPanel ?? createImportOpenPanel()
        
        guard await panel.begin() == .OK, let sourceURL = panel.url else {
            throw DataManagerError.userCancelled
        }
        
        // 一時ディレクトリで展開
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("LanguageTrainingImport_\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        
        defer {
            try? FileManager.default.removeItem(at: tempDir)
        }
        
        // ZIPを展開
        try await extractZipArchive(from: sourceURL, to: tempDir)
        
        // Look for the current export folder first, then the legacy folder.
        let importedDataDir = tempDir.appendingPathComponent(AppStorage.appName, isDirectory: true)
        let legacyImportedDataDir = tempDir.appendingPathComponent(AppStorage.legacyAppName, isDirectory: true)
        let resolvedImportedDataDir = FileManager.default.fileExists(atPath: importedDataDir.path) ? importedDataDir : legacyImportedDataDir
        guard FileManager.default.fileExists(atPath: resolvedImportedDataDir.path) else {
            throw DataManagerError.invalidArchive
        }
        
        // cards.xmlが存在するか確認
        let cardsXMLURL = resolvedImportedDataDir.appendingPathComponent("cards.xml", isDirectory: false)
        guard FileManager.default.fileExists(atPath: cardsXMLURL.path) else {
            throw DataManagerError.noCardsFound
        }
        
        // 既存データのバックアップを作成
        try await backupCurrentData()
        
        // データをインポート
        let destinationDir = try AppStorage.dataDirectoryURL()
        
        // 既存データを削除
        if FileManager.default.fileExists(atPath: destinationDir.path) {
            try FileManager.default.removeItem(at: destinationDir)
        }
        
        // 新しいデータをコピー
        try FileManager.default.copyItem(at: resolvedImportedDataDir, to: destinationDir)
        
        // インポートしたカード数を返す
        let data = try Data(contentsOf: cardsXMLURL)
        let cards = try CardXMLCodec.decode(data: data)
        return cards.count
    }
    
    // MARK: - バックアップ
    
    /// 現在のデータをバックアップ
    static func backupCurrentData() async throws {
        let sourceDir = try AppStorage.dataDirectoryURL()
        
        guard FileManager.default.fileExists(atPath: sourceDir.path) else {
            return // バックアップするデータがない
        }
        
        let backupDir = try AppStorage.backupDirectoryURL()
        try FileManager.default.createDirectory(at: backupDir, withIntermediateDirectories: true)
        
        let timestamp = ISO8601DateFormatter().string(from: Date()).replacingOccurrences(of: ":", with: "-")
        let backupName = "Backup_\(timestamp)"
        let backupURL = backupDir.appendingPathComponent(backupName, isDirectory: true)
        
        try FileManager.default.copyItem(at: sourceDir, to: backupURL)
        
        // 古いバックアップを削除（最新5個まで保持）
        try cleanupOldBackups(in: backupDir, keepCount: 5)
    }
    
    private static func cleanupOldBackups(in directory: URL, keepCount: Int) throws {
        let contents = try FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.creationDateKey],
            options: [.skipsHiddenFiles]
        )
        
        let sorted = contents.sorted { url1, url2 in
            let date1 = try? url1.resourceValues(forKeys: [.creationDateKey]).creationDate ?? Date.distantPast
            let date2 = try? url2.resourceValues(forKeys: [.creationDateKey]).creationDate ?? Date.distantPast
            return (date1 ?? Date.distantPast) > (date2 ?? Date.distantPast)
        }
        
        // keepCount以降を削除
        for url in sorted.dropFirst(keepCount) {
            try FileManager.default.removeItem(at: url)
        }
    }
    
    // MARK: - Finderで表示
    
    /// データフォルダをFinderで開く
    static func revealDataFolder() throws {
        let appSupportURL = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let dataDir = try AppStorage.dataDirectoryURL()
        
        if FileManager.default.fileExists(atPath: dataDir.path) {
            NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: dataDir.path)
        } else {
            // フォルダがない場合は親ディレクトリを開く
            NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: appSupportURL.path)
        }
    }
    
    // MARK: - ヘルパーメソッド
    
    private static func createExportSavePanel() -> NSSavePanel {
        let panel = NSSavePanel()
        panel.title = "Export Card Data"
        panel.message = "Save all learning cards and audio files."
        panel.nameFieldLabel = "Save as:"
        panel.nameFieldStringValue = "LanguageTraining_Export_\(formattedDate()).zip"
        panel.allowedContentTypes = [.zip]
        panel.canCreateDirectories = true
        return panel
    }
    
    private static func createImportOpenPanel() -> NSOpenPanel {
        let panel = NSOpenPanel()
        panel.title = "Import Card Data"
        panel.message = "Select an exported ZIP file."
        panel.allowedContentTypes = [.zip]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        return panel
    }
    
    private static func formattedDate() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        return formatter.string(from: Date())
    }
    
    private static func createReadmeText() -> String {
        """
        LanguageTraining Data Export
        ================================
        
        This archive contains the following data:
        
        📁 LanguageTraining/
        ├── cards.xml          # all learning card data
        └── audio/             # audio files in MP3 format
        
        
        🔄 How to Import
        ----------------
        
        1. Launch LanguageTraining.
        2. Open Settings and choose Import Data.
        3. Select this ZIP file.
        4. Existing data is backed up automatically.
        
        
        📤 Manual Import
        ----------------
        
        1. Copy the LanguageTraining folder from this ZIP file to:
           ~/Library/Application Support/
        
        2. Existing data will be overwritten. Back up first if needed.
        
        
        💾 Backups
        ----------
        
        - Existing data is backed up automatically before import.
        - Backup location:
          ~/Library/Application Support/LanguageTraining_Backups/
        
        - The latest 5 backups are kept automatically.
        
        
        Exported at: \(ISO8601DateFormatter().string(from: Date()))
        """
    }
    
    // MARK: - ZIP操作（macOS標準コマンド使用）
    
    private static func createZipArchive(from sourceDir: URL, to destinationURL: URL) async throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
        process.arguments = [
            "-c", "-k", "--sequesterRsrc", "--keepParent",
            sourceDir.path,
            destinationURL.path
        ]
        
        try process.run()
        process.waitUntilExit()
        
        guard process.terminationStatus == 0 else {
            throw DataManagerError.zipFailed
        }
    }
    
    private static func extractZipArchive(from sourceURL: URL, to destinationDir: URL) async throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
        process.arguments = [
            "-x", "-k",
            sourceURL.path,
            destinationDir.path
        ]
        
        try process.run()
        process.waitUntilExit()
        
        guard process.terminationStatus == 0 else {
            throw DataManagerError.unzipFailed
        }
    }
}

// MARK: - エラー定義

enum DataManagerError: LocalizedError {
    case userCancelled
    case noDataFound
    case invalidArchive
    case noCardsFound
    case zipFailed
    case unzipFailed
    
    var errorDescription: String? {
        switch self {
        case .userCancelled:
            return "The operation was cancelled."
        case .noDataFound:
            return "No data was found to export."
        case .invalidArchive:
            return "The archive file is invalid."
        case .noCardsFound:
            return "No card data was found in the archive."
        case .zipFailed:
            return "Failed to create the ZIP archive."
        case .unzipFailed:
            return "Failed to extract the ZIP archive."
        }
    }
}

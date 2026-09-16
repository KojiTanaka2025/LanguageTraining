import Foundation

enum LibraryArchiveError: LocalizedError {
    case noDataFound
    case invalidArchive
    case unsafeArchive
    case noCardsFound

    var errorDescription: String? {
        switch self {
        case .noDataFound:
            return "No data was found to export."
        case .invalidArchive:
            return "The archive file is invalid."
        case .unsafeArchive:
            return "The archive contains unsupported or unsafe files."
        case .noCardsFound:
            return "No card data was found in the archive."
        }
    }
}

enum LibraryArchive {
    static func exportZipData() throws -> Data {
        let sourceDir = try AppStorage.dataDirectoryURL()
        guard FileManager.default.fileExists(atPath: sourceDir.path) else {
            throw LibraryArchiveError.noDataFound
        }
        try downloadUbiquitousTree(at: sourceDir)
        return try ZipArchive.zipDirectory(sourceDir, rootName: AppStorage.appName)
    }

    static func importZip(from url: URL) throws -> Int {
        let didAccess = url.startAccessingSecurityScopedResource()
        defer {
            if didAccess {
                url.stopAccessingSecurityScopedResource()
            }
        }
        let data = try Data(contentsOf: url)
        return try importZip(data: data)
    }

    static func importZip(data: Data) throws -> Int {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("LanguageTrainingImport_\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer {
            try? FileManager.default.removeItem(at: tempDir)
        }

        try ZipArchive.unzip(data, to: tempDir)

        let importedDataDir = tempDir.appendingPathComponent(AppStorage.appName, isDirectory: true)
        let legacyImportedDataDir = tempDir.appendingPathComponent(AppStorage.legacyAppName, isDirectory: true)
        let resolvedImportedDataDir = FileManager.default.fileExists(atPath: importedDataDir.path) ? importedDataDir : legacyImportedDataDir
        guard FileManager.default.fileExists(atPath: resolvedImportedDataDir.path) else {
            throw LibraryArchiveError.invalidArchive
        }

        let cardsJSONURL = LibraryFile.jsonURL(in: resolvedImportedDataDir)
        let cardsXMLURL = LibraryFile.xmlURL(in: resolvedImportedDataDir)
        guard FileManager.default.fileExists(atPath: cardsJSONURL.path)
                || FileManager.default.fileExists(atPath: cardsXMLURL.path) else {
            throw LibraryArchiveError.noCardsFound
        }

        try validateImportedDataDirectory(resolvedImportedDataDir)

        let libraryURL = FileManager.default.fileExists(atPath: cardsJSONURL.path) ? cardsJSONURL : cardsXMLURL
        let cards = try LibraryJSONCodec.decodeCardsFlexible(data: try Data(contentsOf: libraryURL))
        try backupCurrentData()

        let destinationDir = try AppStorage.dataDirectoryURL()
        if FileManager.default.fileExists(atPath: destinationDir.path) {
            try CoordinatedFile.removeItem(at: destinationDir)
        }
        try FileManager.default.copyItem(at: resolvedImportedDataDir, to: destinationDir)
        // Ensure the active library file is JSON after import.
        _ = try LibraryJSONCodec.loadDocument(fromDirectory: destinationDir)
        return cards.count
    }

    static func backupCurrentData() throws {
        let sourceDir = try AppStorage.dataDirectoryURL()
        guard FileManager.default.fileExists(atPath: sourceDir.path) else { return }

        try downloadUbiquitousTree(at: sourceDir)
        let backupDir = try AppStorage.backupDirectoryURL()
        try FileManager.default.createDirectory(at: backupDir, withIntermediateDirectories: true)

        let timestamp = ISO8601DateFormatter().string(from: Date()).replacingOccurrences(of: ":", with: "-")
        let backupURL = backupDir.appendingPathComponent("Backup_\(timestamp)", isDirectory: true)
        try FileManager.default.copyItem(at: sourceDir, to: backupURL)
        try cleanupOldBackups(in: backupDir, keepCount: 5)
    }

    private static func cleanupOldBackups(in directory: URL, keepCount: Int) throws {
        let contents = try FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.creationDateKey],
            options: [.skipsHiddenFiles]
        )
        let sorted = contents.sorted { lhs, rhs in
            let date1 = (try? lhs.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? .distantPast
            let date2 = (try? rhs.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? .distantPast
            return date1 > date2
        }
        for url in sorted.dropFirst(keepCount) {
            try FileManager.default.removeItem(at: url)
        }
    }

    private static func downloadUbiquitousTree(at directory: URL) throws {
        guard let enumerator = FileManager.default.enumerator(
            at: directory,
            includingPropertiesForKeys: [.isRegularFileKey, .isUbiquitousItemKey],
            options: [.skipsHiddenFiles]
        ) else { return }

        for case let itemURL as URL in enumerator {
            let values = try itemURL.resourceValues(forKeys: [.isRegularFileKey, .isUbiquitousItemKey])
            if values.isRegularFile == true, values.isUbiquitousItem == true {
                try CoordinatedFile.ensureLocalCopyBlocking(at: itemURL)
            }
        }
    }

    private static func validateImportedDataDirectory(_ directory: URL) throws {
        guard let enumerator = FileManager.default.enumerator(
            at: directory,
            includingPropertiesForKeys: [.isDirectoryKey, .isRegularFileKey, .isSymbolicLinkKey],
            options: []
        ) else {
            throw LibraryArchiveError.invalidArchive
        }

        for case let itemURL as URL in enumerator {
            let values = try itemURL.resourceValues(forKeys: [.isDirectoryKey, .isRegularFileKey, .isSymbolicLinkKey])
            if values.isSymbolicLink == true {
                throw LibraryArchiveError.unsafeArchive
            }

            let standardizedDir = directory.standardizedFileURL
            let standardizedItem = itemURL.standardizedFileURL
            let dirPath = standardizedDir.path.hasSuffix("/") ? standardizedDir.path : standardizedDir.path + "/"
            guard standardizedItem == standardizedDir || standardizedItem.path.hasPrefix(dirPath) else {
                throw LibraryArchiveError.unsafeArchive
            }

            let relativePath = standardizedItem == standardizedDir
                ? ""
                : String(standardizedItem.path.dropFirst(dirPath.count))
            if relativePath.isEmpty {
                continue
            }
            let filename = itemURL.lastPathComponent
            if filename == ".DS_Store" || filename.hasPrefix("._") {
                continue
            }

            if values.isDirectory == true {
                guard relativePath == "audio" else {
                    throw LibraryArchiveError.unsafeArchive
                }
                continue
            }

            guard values.isRegularFile == true else {
                throw LibraryArchiveError.unsafeArchive
            }
            if relativePath == LibraryFile.jsonName
                || relativePath == LibraryFile.xmlName
                || relativePath == LibraryFile.xmlMigratedName {
                continue
            }
            if relativePath.hasPrefix("audio/"), itemURL.pathExtension.lowercased() == "mp3" {
                continue
            }
            throw LibraryArchiveError.unsafeArchive
        }
    }
}

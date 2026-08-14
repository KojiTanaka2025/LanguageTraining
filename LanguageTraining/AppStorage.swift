import Foundation
import Darwin

enum AppStorage {
    static let appName = "LanguageTraining"
    static let legacyAppName = "EnglishCard"

    private static let bookmarkDefaultsKey = "languageTrainingSharedFolderBookmark"
    private static let usesSubfolderKey = "languageTrainingSharedFolderUsesAppSubfolder"
    private static let cacheLock = NSLock()
    private static var cachedDataDirectory: URL?
    private static var cachedUsesiCloud = false
    private static var accessedSecurityScopedURL: URL?

    static var isUsingiCloud: Bool {
        cacheLock.lock()
        defer { cacheLock.unlock() }
        return cachedUsesiCloud
    }

    static func prepare() throws {
        _ = try dataDirectoryURL()
    }

    static func resetCachedDirectory() {
        cacheLock.lock()
        if let accessedSecurityScopedURL {
            accessedSecurityScopedURL.stopAccessingSecurityScopedResource()
        }
        accessedSecurityScopedURL = nil
        cachedDataDirectory = nil
        cachedUsesiCloud = false
        cacheLock.unlock()
    }

    static func dataDirectoryURL() throws -> URL {
        cacheLock.lock()
        defer { cacheLock.unlock() }
        if let cachedDataDirectory {
            return cachedDataDirectory
        }

        let localURL = try localDataDirectoryURL()
        if let sharedURL = resolvedSharedLibraryURL() {
            try FileManager.default.createDirectory(at: sharedURL, withIntermediateDirectories: true)
            try migrateLocalLibraryIfNeeded(from: localURL, to: sharedURL)
            cachedUsesiCloud = true
            cachedDataDirectory = sharedURL
            return sharedURL
        }

        cachedUsesiCloud = false
        cachedDataDirectory = localURL
        return localURL
    }

    static func backupDirectoryURL() throws -> URL {
        let appSupportURL = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        return appSupportURL.appendingPathComponent("\(appName)_Backups", isDirectory: true)
    }

    static func setSharedLibraryFolder(_ url: URL) throws {
        let accessed = url.startAccessingSecurityScopedResource()
        defer {
            if accessed {
                url.stopAccessingSecurityScopedResource()
            }
        }

        let cardsURL = url.appendingPathComponent("cards.xml", isDirectory: false)
        let usesSubfolder = url.lastPathComponent != appName
            && !FileManager.default.fileExists(atPath: cardsURL.path)
        let libraryURL = usesSubfolder
            ? url.appendingPathComponent(appName, isDirectory: true)
            : url

        try FileManager.default.createDirectory(at: libraryURL, withIntermediateDirectories: true)
        let bookmark = try makeBookmark(for: url)
        UserDefaults.standard.set(bookmark, forKey: bookmarkDefaultsKey)
        UserDefaults.standard.set(usesSubfolder, forKey: usesSubfolderKey)
        resetCachedDirectory()
    }

    static func clearSharedLibraryFolder() {
        UserDefaults.standard.removeObject(forKey: bookmarkDefaultsKey)
        UserDefaults.standard.removeObject(forKey: usesSubfolderKey)
        resetCachedDirectory()
    }

    static func iCloudDriveLibraryURL() -> URL? {
        guard let home = realUserHomeDirectory() else { return nil }
        let cloudDocs = home
            .appendingPathComponent("Library/Mobile Documents/com~apple~CloudDocs", isDirectory: true)
        guard FileManager.default.fileExists(atPath: cloudDocs.path) else { return nil }
        return cloudDocs.appendingPathComponent(appName, isDirectory: true)
    }

    private static func resolvedSharedLibraryURL() -> URL? {
        if let bookmarked = resolveBookmarkedFolder() {
            return bookmarked
        }
        #if os(macOS)
        return iCloudDriveLibraryURL()
        #else
        return nil
        #endif
    }

    private static func resolveBookmarkedFolder() -> URL? {
        guard let data = UserDefaults.standard.data(forKey: bookmarkDefaultsKey) else { return nil }
        var isStale = false
        do {
            #if os(macOS)
            let url = try URL(
                resolvingBookmarkData: data,
                options: [.withSecurityScope],
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            )
            #else
            let url = try URL(
                resolvingBookmarkData: data,
                options: [],
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            )
            #endif
            _ = isStale
            if url.startAccessingSecurityScopedResource() {
                accessedSecurityScopedURL = url
            }
            if UserDefaults.standard.bool(forKey: usesSubfolderKey) {
                return url.appendingPathComponent(appName, isDirectory: true)
            }
            return url
        } catch {
            return nil
        }
    }

    private static func makeBookmark(for url: URL) throws -> Data {
        #if os(macOS)
        try url.bookmarkData(
            options: .withSecurityScope,
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        )
        #else
        try url.bookmarkData(
            options: [],
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        )
        #endif
    }

    private static func realUserHomeDirectory() -> URL? {
        guard let pw = getpwuid(getuid()), let dir = pw.pointee.pw_dir else { return nil }
        return URL(fileURLWithPath: String(cString: dir), isDirectory: true)
    }

    private static func localDataDirectoryURL() throws -> URL {
        let appSupportURL = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let currentURL = appSupportURL.appendingPathComponent(appName, isDirectory: true)
        let legacyURL = appSupportURL.appendingPathComponent(legacyAppName, isDirectory: true)

        if !FileManager.default.fileExists(atPath: currentURL.path),
           FileManager.default.fileExists(atPath: legacyURL.path) {
            try FileManager.default.copyItem(at: legacyURL, to: currentURL)
        }

        return currentURL
    }

    private static func migrateLocalLibraryIfNeeded(from localURL: URL, to sharedURL: URL) throws {
        let sharedCards = sharedURL.appendingPathComponent("cards.xml", isDirectory: false)
        if FileManager.default.fileExists(atPath: sharedCards.path) {
            return
        }

        let localCards = localURL.appendingPathComponent("cards.xml", isDirectory: false)
        guard FileManager.default.fileExists(atPath: localCards.path) else { return }
        guard FileManager.default.fileExists(atPath: localURL.path) else { return }

        if FileManager.default.fileExists(atPath: sharedURL.path) {
            let contents = try FileManager.default.contentsOfDirectory(atPath: sharedURL.path)
                .filter { !$0.hasPrefix(".") }
            if contents.isEmpty {
                try FileManager.default.removeItem(at: sharedURL)
            } else {
                return
            }
        }

        try FileManager.default.copyItem(at: localURL, to: sharedURL)
    }
}

import Foundation

enum AppStorage {
    static let appName = "LanguageTraining"
    static let legacyAppName = "EnglishCard"

    static func dataDirectoryURL() throws -> URL {
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

    static func backupDirectoryURL() throws -> URL {
        let appSupportURL = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        return appSupportURL.appendingPathComponent("\(appName)_Backups", isDirectory: true)
    }
}

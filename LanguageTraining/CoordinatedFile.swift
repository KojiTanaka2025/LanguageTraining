import Foundation

enum CoordinatedFileError: LocalizedError {
    case downloadTimedOut
    case missingData

    var errorDescription: String? {
        switch self {
        case .downloadTimedOut:
            return "Timed out while downloading the library from iCloud."
        case .missingData:
            return "The file could not be read."
        }
    }
}

enum CoordinatedFile {
    static func readData(at url: URL) throws -> Data {
        try ensureLocalCopy(at: url)

        var fileData: Data?
        var coordinatorError: NSError?
        var readError: Error?
        let coordinator = NSFileCoordinator()
        coordinator.coordinate(readingItemAt: url, options: [], error: &coordinatorError) { coordinatedURL in
            do {
                fileData = try Data(contentsOf: coordinatedURL)
            } catch {
                readError = error
            }
        }
        if let coordinatorError {
            throw coordinatorError
        }
        if let readError {
            throw readError
        }
        guard let fileData else {
            throw CoordinatedFileError.missingData
        }
        return fileData
    }

    static func writeData(_ data: Data, to url: URL) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)

        var coordinatorError: NSError?
        var writeError: Error?
        let coordinator = NSFileCoordinator()
        coordinator.coordinate(writingItemAt: url, options: .forReplacing, error: &coordinatorError) { coordinatedURL in
            do {
                try data.write(to: coordinatedURL, options: [.atomic])
            } catch {
                writeError = error
            }
        }
        if let coordinatorError {
            throw coordinatorError
        }
        if let writeError {
            throw writeError
        }
    }

    static func copyItem(at sourceURL: URL, to destinationURL: URL) throws {
        try ensureLocalCopy(at: sourceURL)
        try FileManager.default.createDirectory(at: destinationURL.deletingLastPathComponent(), withIntermediateDirectories: true)

        var readError: NSError?
        var writeError: NSError?
        var copyError: Error?
        let coordinator = NSFileCoordinator()
        coordinator.coordinate(readingItemAt: sourceURL, options: [], error: &readError) { coordinatedSource in
            coordinator.coordinate(writingItemAt: destinationURL, options: .forReplacing, error: &writeError) { coordinatedDestination in
                do {
                    if FileManager.default.fileExists(atPath: coordinatedDestination.path) {
                        try FileManager.default.removeItem(at: coordinatedDestination)
                    }
                    try FileManager.default.copyItem(at: coordinatedSource, to: coordinatedDestination)
                } catch {
                    copyError = error
                }
            }
        }
        if let readError {
            throw readError
        }
        if let writeError {
            throw writeError
        }
        if let copyError {
            throw copyError
        }
    }

    static func removeItem(at url: URL) throws {
        guard FileManager.default.fileExists(atPath: url.path) else { return }

        var coordinatorError: NSError?
        var removeError: Error?
        let coordinator = NSFileCoordinator()
        coordinator.coordinate(writingItemAt: url, options: .forDeleting, error: &coordinatorError) { coordinatedURL in
            do {
                try FileManager.default.removeItem(at: coordinatedURL)
            } catch {
                removeError = error
            }
        }
        if let coordinatorError {
            throw coordinatorError
        }
        if let removeError {
            throw removeError
        }
    }

    static func ensureLocalCopy(at url: URL) throws {
        let values = try url.resourceValues(forKeys: [
            .isUbiquitousItemKey,
            .ubiquitousItemDownloadingStatusKey
        ])
        guard values.isUbiquitousItem == true else { return }
        if values.ubiquitousItemDownloadingStatus == URLUbiquitousItemDownloadingStatus.current {
            return
        }

        try FileManager.default.startDownloadingUbiquitousItem(at: url)

        let deadline = Date().addingTimeInterval(45)
        while Date() < deadline {
            let status = try url.resourceValues(forKeys: [
                .ubiquitousItemDownloadingStatusKey,
                .ubiquitousItemDownloadingErrorKey
            ])
            if let error = status.ubiquitousItemDownloadingError {
                throw error
            }
            if status.ubiquitousItemDownloadingStatus == URLUbiquitousItemDownloadingStatus.current {
                return
            }
            Thread.sleep(forTimeInterval: 0.15)
        }
        throw CoordinatedFileError.downloadTimedOut
    }
}

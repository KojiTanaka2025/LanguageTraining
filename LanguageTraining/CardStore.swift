import Foundation
import SwiftUI
import Combine

enum CardStoreError: LocalizedError {
    case persistBlocked

    var errorDescription: String? {
        switch self {
        case .persistBlocked:
            return "Saving is disabled because the library could not be loaded. Restore your data first to avoid overwriting cards.xml."
        }
    }
}

@MainActor
final class CardStore: ObservableObject {
    @Published private(set) var cards: [Card] = []
    @Published var lastLoadedAt: Date? = nil
    @Published private(set) var loadErrorMessage: String? = nil
    @Published private(set) var isUsingiCloud = false

    private var hasLoaded = false
    private var canPersist = false
    private var lastPersistedData: Data?
    private var filePresenter: LibraryFilePresenter?
    private var iCloudObserver: NSObjectProtocol?

    func loadIfNeeded() {
        guard !hasLoaded else { return }
        hasLoaded = true
        Task {
            await loadLibrary()
        }
    }

    /// データを強制的に再読み込み（インポート後などに使用）
    func reloadData() {
        Task {
            await loadLibrary()
        }
    }

    func appendCard(sourceText: String, markdown: String, audioFileName: String? = nil) async throws {
        let card = Card(sourceText: sourceText, markdown: markdown, audioFileName: audioFileName)
        try appendCard(card)
    }

    /// カードをカスタムIDで追加（音声保存時に使用）
    func appendCard(_ card: Card) throws {
        try mutatingWithRollback {
            cards.insert(card, at: 0)
        }
    }

    /// カードを更新（音声追加など）
    func updateCard(_ updatedCard: Card) throws {
        guard let index = cards.firstIndex(where: { $0.id == updatedCard.id }) else { return }
        try mutatingWithRollback {
            cards[index] = updatedCard
        }
    }

    /// 音声ファイルを保存して、そのファイル名を返す
    func saveAudioFile(from tempURL: URL, for cardID: UUID) throws -> String {
        try ensureCanPersist()

        let audioDir = try audioDirectoryURL()
        try FileManager.default.createDirectory(at: audioDir, withIntermediateDirectories: true)

        let fileName = "\(cardID.uuidString).mp3"
        let destinationURL = audioDir.appendingPathComponent(fileName, isDirectory: false)
        try CoordinatedFile.copyItem(at: tempURL, to: destinationURL)
        return fileName
    }

    /// 音声ディレクトリのURLを取得
    func audioDirectoryURL() throws -> URL {
        try AppStorage.dataDirectoryURL()
            .appendingPathComponent("audio", isDirectory: true)
    }

    func deleteCards(at offsets: IndexSet) throws {
        let removed = offsets.compactMap { cards.indices.contains($0) ? cards[$0] : nil }
        try mutatingWithRollback {
            cards.remove(atOffsets: offsets)
        }
        for card in removed {
            if let audioURL = card.audioFileURL() {
                try? CoordinatedFile.removeItem(at: audioURL)
            }
        }
    }

    func deleteCard(_ card: Card) throws {
        try mutatingWithRollback {
            cards.removeAll { $0.id == card.id }
        }
        if let audioURL = card.audioFileURL() {
            try? CoordinatedFile.removeItem(at: audioURL)
        }
    }

    func persist() throws {
        try ensureCanPersist()
        let url = try dataFileURL()
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let data = try CardXMLCodec.encode(cards: cards)
        lastPersistedData = data
        try CoordinatedFile.writeData(data, to: url)
    }

    func dataFileURL() throws -> URL {
        let dir = try AppStorage.dataDirectoryURL()
        return dir.appendingPathComponent("cards.xml", isDirectory: false)
    }

    private func loadLibrary() async {
        do {
            try await Task.detached(priority: .userInitiated) {
                try AppStorage.prepare()
            }.value
            try loadFromDisk()
            isUsingiCloud = AppStorage.isUsingiCloud
            startWatchingLibraryFile()
            startWatchingiCloudIdentity()
        } catch {
            canPersist = false
            loadErrorMessage = error.localizedDescription
        }
    }

    private func loadFromDisk() throws {
        let url = try dataFileURL()
        if FileManager.default.fileExists(atPath: url.path) {
            let data = try CoordinatedFile.readData(at: url)
            cards = try CardXMLCodec.decode(data: data)
            lastPersistedData = data
        } else {
            cards = []
            lastPersistedData = nil
        }
        lastLoadedAt = Date()
        loadErrorMessage = nil
        canPersist = true
        hasLoaded = true
        isUsingiCloud = AppStorage.isUsingiCloud
    }

    private func ensureCanPersist() throws {
        guard canPersist else { throw CardStoreError.persistBlocked }
    }

    private func mutatingWithRollback(_ mutate: () throws -> Void) throws {
        try ensureCanPersist()
        let previous = cards
        do {
            try mutate()
            try persist()
        } catch {
            cards = previous
            throw error
        }
    }

    private func startWatchingLibraryFile() {
        if let filePresenter {
            NSFileCoordinator.removeFilePresenter(filePresenter)
            self.filePresenter = nil
        }
        guard let url = try? dataFileURL() else { return }
        let presenter = LibraryFilePresenter(url: url) { [weak self] in
            Task { @MainActor in
                self?.reloadFromExternalChange()
            }
        }
        filePresenter = presenter
        NSFileCoordinator.addFilePresenter(presenter)
    }

    private func startWatchingiCloudIdentity() {
        guard iCloudObserver == nil else { return }
        iCloudObserver = NotificationCenter.default.addObserver(
            forName: .NSUbiquityIdentityDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                AppStorage.resetCachedDirectory()
                self?.reloadData()
            }
        }
    }

    private func reloadFromExternalChange() {
        guard canPersist, let url = try? dataFileURL() else { return }
        guard FileManager.default.fileExists(atPath: url.path) else { return }
        do {
            let data = try CoordinatedFile.readData(at: url)
            if data == lastPersistedData {
                return
            }
            cards = try CardXMLCodec.decode(data: data)
            lastPersistedData = data
            lastLoadedAt = Date()
        } catch {
            loadErrorMessage = error.localizedDescription
        }
    }
}

private final class LibraryFilePresenter: NSObject, NSFilePresenter {
    let presentedItemURL: URL?
    let presentedItemOperationQueue: OperationQueue
    private let onChange: () -> Void

    init(url: URL, onChange: @escaping () -> Void) {
        presentedItemURL = url
        self.onChange = onChange
        let queue = OperationQueue()
        queue.name = "LanguageTraining.LibraryFilePresenter"
        queue.maxConcurrentOperationCount = 1
        presentedItemOperationQueue = queue
        super.init()
    }

    func presentedItemDidChange() {
        onChange()
    }

    func presentedItemDidGain(_ version: NSFileVersion) {
        onChange()
    }

    func presentedItemDidResolveConflict(_ version: NSFileVersion) {
        onChange()
    }
}

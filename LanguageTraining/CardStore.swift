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
    @Published private(set) var tags: [LibraryTag] = LibraryTag.builtInDefaults
    @Published var lastLoadedAt: Date? = nil
    @Published private(set) var loadErrorMessage: String? = nil
    @Published private(set) var isUsingiCloud = false
    @Published private(set) var isLoading = false

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

    func tag(named name: String) -> LibraryTag? {
        let key = LibraryTag.normalizedName(name)
        guard !key.isEmpty else { return nil }
        return tags.first { $0.name == key }
    }

    func colorHex(forCategory name: String) -> String {
        tag(named: name)?.colorHex ?? LibraryTag.defaultColorHex
    }

    func appendCard(sourceText: String, markdown: String, audioFileName: String? = nil, category: String = "") async throws {
        let card = Card(sourceText: sourceText, markdown: markdown, audioFileName: audioFileName, category: category)
        try appendCard(card)
    }

    /// カードをカスタムIDで追加（音声保存時に使用）
    func appendCard(_ card: Card) throws {
        try mutatingWithRollback {
            ensureTagExistsLocked(named: card.category)
            cards.insert(card, at: 0)
        }
    }

    /// カードを更新（音声追加など）
    func updateCard(_ updatedCard: Card) throws {
        guard let index = cards.firstIndex(where: { $0.id == updatedCard.id }) else { return }
        try mutatingWithRollback {
            ensureTagExistsLocked(named: updatedCard.category)
            cards[index] = updatedCard
        }
    }

    @discardableResult
    func addTag(name: String, colorHex: String) throws -> LibraryTag? {
        let trimmed = LibraryTag.normalizedName(name)
        guard !trimmed.isEmpty else { return nil }
        if tag(named: trimmed) != nil {
            return nil
        }
        let created = LibraryTag(name: trimmed, colorHex: colorHex)
        try mutatingWithRollback {
            tags.append(created)
        }
        return created
    }

    func updateTagColor(name: String, colorHex: String) throws {
        let trimmed = LibraryTag.normalizedName(name)
        guard let index = tags.firstIndex(where: { $0.name == trimmed }) else { return }
        try mutatingWithRollback {
            tags[index].colorHex = LibraryTag.normalizedColor(colorHex)
        }
    }

    func removeTag(name: String, clearFromCards: Bool = true) throws {
        let trimmed = LibraryTag.normalizedName(name)
        guard !trimmed.isEmpty else { return }
        try mutatingWithRollback {
            tags.removeAll { $0.name == trimmed }
            if clearFromCards {
                for index in cards.indices where cards[index].category == trimmed {
                    cards[index].category = ""
                }
            }
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
        let data = try CardXMLCodec.encode(tags: tags, cards: cards)
        lastPersistedData = data
        try CoordinatedFile.writeData(data, to: url)
    }

    func dataFileURL() throws -> URL {
        let dir = try AppStorage.dataDirectoryURL()
        return dir.appendingPathComponent("cards.xml", isDirectory: false)
    }

    private func loadLibrary() async {
        isLoading = true
        do {
            let snapshot = try await Task.detached(priority: .userInitiated) {
                try AppStorage.prepare()
                return try LibrarySnapshot.readFromDisk()
            }.value
            apply(snapshot)
            startWatchingLibraryFile()
            startWatchingiCloudIdentity()
        } catch {
            canPersist = false
            loadErrorMessage = error.localizedDescription
        }
        isLoading = false
    }

    private func apply(_ snapshot: LibrarySnapshot) {
        cards = snapshot.cards
        tags = snapshot.tags
        lastPersistedData = snapshot.persistedData
        lastLoadedAt = Date()
        loadErrorMessage = nil
        canPersist = true
        hasLoaded = true
        isUsingiCloud = snapshot.isUsingiCloud

        // One-time migrate UserDefaults custom categories into the library tag catalog.
        let extras = (UserDefaults.standard.stringArray(forKey: "customCategories") ?? [])
            .map(LibraryTag.normalizedName)
            .filter { !$0.isEmpty }
            .map { LibraryTag(name: $0, colorHex: LibraryTag.defaultColorHex) }
        if !extras.isEmpty {
            let merged = LibraryTag.mergedCatalog(
                existing: tags,
                usedNames: cards.map(\.category),
                extras: extras
            )
            if merged != tags {
                tags = merged
                try? persist()
            }
            UserDefaults.standard.removeObject(forKey: "customCategories")
        }
    }

    private func ensureCanPersist() throws {
        guard canPersist else { throw CardStoreError.persistBlocked }
    }

    private func ensureTagExistsLocked(named name: String) {
        let trimmed = LibraryTag.normalizedName(name)
        guard !trimmed.isEmpty else { return }
        guard !tags.contains(where: { $0.name == trimmed }) else { return }
        tags.append(LibraryTag(name: trimmed, colorHex: LibraryTag.defaultColorHex))
    }

    private func mutatingWithRollback(_ mutate: () throws -> Void) throws {
        try ensureCanPersist()
        let previousCards = cards
        let previousTags = tags
        do {
            try mutate()
            try persist()
        } catch {
            cards = previousCards
            tags = previousTags
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
                await self?.reloadFromExternalChange()
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

    private func reloadFromExternalChange() async {
        guard canPersist else { return }
        do {
            let snapshot = try await Task.detached(priority: .userInitiated) {
                try LibrarySnapshot.readFromDisk()
            }.value
            if snapshot.persistedData == lastPersistedData {
                return
            }
            cards = snapshot.cards
            tags = snapshot.tags
            lastPersistedData = snapshot.persistedData
            lastLoadedAt = Date()
            isUsingiCloud = snapshot.isUsingiCloud
        } catch {
            loadErrorMessage = error.localizedDescription
        }
    }
}

private struct LibrarySnapshot: Sendable {
    var tags: [LibraryTag]
    var cards: [Card]
    var persistedData: Data?
    var isUsingiCloud: Bool

    static func readFromDisk() throws -> LibrarySnapshot {
        let url = try AppStorage.dataDirectoryURL()
            .appendingPathComponent("cards.xml", isDirectory: false)
        if FileManager.default.fileExists(atPath: url.path) {
            let data = try CoordinatedFile.readData(at: url)
            let document = try CardXMLCodec.decode(data: data)
            return LibrarySnapshot(
                tags: document.tags,
                cards: document.cards,
                persistedData: data,
                isUsingiCloud: AppStorage.isUsingiCloud
            )
        }
        return LibrarySnapshot(
            tags: LibraryTag.builtInDefaults,
            cards: [],
            persistedData: nil,
            isUsingiCloud: AppStorage.isUsingiCloud
        )
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

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

    private var hasLoaded = false
    private var canPersist = false

    func loadIfNeeded() {
        guard !hasLoaded else { return }
        hasLoaded = true
        do {
            try loadFromDisk()
        } catch {
            canPersist = false
            loadErrorMessage = error.localizedDescription
        }
    }
    
    /// データを強制的に再読み込み（インポート後などに使用）
    func reloadData() {
        do {
            try loadFromDisk()
            hasLoaded = true
        } catch {
            canPersist = false
            loadErrorMessage = error.localizedDescription
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
        
        if FileManager.default.fileExists(atPath: destinationURL.path) {
            try FileManager.default.removeItem(at: destinationURL)
        }
        
        try FileManager.default.copyItem(at: tempURL, to: destinationURL)
        
        return fileName
    }
    
    /// 音声ディレクトリのURLを取得
    func audioDirectoryURL() throws -> URL {
        return try AppStorage.dataDirectoryURL()
            .appendingPathComponent("audio", isDirectory: true)
    }
    
    func deleteCards(at offsets: IndexSet) throws {
        let removed = offsets.compactMap { cards.indices.contains($0) ? cards[$0] : nil }
        try mutatingWithRollback {
            cards.remove(atOffsets: offsets)
        }
        for card in removed {
            if let audioURL = card.audioFileURL() {
                try? FileManager.default.removeItem(at: audioURL)
            }
        }
    }
    
    func deleteCard(_ card: Card) throws {
        try mutatingWithRollback {
            cards.removeAll { $0.id == card.id }
        }
        if let audioURL = card.audioFileURL() {
            try? FileManager.default.removeItem(at: audioURL)
        }
    }

    func persist() throws {
        try ensureCanPersist()
        let url = try dataFileURL()
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let data = try CardXMLCodec.encode(cards: cards)
        try data.write(to: url, options: [.atomic])
    }

    func dataFileURL() throws -> URL {
        let dir = try AppStorage.dataDirectoryURL()
        return dir.appendingPathComponent("cards.xml", isDirectory: false)
    }

    private func loadFromDisk() throws {
        let url = try dataFileURL()
        if FileManager.default.fileExists(atPath: url.path) {
            let data = try Data(contentsOf: url)
            cards = try CardXMLCodec.decode(data: data)
        } else {
            cards = []
        }
        lastLoadedAt = Date()
        loadErrorMessage = nil
        canPersist = true
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
}

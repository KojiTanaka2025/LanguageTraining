import Foundation
import SwiftUI
import Combine

@MainActor
final class CardStore: ObservableObject {
    @Published private(set) var cards: [Card] = []
    @Published var lastLoadedAt: Date? = nil

    private var hasLoaded = false

    func loadIfNeeded() {
        guard !hasLoaded else { return }
        hasLoaded = true
        do {
            let url = try dataFileURL()
            if FileManager.default.fileExists(atPath: url.path) {
                let data = try Data(contentsOf: url)
                self.cards = try CardXMLCodec.decode(data: data)
            } else {
                self.cards = []
            }
            self.lastLoadedAt = Date()
        } catch {
            // 破損などの場合でもアプリを落とさない
            self.cards = []
            self.lastLoadedAt = Date()
        }
    }
    
    /// データを強制的に再読み込み（インポート後などに使用）
    func reloadData() {
        do {
            let url = try dataFileURL()
            if FileManager.default.fileExists(atPath: url.path) {
                let data = try Data(contentsOf: url)
                self.cards = try CardXMLCodec.decode(data: data)
            } else {
                self.cards = []
            }
            self.lastLoadedAt = Date()
        } catch {
            // エラーが発生しても既存データを保持
            print("Failed to reload data: \(error)")
        }
    }

    func appendCard(sourceText: String, markdown: String, audioFileName: String? = nil) async throws {
        let card = Card(sourceText: sourceText, markdown: markdown, audioFileName: audioFileName)
        cards.insert(card, at: 0)
        try persist()
    }
    
    /// カードをカスタムIDで追加（音声保存時に使用）
    func appendCard(_ card: Card) throws {
        cards.insert(card, at: 0)
        try persist()
    }
    
    /// カードを更新（音声追加など）
    func updateCard(_ updatedCard: Card) throws {
        if let index = cards.firstIndex(where: { $0.id == updatedCard.id }) {
            cards[index] = updatedCard
            try persist()
        }
    }
    
    /// 音声ファイルを保存して、そのファイル名を返す
    func saveAudioFile(from tempURL: URL, for cardID: UUID) throws -> String {
        let audioDir = try audioDirectoryURL()
        try FileManager.default.createDirectory(at: audioDir, withIntermediateDirectories: true)
        
        let fileName = "\(cardID.uuidString).mp3"
        let destinationURL = audioDir.appendingPathComponent(fileName, isDirectory: false)
        
        // 既存ファイルがあれば削除
        if FileManager.default.fileExists(atPath: destinationURL.path) {
            try FileManager.default.removeItem(at: destinationURL)
        }
        
        // 一時ファイルをコピー
        try FileManager.default.copyItem(at: tempURL, to: destinationURL)
        
        return fileName
    }
    
    /// 音声ディレクトリのURLを取得
    func audioDirectoryURL() throws -> URL {
        return try AppStorage.dataDirectoryURL()
            .appendingPathComponent("audio", isDirectory: true)
    }
    
    func deleteCards(at offsets: IndexSet) throws {
        // 音声ファイルも削除
        for index in offsets {
            if let audioURL = cards[index].audioFileURL() {
                try? FileManager.default.removeItem(at: audioURL)
            }
        }
        cards.remove(atOffsets: offsets)
        try persist()
    }
    
    func deleteCard(_ card: Card) throws {
        // 音声ファイルも削除
        if let audioURL = card.audioFileURL() {
            try? FileManager.default.removeItem(at: audioURL)
        }
        cards.removeAll { $0.id == card.id }
        try persist()
    }

    func persist() throws {
        let url = try dataFileURL()
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let data = try CardXMLCodec.encode(cards: cards)
        try data.write(to: url, options: [.atomic])
    }

    func dataFileURL() throws -> URL {
        let dir = try AppStorage.dataDirectoryURL()
        return dir.appendingPathComponent("cards.xml", isDirectory: false)
    }
}

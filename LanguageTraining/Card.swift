import Foundation

struct Card: Identifiable, Hashable {
    let id: UUID
    let createdAt: Date
    var sourceText: String
    var markdown: String
    /// 音声ファイル名（Application Support内の相対パス）
    var audioFileName: String?

    init(
        id: UUID = UUID(),
        createdAt: Date = Date(),
        sourceText: String,
        markdown: String,
        audioFileName: String? = nil
    ) {
        self.id = id
        self.createdAt = createdAt
        self.sourceText = sourceText
        self.markdown = markdown
        self.audioFileName = audioFileName
    }
    
    /// 音声ファイルの絶対パスを取得
    func audioFileURL() -> URL? {
        guard let fileName = audioFileName else { return nil }
        guard let dataDir = try? AppStorage.dataDirectoryURL() else { return nil }

        let audioDir = dataDir
            .appendingPathComponent("audio", isDirectory: true)
        
        return audioDir.appendingPathComponent(fileName, isDirectory: false)
    }
}

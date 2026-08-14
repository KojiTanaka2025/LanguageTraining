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
        self.audioFileName = Self.sanitizedAudioFileName(audioFileName)
    }
    
    /// 音声ファイルの絶対パスを取得
    func audioFileURL() -> URL? {
        guard let fileName = Self.sanitizedAudioFileName(audioFileName) else { return nil }
        guard let dataDir = try? AppStorage.dataDirectoryURL() else { return nil }

        let audioDir = dataDir
            .appendingPathComponent("audio", isDirectory: true)
            .standardizedFileURL
        let destination = audioDir
            .appendingPathComponent(fileName, isDirectory: false)
            .standardizedFileURL

        let audioPrefix = audioDir.path.hasSuffix("/") ? audioDir.path : audioDir.path + "/"
        guard destination.path.hasPrefix(audioPrefix) else { return nil }
        return destination
    }

    static func isSafeAudioFileName(_ fileName: String) -> Bool {
        sanitizedAudioFileName(fileName) != nil
    }

    static func sanitizedAudioFileName(_ fileName: String?) -> String? {
        guard let fileName, !fileName.isEmpty else { return nil }
        let trimmed = fileName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed == (trimmed as NSString).lastPathComponent else { return nil }
        guard !trimmed.contains("..") else { return nil }
        guard trimmed.lowercased().hasSuffix(".mp3") else { return nil }
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_."))
        guard trimmed.unicodeScalars.allSatisfy({ allowed.contains($0) }) else { return nil }
        return trimmed
    }
}

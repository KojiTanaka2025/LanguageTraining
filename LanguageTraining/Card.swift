import Foundation

struct Card: Identifiable, Hashable, Sendable {
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

    /// Explanation for the UI: drop the unhelpful "easy wording" field, then show the source once as the title.
    var displayMarkdown: String {
        Self.displayMarkdown(from: markdown, sourceText: sourceText)
    }

    static func displayMarkdown(from markdown: String, sourceText: String? = nil) -> String {
        var lines = markdown.split(omittingEmptySubsequences: false, whereSeparator: \.isNewline).map(String.init)

        if let index = lines.firstIndex(where: { !$0.trimmingCharacters(in: .whitespaces).isEmpty }) {
            let heading = lines[index].trimmingCharacters(in: .whitespaces)
            if heading.hasPrefix("#"), !heading.hasPrefix("##") {
                lines.remove(at: index)
                while index < lines.count, lines[index].trimmingCharacters(in: .whitespaces).isEmpty {
                    lines.remove(at: index)
                }
            }
        }

        lines.removeAll { isEasyWordingField($0) }

        let body = lines.joined(separator: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let source = sourceText?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !source.isEmpty else { return body }
        if body.isEmpty { return "# \(source)" }
        return "# \(source)\n\n" + body
    }

    private static func isEasyWordingField(_ line: String) -> Bool {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        let prefixes = [
            "- かんたんな言い方:",
            "- Nói dễ hiểu:",
            "- 쉬운 말:",
            "- 简单说法:",
            "- 簡單說法:",
            "- En mots simples:",
            "- En palabras fáciles:",
            "- In einfachen Worten:",
            "- In easy words:",
        ]
        return prefixes.contains { trimmed.hasPrefix($0) }
    }
}

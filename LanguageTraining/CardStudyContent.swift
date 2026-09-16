import Foundation

/// English / Japanese sides extracted from a saved learning card for Study mode.
struct CardStudyContent: Hashable, Sendable {
    var english: String
    var japanese: String

    static func canStudy(_ card: Card) -> Bool {
        make(from: card) != nil
    }

    static func make(from card: Card) -> CardStudyContent? {
        let english = card.sourceText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !english.isEmpty else { return nil }
        if let japanese = card.explanation?.japaneseTranslation, !japanese.isEmpty {
            return CardStudyContent(english: english, japanese: japanese)
        }
        guard let japanese = extractJapanese(from: card.markdown), !japanese.isEmpty else {
            return nil
        }
        return CardStudyContent(english: english, japanese: japanese)
    }

    var prompt: (shown: String, hidden: String) {
        // Default helpers; StudyView picks by direction.
        (english, japanese)
    }

    func sides(for direction: StudyDirection) -> (prompt: String, answer: String) {
        switch direction {
        case .japaneseToEnglish:
            return (japanese, english)
        case .englishToJapanese:
            return (english, japanese)
        }
    }

    private static func extractJapanese(from markdown: String) -> String? {
        let lines = markdown.split(omittingEmptySubsequences: false, whereSeparator: \.isNewline).map(String.init)
        let labels = [
            "自然な日本語訳:",
            "自然な日本語訳：",
            "日本語訳:",
            "日本語訳：",
            "意味:",
            "意味：",
            "Natural Japanese:",
            "Translation:",
        ]

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard trimmed.hasPrefix("-") || trimmed.contains(":") || trimmed.contains("：") else { continue }
            for label in labels {
                if let value = valueAfterLabel(in: trimmed, label: label) {
                    let cleaned = cleanTranslation(value)
                    if !cleaned.isEmpty { return cleaned }
                }
            }
        }

        // Fallback: first non-heading bullet that looks like Japanese prose.
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard trimmed.hasPrefix("-") else { continue }
            var body = trimmed.dropFirst().trimmingCharacters(in: .whitespaces)
            if let idx = body.firstIndex(of: ":") {
                body = String(body[body.index(after: idx)...]).trimmingCharacters(in: .whitespaces)
            } else if let idx = body.firstIndex(of: "：") {
                body = String(body[body.index(after: idx)...]).trimmingCharacters(in: .whitespaces)
            }
            let cleaned = cleanTranslation(body)
            if looksLikeJapanese(cleaned) { return cleaned }
        }
        return nil
    }

    private static func valueAfterLabel(in line: String, label: String) -> String? {
        guard let range = line.range(of: label) else { return nil }
        return String(line[range.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func cleanTranslation(_ text: String) -> String {
        var value = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if value.hasPrefix("**"), let end = value.range(of: "**", range: value.index(value.startIndex, offsetBy: 2)..<value.endIndex) {
            // unlikely for JA translation
            _ = end
        }
        // Drop leading list markers leftovers
        while value.hasPrefix("-") {
            value = String(value.dropFirst()).trimmingCharacters(in: .whitespaces)
        }
        return value
    }

    private static func looksLikeJapanese(_ text: String) -> Bool {
        text.unicodeScalars.contains { scalar in
            (0x3040...0x30FF).contains(scalar.value) // hiragana/katakana
                || (0x4E00...0x9FFF).contains(scalar.value) // CJK
        }
    }
}

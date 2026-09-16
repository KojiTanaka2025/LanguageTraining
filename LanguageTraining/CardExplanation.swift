import Foundation

/// Structured explanation stored alongside (and preferred over) freeform markdown.
struct CardExplanation: Hashable, Codable, Sendable {
    var translation: TranslationSection
    var pronunciation: PronunciationSection
    var structure: StructureSection
    var grammar: GrammarSection
    var vocabulary: [VocabularyItem]
    var examples: [ExampleItem]
    var notes: NotesSection
    var summary: [String]
    /// Optional cost footer markdown line (italic), kept out of the main sections.
    var costFooter: String?

    struct TranslationSection: Hashable, Codable, Sendable {
        var japanese: String
        var naturalEnglish: String
        var usage: String
        var formality: String
    }

    struct PronunciationSection: Hashable, Codable, Sendable {
        var stress: String
        var tips: String
    }

    struct StructureSection: Hashable, Codable, Sendable {
        var kind: String
        var parts: String
        var pattern: String
    }

    struct GrammarSection: Hashable, Codable, Sendable {
        var tense: String
        var articles: String
        var prepositions: String
        var other: String
        var why: String
    }

    struct VocabularyItem: Hashable, Codable, Sendable {
        var english: String
        var gloss: String
        var collocations: String
    }

    struct ExampleItem: Hashable, Codable, Sendable {
        var sentence: String
        var meaning: String
    }

    struct NotesSection: Hashable, Codable, Sendable {
        var similar: String
        var mistakes: String
    }

    static let empty = CardExplanation(
        translation: .init(japanese: "", naturalEnglish: "", usage: "", formality: ""),
        pronunciation: .init(stress: "", tips: ""),
        structure: .init(kind: "", parts: "", pattern: ""),
        grammar: .init(tense: "", articles: "", prepositions: "", other: "", why: ""),
        vocabulary: [],
        examples: [],
        notes: .init(similar: "", mistakes: ""),
        summary: [],
        costFooter: nil
    )

    var japaneseTranslation: String {
        translation.japanese.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Build display markdown. Section 1 is titled 日本語訳 (not 意味).
    func asMarkdown(includeCostFooter: Bool = true) -> String {
        var lines: [String] = []

        lines.append("## 1. 日本語訳")
        lines.append("- 自然な日本語訳: \(translation.japanese)")
        lines.append("- 自然な英語（学習用）: \(translation.naturalEnglish)")
        lines.append("- どんなときに使う: \(translation.usage)")
        lines.append("- カジュアル / フォーマル: \(translation.formality)")
        lines.append("")

        lines.append("## 2. 発音")
        lines.append("- 強く読む音: \(pronunciation.stress)")
        lines.append("- 発音のコツ: \(pronunciation.tips)")
        lines.append("")

        lines.append("## 3. 構造")
        lines.append("- 種類: \(structure.kind)")
        lines.append("- パーツごと: \(structure.parts)")
        lines.append("- 同じ型で言えるパターン: \(structure.pattern)")
        lines.append("")

        lines.append("## 4. 文法")
        lines.append("- 時制・形: \(grammar.tense)")
        lines.append("- 冠詞: \(grammar.articles)")
        lines.append("- 前置詞: \(grammar.prepositions)")
        lines.append("- この文に出るほかの文法: \(grammar.other)")
        lines.append("- なぜこの形なのか: \(grammar.why)")
        lines.append("")

        lines.append("## 5. 語彙")
        if vocabulary.isEmpty {
            lines.append("- （なし）")
        } else {
            for item in vocabulary {
                var entry = "**\(item.english)** = \(item.gloss)"
                let colo = item.collocations.trimmingCharacters(in: .whitespacesAndNewlines)
                if !colo.isEmpty {
                    entry += " / \(colo)"
                }
                lines.append("- \(entry)")
            }
        }
        lines.append("")

        lines.append("## 6. 例文")
        if examples.isEmpty {
            lines.append("- （なし）")
        } else {
            for (index, example) in examples.enumerated() {
                lines.append("- 例文\(index + 1): \(example.sentence)")
                lines.append("- 意味: \(example.meaning)")
            }
        }
        lines.append("")

        lines.append("## 7. 注意点")
        lines.append("- 似た表現との違い: \(notes.similar)")
        lines.append("- やりがちなミス: \(notes.mistakes)")
        lines.append("")

        lines.append("## 8. 要点")
        if summary.isEmpty {
            lines.append("- （なし）")
        } else {
            for point in summary {
                lines.append("- \(point)")
            }
        }

        var body = lines.joined(separator: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if includeCostFooter,
           let footer = costFooter?.trimmingCharacters(in: .whitespacesAndNewlines),
           !footer.isEmpty {
            body += "\n\n---\n\n" + footer
        }
        return body
    }

    /// Best-effort parse of legacy markdown cards into structure.
    static func parse(fromMarkdown markdown: String) -> CardExplanation? {
        let sections = splitSections(markdown)
        guard !sections.isEmpty else { return nil }

        var result = CardExplanation.empty
        for (title, body) in sections {
            let normalized = title
                .replacingOccurrences(of: #"^\d+\.\s*"#, with: "", options: .regularExpression)
                .trimmingCharacters(in: .whitespacesAndNewlines)

            switch normalized {
            case "日本語訳", "意味":
                let fields = fieldMap(from: body)
                result.translation.japanese = firstValue(in: fields, keys: ["自然な日本語訳", "日本語訳", "意味"])
                result.translation.naturalEnglish = firstValue(in: fields, keys: ["自然な英語（学習用）", "自然な英語"])
                result.translation.usage = firstValue(in: fields, keys: ["どんなときに使う"])
                result.translation.formality = firstValue(in: fields, keys: ["カジュアル / フォーマル", "カジュアル/フォーマル"])
            case "発音":
                let fields = fieldMap(from: body)
                result.pronunciation.stress = firstValue(in: fields, keys: ["強く読む音"])
                result.pronunciation.tips = firstValue(in: fields, keys: ["発音のコツ"])
            case "構造":
                let fields = fieldMap(from: body)
                result.structure.kind = firstValue(in: fields, keys: ["種類"])
                result.structure.parts = firstValue(in: fields, keys: ["パーツごと", "パーツごと（英語の原文を切る。各パーツは「英語 = 日本語」。訳文は切らない）"])
                result.structure.pattern = firstValue(in: fields, keys: ["同じ型で言えるパターン", "同じ型で言えるパターン（英語の型 + 短い日本語。日本語の文型にしない）"])
            case "文法":
                let fields = fieldMap(from: body)
                result.grammar.tense = firstValue(in: fields, keys: ["時制・形", "時制・形（いま / 過去 / 進行など）"])
                result.grammar.articles = firstValue(in: fields, keys: ["冠詞", "冠詞（a / an / the / なし）"])
                result.grammar.prepositions = firstValue(in: fields, keys: ["前置詞"])
                result.grammar.other = firstValue(in: fields, keys: ["この文に出るほかの文法", "この文に出るほかの文法（可算・不可算、動詞の形、助動詞、関係詞など）"])
                result.grammar.why = firstValue(in: fields, keys: ["なぜこの形なのか", "なぜこの形なのか（原文の語を使って、似た形との違いも）"])
            case "語彙":
                result.vocabulary = parseVocabulary(body)
            case "例文":
                result.examples = parseExamples(body)
            case "注意点":
                let fields = fieldMap(from: body)
                result.notes.similar = firstValue(in: fields, keys: ["似た表現との違い"])
                result.notes.mistakes = firstValue(in: fields, keys: ["やりがちなミス"])
            case "要点":
                result.summary = bulletValues(from: body)
            default:
                break
            }
        }

        if let footer = extractCostFooter(from: markdown) {
            result.costFooter = footer
        }

        // Require at least a Japanese translation to treat as successfully parsed.
        guard !result.japaneseTranslation.isEmpty else { return nil }
        return result
    }

    // MARK: - Parsing helpers

    private static func splitSections(_ markdown: String) -> [(String, String)] {
        var sections: [(String, String)] = []
        var currentTitle: String?
        var currentBody: [String] = []

        func flush() {
            guard let title = currentTitle else { return }
            sections.append((title, currentBody.joined(separator: "\n")))
        }

        for raw in markdown.components(separatedBy: .newlines) {
            let trimmed = raw.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("## ") {
                flush()
                currentTitle = String(trimmed.dropFirst(3))
                currentBody = []
            } else if trimmed == "---" || trimmed == "***" {
                flush()
                currentTitle = nil
                currentBody = []
            } else if currentTitle != nil {
                currentBody.append(raw)
            }
        }
        flush()
        return sections
    }

    private static func fieldMap(from body: String) -> [String: String] {
        var map: [String: String] = [:]
        for raw in body.components(separatedBy: .newlines) {
            let trimmed = raw.trimmingCharacters(in: .whitespaces)
            guard trimmed.hasPrefix("-") else { continue }
            var line = String(trimmed.dropFirst()).trimmingCharacters(in: .whitespaces)
            let colon = line.firstIndex(of: ":") ?? line.firstIndex(of: "：")
            guard let colon else { continue }
            let key = String(line[..<colon]).trimmingCharacters(in: .whitespaces)
            let value = String(line[line.index(after: colon)...]).trimmingCharacters(in: .whitespaces)
            if !key.isEmpty {
                map[key] = value
            }
        }
        return map
    }

    private static func firstValue(in map: [String: String], keys: [String]) -> String {
        for key in keys {
            if let value = map[key], !value.isEmpty { return value }
            // Prefix match for long template labels.
            if let match = map.first(where: { $0.key.hasPrefix(key) })?.value, !match.isEmpty {
                return match
            }
        }
        return ""
    }

    private static func bulletValues(from body: String) -> [String] {
        body.components(separatedBy: .newlines).compactMap { raw in
            let trimmed = raw.trimmingCharacters(in: .whitespaces)
            guard trimmed.hasPrefix("-") else { return nil }
            let value = String(trimmed.dropFirst()).trimmingCharacters(in: .whitespaces)
            return value.isEmpty ? nil : value
        }
    }

    private static func parseVocabulary(_ body: String) -> [VocabularyItem] {
        bulletValues(from: body).compactMap { line in
            // **English** = gloss / collocations
            var english = ""
            var rest = line
            if let bold = line.range(of: #"\*\*([^*]+)\*\*"#, options: .regularExpression) {
                english = String(line[bold])
                    .replacingOccurrences(of: "**", with: "")
                rest = String(line[bold.upperBound...]).trimmingCharacters(in: .whitespaces)
                if rest.hasPrefix("=") {
                    rest = String(rest.dropFirst()).trimmingCharacters(in: .whitespaces)
                }
            } else if let eq = line.firstIndex(of: "=") {
                english = String(line[..<eq]).trimmingCharacters(in: CharacterSet.whitespaces.union(CharacterSet(charactersIn: "*")))
                rest = String(line[line.index(after: eq)...]).trimmingCharacters(in: .whitespaces)
            } else {
                return nil
            }
            let parts = rest.split(separator: "/", maxSplits: 1).map {
                $0.trimmingCharacters(in: .whitespaces)
            }
            let gloss = parts.first ?? ""
            let colo = parts.count > 1 ? parts[1] : ""
            guard !english.isEmpty else { return nil }
            return VocabularyItem(english: english, gloss: gloss, collocations: colo)
        }
    }

    private static func parseExamples(_ body: String) -> [ExampleItem] {
        let fields = fieldMap(from: body)
        var examples: [ExampleItem] = []
        for index in 1...5 {
            let sentence = firstValue(in: fields, keys: ["例文\(index)", "例文 \(index)"])
            guard !sentence.isEmpty else { continue }
            // Meaning may be the next "意味" — fieldMap overwrites duplicate keys; fall back to empty.
            let meaning = fields["意味"] ?? ""
            examples.append(ExampleItem(sentence: sentence, meaning: meaning))
        }
        if examples.isEmpty {
            // Pair consecutive bullets: sentence then meaning.
            let bullets = bulletValues(from: body)
            var i = 0
            while i < bullets.count {
                let sentence = bullets[i]
                let meaning = i + 1 < bullets.count ? bullets[i + 1] : ""
                if sentence.hasPrefix("例文") || !sentence.isEmpty {
                    let cleaned = sentence.replacingOccurrences(
                        of: #"^例文\d+\s*[:：]\s*"#,
                        with: "",
                        options: .regularExpression
                    )
                    examples.append(ExampleItem(sentence: cleaned, meaning: meaning.replacingOccurrences(
                        of: #"^意味\s*[:：]\s*"#,
                        with: "",
                        options: .regularExpression
                    )))
                }
                i += 2
            }
        }
        return examples
    }

    private static func extractCostFooter(from markdown: String) -> String? {
        let parts = markdown.components(separatedBy: "\n---\n")
        guard parts.count >= 2 else { return nil }
        let footer = parts.last?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return footer.isEmpty ? nil : footer
    }
}

/// Wire format returned by the model for Japanese explanations.
struct CardExplanationDTO: Codable, Sendable {
    var translation: CardExplanation.TranslationSection
    var pronunciation: CardExplanation.PronunciationSection
    var structure: CardExplanation.StructureSection
    var grammar: CardExplanation.GrammarSection
    var vocabulary: [CardExplanation.VocabularyItem]
    var examples: [CardExplanation.ExampleItem]
    var notes: CardExplanation.NotesSection
    var summary: [String]

    func makeExplanation() -> CardExplanation {
        CardExplanation(
            translation: translation,
            pronunciation: pronunciation,
            structure: structure,
            grammar: grammar,
            vocabulary: vocabulary,
            examples: examples,
            notes: notes,
            summary: summary,
            costFooter: nil
        )
    }
}

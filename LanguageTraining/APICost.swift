import Foundation

enum APICost {
    struct ChatUsage: Sendable {
        var promptTokens: Int
        var completionTokens: Int
        var cachedPromptTokens: Int
    }

    /// Approximate OpenAI list prices in USD per 1 million tokens.
    private struct Rate {
        var input: Double
        var cachedInput: Double
        var output: Double
    }

    static func estimateTokenCount(_ text: String) -> Int {
        max(1, (text.utf16.count + 3) / 4)
    }

    static func chatUSD(model: String, usage: ChatUsage) -> Double {
        let rate = rate(forChatModel: model)
        let cached = min(max(usage.cachedPromptTokens, 0), max(usage.promptTokens, 0))
        let uncached = max(usage.promptTokens - cached, 0)
        let output = max(usage.completionTokens, 0)
        return (Double(uncached) * rate.input
                + Double(cached) * rate.cachedInput
                + Double(output) * rate.output) / 1_000_000
    }

    /// `gpt-4o-mini-tts` is billed per tokens; the speech endpoint does not return usage.
    static func ttsUSD(
        spokenText: String,
        instructions: String = OpenAIClient.defaultTTSInstructions
    ) -> Double {
        let inputTokens = estimateTokenCount(spokenText + "\n" + instructions)
        // Audio output roughly tracks spoken length. 1 character ≈ 4 audio tokens is a conservative stand-in.
        let audioTokens = max(1, spokenText.utf16.count * 4)
        let inputUSD = Double(inputTokens) * 0.60 / 1_000_000
        let outputUSD = Double(audioTokens) * 12.0 / 1_000_000
        return inputUSD + outputUSD
    }

    static func footer(
        usd: Double,
        explanationLanguage: String,
        includedAudio: Bool
    ) -> String {
        let amount = formatAmount(usd: usd, language: explanationLanguage)
        let scope = scopeLabel(language: explanationLanguage, includedAudio: includedAudio)
        return "*" + line(language: explanationLanguage, amount: amount, scope: scope) + "*"
    }

    static func appendingFooter(
        to markdown: String,
        usd: Double,
        explanationLanguage: String,
        includedAudio: Bool
    ) -> String {
        let body = markdown.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !body.isEmpty else { return footer(usd: usd, explanationLanguage: explanationLanguage, includedAudio: includedAudio) }
        return body + "\n\n---\n\n" + footer(usd: usd, explanationLanguage: explanationLanguage, includedAudio: includedAudio)
    }

    // MARK: - Rates

    private static func rate(forChatModel model: String) -> Rate {
        let normalized = normalizeModelName(model)
        let table: [(prefix: String, Rate)] = [
            ("gpt-5.6-sol", Rate(input: 5.00, cachedInput: 0.50, output: 30.00)),
            ("gpt-5.6-terra", Rate(input: 2.00, cachedInput: 0.20, output: 12.00)),
            ("gpt-5.6-luna", Rate(input: 0.20, cachedInput: 0.02, output: 1.20)),
            ("gpt-5.6-cyber", Rate(input: 12.50, cachedInput: 1.25, output: 75.00)),
            ("gpt-5.5-pro", Rate(input: 30.00, cachedInput: 3.00, output: 180.00)),
            ("gpt-5.5", Rate(input: 5.00, cachedInput: 0.50, output: 30.00)),
            ("gpt-5.4-nano", Rate(input: 0.20, cachedInput: 0.02, output: 1.25)),
            ("gpt-5.4-mini", Rate(input: 0.75, cachedInput: 0.075, output: 4.50)),
            ("gpt-5.4", Rate(input: 2.50, cachedInput: 0.25, output: 15.00)),
            ("gpt-5-mini", Rate(input: 0.25, cachedInput: 0.025, output: 2.00)),
            ("gpt-5-nano", Rate(input: 0.05, cachedInput: 0.005, output: 0.40)),
            ("gpt-5.3-codex", Rate(input: 1.75, cachedInput: 0.175, output: 14.00)),
            ("gpt-5", Rate(input: 1.25, cachedInput: 0.125, output: 10.00)),
            ("gpt-4.1-nano", Rate(input: 0.10, cachedInput: 0.025, output: 0.40)),
            ("gpt-4.1-mini", Rate(input: 0.40, cachedInput: 0.10, output: 1.60)),
            ("gpt-4.1", Rate(input: 2.00, cachedInput: 0.50, output: 8.00)),
            ("gpt-4o-mini", Rate(input: 0.15, cachedInput: 0.075, output: 0.60)),
            ("gpt-4o", Rate(input: 2.50, cachedInput: 1.25, output: 10.00)),
            ("o4-mini", Rate(input: 0.55, cachedInput: 0.138, output: 2.20)),
            ("o3-mini", Rate(input: 1.10, cachedInput: 0.55, output: 4.40)),
            ("o3", Rate(input: 2.00, cachedInput: 0.50, output: 8.00)),
        ]
        return table.first(where: { normalized.hasPrefix($0.prefix) })?.1
            ?? Rate(input: 0.15, cachedInput: 0.075, output: 0.60)
    }

    private static func normalizeModelName(_ model: String) -> String {
        var name = model.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if let range = name.range(of: #"-20\d{2}-\d{2}-\d{2}$"#, options: .regularExpression) {
            name.removeSubrange(range)
        }
        return name
    }

    // MARK: - Currency

    private struct Currency {
        var code: String
        var localeIdentifier: String
        /// Approximate local units per 1 USD, for display only.
        var unitsPerUSD: Double
    }

    private static func currency(for language: String) -> Currency {
        switch language {
        case "Japanese":
            return Currency(code: "JPY", localeIdentifier: "ja_JP", unitsPerUSD: 148)
        case "Korean":
            return Currency(code: "KRW", localeIdentifier: "ko_KR", unitsPerUSD: 1390)
        case "Simplified Chinese":
            return Currency(code: "CNY", localeIdentifier: "zh_CN", unitsPerUSD: 7.2)
        case "Traditional Chinese":
            return Currency(code: "TWD", localeIdentifier: "zh_TW", unitsPerUSD: 32.5)
        case "Vietnamese":
            return Currency(code: "VND", localeIdentifier: "vi_VN", unitsPerUSD: 25400)
        case "French":
            return Currency(code: "EUR", localeIdentifier: "fr_FR", unitsPerUSD: 0.92)
        case "Spanish":
            return Currency(code: "EUR", localeIdentifier: "es_ES", unitsPerUSD: 0.92)
        case "German":
            return Currency(code: "EUR", localeIdentifier: "de_DE", unitsPerUSD: 0.92)
        default:
            return Currency(code: "USD", localeIdentifier: "en_US", unitsPerUSD: 1)
        }
    }

    private static func formatAmount(usd: Double, language: String) -> String {
        let currency = currency(for: language)
        let local = max(usd, 0) * currency.unitsPerUSD
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currency.code
        formatter.locale = Locale(identifier: currency.localeIdentifier)
        formatter.usesGroupingSeparator = true
        if local >= 100 {
            formatter.minimumFractionDigits = 0
            formatter.maximumFractionDigits = 0
        } else if local >= 1 {
            formatter.minimumFractionDigits = 2
            formatter.maximumFractionDigits = 2
        } else if local >= 0.01 {
            formatter.minimumFractionDigits = 2
            formatter.maximumFractionDigits = 3
        } else {
            formatter.minimumFractionDigits = 3
            formatter.maximumFractionDigits = 4
        }
        return formatter.string(from: NSNumber(value: local)) ?? "\(currency.code) \(local)"
    }

    private static func scopeLabel(language: String, includedAudio: Bool) -> String {
        switch language {
        case "Japanese":
            return includedAudio ? "説明 + 音声" : "説明"
        case "Korean":
            return includedAudio ? "설명 + 음성" : "설명"
        case "Simplified Chinese":
            return includedAudio ? "讲解 + 语音" : "讲解"
        case "Traditional Chinese":
            return includedAudio ? "講解 + 語音" : "講解"
        case "Vietnamese":
            return includedAudio ? "giải thích + âm thanh" : "giải thích"
        case "French":
            return includedAudio ? "explication + audio" : "explication"
        case "Spanish":
            return includedAudio ? "explicación + audio" : "explicación"
        case "German":
            return includedAudio ? "Erklärung + Audio" : "Erklärung"
        default:
            return includedAudio ? "explanation + audio" : "explanation"
        }
    }

    private static func line(language: String, amount: String, scope: String) -> String {
        switch language {
        case "Japanese":
            return "概算費用: 約 \(amount)（\(scope)）"
        case "Korean":
            return "예상 비용: 약 \(amount) (\(scope))"
        case "Simplified Chinese":
            return "大约费用: 约 \(amount)（\(scope)）"
        case "Traditional Chinese":
            return "大約費用: 約 \(amount)（\(scope)）"
        case "Vietnamese":
            return "Chi phí ước tính: khoảng \(amount) (\(scope))"
        case "French":
            return "Coût estimé : environ \(amount) (\(scope))"
        case "Spanish":
            return "Coste estimado: unos \(amount) (\(scope))"
        case "German":
            return "Geschätzte Kosten: etwa \(amount) (\(scope))"
        default:
            return "Estimated cost: about \(amount) (\(scope))"
        }
    }
}

struct ExplanationResult: Sendable {
    let markdown: String
    let explanation: CardExplanation?
    let usage: APICost.ChatUsage

    init(markdown: String, explanation: CardExplanation? = nil, usage: APICost.ChatUsage) {
        self.explanation = explanation ?? CardExplanation.parse(fromMarkdown: markdown)
        if let structured = self.explanation {
            self.markdown = structured.asMarkdown()
        } else {
            self.markdown = markdown
        }
        self.usage = usage
    }
}

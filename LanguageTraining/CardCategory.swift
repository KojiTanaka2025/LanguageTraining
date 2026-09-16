import Foundation

enum CardCategory {
    /// Built-in categories shown to every user.
    static let presets: [String] = [
        "仕事用",
        "日常会話",
    ]

    static let uncategorizedID = ""
    static let uncategorizedLabel = "未分類"
    static let allFilterID = "__all__"
    static let allFilterLabel = "すべて"

    static func displayName(_ category: String) -> String {
        let trimmed = category.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? uncategorizedLabel : trimmed
    }

    static func normalized(_ category: String?) -> String {
        category?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

    /// Presets + custom names + categories already used on cards, de-duplicated.
    static func availableNames(custom: [String], usedOnCards: [String] = []) -> [String] {
        var seen = Set<String>()
        var result: [String] = []
        for name in presets + custom + usedOnCards {
            let trimmed = normalized(name)
            guard !trimmed.isEmpty, !seen.contains(trimmed) else { continue }
            seen.insert(trimmed)
            result.append(trimmed)
        }
        return result
    }
}

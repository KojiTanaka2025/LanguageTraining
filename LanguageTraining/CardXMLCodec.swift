import Foundation

enum CardXMLError: LocalizedError {
    case invalidRoot
    case missingCardsElement
    case unreadableCards

    var errorDescription: String? {
        switch self {
        case .invalidRoot:
            return "The card data file is not a valid LanguageTraining library."
        case .missingCardsElement:
            return "The card data file is missing the cards list."
        case .unreadableCards:
            return "The card data file could not be read. The cards may be damaged."
        }
    }
}

struct LibraryDocument: Sendable {
    var tags: [LibraryTag]
    var cards: [Card]
    var studyProgress: [StudyProgress]
    var studyDailyLog: [StudyDayRecord]

    static func seeded(
        cards: [Card],
        tags: [LibraryTag] = [],
        studyProgress: [StudyProgress] = [],
        studyDailyLog: [StudyDayRecord] = [],
        extraNames: [String] = []
    ) -> LibraryDocument {
        let catalog = tags.isEmpty ? LibraryTag.builtInDefaults : tags
        let used = cards.map(\.category) + extraNames
        let knownIDs = Set(cards.map(\.id))
        return LibraryDocument(
            tags: LibraryTag.mergedCatalog(existing: catalog, usedNames: used),
            cards: cards,
            studyProgress: studyProgress.filter { knownIDs.contains($0.cardID) },
            studyDailyLog: studyDailyLog
        )
    }
}

enum CardXMLCodec {
    static let rootName = "englishCard"
    static let version = "1"

    static func encode(
        tags: [LibraryTag],
        cards: [Card],
        studyProgress: [StudyProgress] = [],
        studyDailyLog: [StudyDayRecord] = []
    ) throws -> Data {
        try encode(LibraryDocument(
            tags: tags,
            cards: cards,
            studyProgress: studyProgress,
            studyDailyLog: studyDailyLog
        ))
    }

    static func encode(_ document: LibraryDocument) throws -> Data {
        var xml = """
        <?xml version="1.0" encoding="utf-8"?>
        <EnglishCardData version="\(version)">
          <tags>

        """

        for tag in document.tags {
            let name = LibraryTag.normalizedName(tag.name)
            guard !name.isEmpty else { continue }
            xml += "    <tag id=\"\(escapeAttribute(tag.id.uuidString))\" name=\"\(escapeAttribute(name))\" color=\"\(escapeAttribute(LibraryTag.normalizedColor(tag.colorHex)))\"/>\n"
        }

        xml += """
          </tags>
          <cards>

        """

        for card in document.cards {
            xml += "    <card id=\"\(escapeAttribute(card.id.uuidString))\" createdAt=\"\(iso8601Fractional.string(from: card.createdAt))\""
            if let audioFileName = Card.sanitizedAudioFileName(card.audioFileName) {
                xml += " audioFileName=\"\(escapeAttribute(audioFileName))\""
            }
            let category = LibraryTag.normalizedName(card.category)
            if !category.isEmpty {
                xml += " category=\"\(escapeAttribute(category))\""
            }
            xml += ">\n"
            xml += "      <sourceText>\(escapeText(card.sourceText))</sourceText>\n"
            xml += "      <markdown>\(escapeText(card.markdown))</markdown>\n"
            if let explanation = card.explanation,
               let data = try? JSONEncoder().encode(explanation),
               let json = String(data: data, encoding: .utf8) {
                xml += "      <explanationJson>\(escapeText(json))</explanationJson>\n"
            }
            xml += "    </card>\n"
        }

        xml += """
          </cards>
          <study>

        """

        for item in document.studyProgress {
            xml += "    <progress cardId=\"\(escapeAttribute(item.cardID.uuidString))\""
            xml += " easeFactor=\"\(item.easeFactor)\""
            xml += " intervalDays=\"\(item.intervalDays)\""
            xml += " repetitions=\"\(item.repetitions)\""
            xml += " nextReviewAt=\"\(escapeAttribute(iso8601Fractional.string(from: item.nextReviewAt)))\""
            if let last = item.lastReviewedAt {
                xml += " lastReviewedAt=\"\(escapeAttribute(iso8601Fractional.string(from: last)))\""
            }
            xml += " reviewCount=\"\(item.reviewCount)\""
            xml += " correctCount=\"\(item.correctCount)\""
            xml += " incorrectCount=\"\(item.incorrectCount)\""
            xml += "/>\n"
        }

        for day in document.studyDailyLog.sorted(by: { $0.day < $1.day }) {
            xml += "    <day date=\"\(escapeAttribute(day.dayKey))\" reviews=\"\(day.reviews)\" correct=\"\(day.correct)\"/>\n"
        }

        xml += """
          </study>
        </EnglishCardData>
        """

        guard let data = xml.data(using: .utf8) else {
            throw CardXMLError.unreadableCards
        }
        return data
    }

    static func decode(data: Data) throws -> LibraryDocument {
        let parser = XMLParser(data: data)
        let delegate = LibraryXMLParserDelegate()
        parser.delegate = delegate
        parser.shouldProcessNamespaces = false
        guard parser.parse() else {
            if let error = delegate.parseError {
                throw error
            }
            throw CardXMLError.invalidRoot
        }
        if let error = delegate.parseError {
            throw error
        }
        guard delegate.sawRoot else {
            throw CardXMLError.invalidRoot
        }
        guard delegate.sawCards else {
            throw CardXMLError.missingCardsElement
        }
        if delegate.cards.isEmpty && delegate.cardNodeCount > 0 {
            throw CardXMLError.unreadableCards
        }

        let cards = delegate.cards.sorted { $0.createdAt > $1.createdAt }
        return LibraryDocument.seeded(
            cards: cards,
            tags: delegate.tags,
            studyProgress: delegate.studyProgress,
            studyDailyLog: delegate.studyDailyLog
        )
    }

    /// Convenience for callers that only need the card list.
    static func decodeCards(data: Data) throws -> [Card] {
        try decode(data: data).cards
    }

    fileprivate static func parseDate(_ string: String) -> Date? {
        if let date = iso8601Fractional.date(from: string) {
            return date
        }
        return iso8601.date(from: string)
    }

    private static func escapeText(_ string: String) -> String {
        string
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
    }

    private static func escapeAttribute(_ string: String) -> String {
        escapeText(string)
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&apos;")
    }

    private static let iso8601Fractional: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    private static let iso8601: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()
}

private final class LibraryXMLParserDelegate: NSObject, XMLParserDelegate {
    var tags: [LibraryTag] = []
    var cards: [Card] = []
    var studyProgress: [StudyProgress] = []
    var studyDailyLog: [StudyDayRecord] = []
    var sawRoot = false
    var sawCards = false
    var cardNodeCount = 0
    var parseError: Error?

    private var currentID: UUID?
    private var currentCreatedAt: Date?
    private var currentAudioFileName: String?
    private var currentCategory = ""
    private var currentSourceText = ""
    private var currentMarkdown = ""
    private var currentExplanationJSON = ""
    private var currentElement: String?
    private var textBuffer = ""

    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String: String] = [:]) {
        if elementName == "EnglishCardData" {
            sawRoot = true
            return
        }
        if elementName == "cards" {
            sawCards = true
            return
        }
        if elementName == "tag" {
            let name = LibraryTag.normalizedName(attributeDict["name"])
            guard !name.isEmpty else { return }
            let id = UUID(uuidString: attributeDict["id"] ?? "") ?? UUID()
            let color = LibraryTag.normalizedColor(attributeDict["color"])
            tags.append(LibraryTag(id: id, name: name, colorHex: color))
            return
        }
        if elementName == "progress" {
            guard let id = UUID(uuidString: attributeDict["cardId"] ?? "") else { return }
            let ease = Double(attributeDict["easeFactor"] ?? "") ?? StudyProgress.defaultEase
            let interval = Double(attributeDict["intervalDays"] ?? "") ?? 0
            let repetitions = Int(attributeDict["repetitions"] ?? "") ?? 0
            let nextReview = CardXMLCodec.parseDate(attributeDict["nextReviewAt"] ?? "") ?? Date()
            let lastReviewed = CardXMLCodec.parseDate(attributeDict["lastReviewedAt"] ?? "")
            let reviewCount = Int(attributeDict["reviewCount"] ?? "") ?? 0
            let correctCount = Int(attributeDict["correctCount"] ?? "") ?? 0
            let incorrectCount = Int(attributeDict["incorrectCount"] ?? "") ?? 0
            studyProgress.append(
                StudyProgress(
                    cardID: id,
                    easeFactor: max(StudyProgress.minimumEase, ease),
                    intervalDays: max(0, interval),
                    repetitions: max(0, repetitions),
                    nextReviewAt: nextReview,
                    lastReviewedAt: lastReviewed,
                    reviewCount: max(0, reviewCount),
                    correctCount: max(0, correctCount),
                    incorrectCount: max(0, incorrectCount)
                )
            )
            return
        }
        if elementName == "day" {
            guard let day = StudyDayRecord.parseDayKey(attributeDict["date"] ?? "") else { return }
            let reviews = Int(attributeDict["reviews"] ?? "") ?? 0
            let correct = Int(attributeDict["correct"] ?? "") ?? 0
            studyDailyLog.append(StudyDayRecord(day: day, reviews: max(0, reviews), correct: max(0, correct)))
            return
        }
        if elementName == "card" {
            cardNodeCount += 1
            currentID = UUID(uuidString: attributeDict["id"] ?? "")
            currentCreatedAt = CardXMLCodec.parseDate(attributeDict["createdAt"] ?? "")
            currentAudioFileName = attributeDict["audioFileName"]
            currentCategory = LibraryTag.normalizedName(attributeDict["category"])
            currentSourceText = ""
            currentMarkdown = ""
            currentExplanationJSON = ""
        }
        currentElement = elementName
        textBuffer = ""
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        textBuffer += string
    }

    func parser(_ parser: XMLParser, foundCDATA CDATABlock: Data) {
        if let string = String(data: CDATABlock, encoding: .utf8) {
            textBuffer += string
        }
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        if elementName == "sourceText" {
            currentSourceText = textBuffer
        } else if elementName == "markdown" {
            currentMarkdown = textBuffer
        } else if elementName == "explanationJson" {
            currentExplanationJSON = textBuffer
        } else if elementName == "card" {
            if let id = currentID, let createdAt = currentCreatedAt {
                var structured: CardExplanation?
                if let data = currentExplanationJSON.data(using: .utf8) {
                    structured = try? JSONDecoder().decode(CardExplanation.self, from: data)
                }
                cards.append(Card(
                    id: id,
                    createdAt: createdAt,
                    sourceText: currentSourceText,
                    markdown: currentMarkdown,
                    explanation: structured,
                    audioFileName: Card.sanitizedAudioFileName(currentAudioFileName),
                    category: currentCategory
                ))
            }
            currentID = nil
            currentCreatedAt = nil
            currentAudioFileName = nil
            currentCategory = ""
            currentExplanationJSON = ""
        }
        currentElement = nil
        textBuffer = ""
    }

    func parser(_ parser: XMLParser, parseErrorOccurred parseError: Error) {
        self.parseError = parseError
    }
}

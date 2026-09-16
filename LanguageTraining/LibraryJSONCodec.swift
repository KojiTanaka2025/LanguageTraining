import Foundation

enum LibraryFile {
    static let jsonName = "cards.json"
    static let xmlName = "cards.xml"
    static let xmlMigratedName = "cards.xml.migrated"

    static func jsonURL(in directory: URL) -> URL {
        directory.appendingPathComponent(jsonName, isDirectory: false)
    }

    static func xmlURL(in directory: URL) -> URL {
        directory.appendingPathComponent(xmlName, isDirectory: false)
    }

    static func hasLibraryData(in directory: URL) -> Bool {
        let fm = FileManager.default
        return fm.fileExists(atPath: jsonURL(in: directory).path)
            || fm.fileExists(atPath: xmlURL(in: directory).path)
    }
}

enum LibraryJSONError: LocalizedError {
    case unreadable
    case invalidVersion

    var errorDescription: String? {
        switch self {
        case .unreadable:
            return "The card data file could not be read. The cards may be damaged."
        case .invalidVersion:
            return "The card data file version is not supported."
        }
    }
}

enum LibraryJSONCodec {
    static let version = "1"

    static func encode(_ document: LibraryDocument) throws -> Data {
        let payload = JSONDocument(document: document)
        do {
            return try encoder.encode(payload)
        } catch {
            throw LibraryJSONError.unreadable
        }
    }

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

    static func decode(data: Data) throws -> LibraryDocument {
        let payload: JSONDocument
        do {
            payload = try decoder.decode(JSONDocument.self, from: data)
        } catch {
            throw LibraryJSONError.unreadable
        }
        guard payload.version == version else {
            // Accept only the current schema for now.
            throw LibraryJSONError.invalidVersion
        }
        return payload.makeLibraryDocument()
    }

    static func decodeCards(data: Data) throws -> [Card] {
        try decode(data: data).cards
    }

    /// Load JSON if present; otherwise migrate `cards.xml` → `cards.json`.
    static func loadDocument(fromDirectory directory: URL) throws -> (document: LibraryDocument, persistedData: Data?, migratedFromXML: Bool) {
        let jsonURL = LibraryFile.jsonURL(in: directory)
        let xmlURL = LibraryFile.xmlURL(in: directory)
        let fm = FileManager.default

        if fm.fileExists(atPath: jsonURL.path) {
            let data = try CoordinatedFile.readData(at: jsonURL)
            return (try decode(data: data), data, false)
        }

        if fm.fileExists(atPath: xmlURL.path) {
            let xmlData = try CoordinatedFile.readData(at: xmlURL)
            let document = try CardXMLCodec.decode(data: xmlData)
            let jsonData = try encode(document)
            try CoordinatedFile.writeData(jsonData, to: jsonURL)
            let migratedURL = directory.appendingPathComponent(LibraryFile.xmlMigratedName, isDirectory: false)
            if FileManager.default.fileExists(atPath: migratedURL.path) {
                try? CoordinatedFile.removeItem(at: migratedURL)
            }
            do {
                try FileManager.default.moveItem(at: xmlURL, to: migratedURL)
            } catch {
                try? CoordinatedFile.copyItem(at: xmlURL, to: migratedURL)
                try? CoordinatedFile.removeItem(at: xmlURL)
            }
            return (document, jsonData, true)
        }

        return (
            LibraryDocument(tags: LibraryTag.builtInDefaults, cards: [], studyProgress: [], studyDailyLog: []),
            nil,
            false
        )
    }

    /// Decode a library payload that may be JSON or legacy XML.
    static func decodeFlexible(data: Data) throws -> LibraryDocument {
        if let document = try? decode(data: data) {
            return document
        }
        return try CardXMLCodec.decode(data: data)
    }

    static func decodeCardsFlexible(data: Data) throws -> [Card] {
        try decodeFlexible(data: data).cards
    }

    private static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .custom { date, enc in
            var container = enc.singleValueContainer()
            try container.encode(iso8601Fractional.string(from: date))
        }
        return encoder
    }()

    private static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { dec in
            let container = try dec.singleValueContainer()
            let string = try container.decode(String.self)
            if let date = iso8601Fractional.date(from: string) {
                return date
            }
            if let date = iso8601.date(from: string) {
                return date
            }
            throw LibraryJSONError.unreadable
        }
        return decoder
    }()

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

private struct JSONDocument: Codable {
    var version: String
    var tags: [TagJSON]
    var cards: [CardJSON]
    var study: StudyJSON

    init(document: LibraryDocument) {
        version = LibraryJSONCodec.version
        tags = document.tags.map(TagJSON.init)
        cards = document.cards.map(CardJSON.init)
        study = StudyJSON(
            progress: document.studyProgress.map(ProgressJSON.init),
            days: document.studyDailyLog.map(DayJSON.init)
        )
    }

    func makeLibraryDocument() -> LibraryDocument {
        let tags = tags.compactMap(\.libraryTag)
        let cards = cards.compactMap(\.card)
        let progress = study.progress.compactMap(\.studyProgress)
        let days = study.days.compactMap(\.dayRecord)
        return LibraryDocument.seeded(
            cards: cards,
            tags: tags,
            studyProgress: progress,
            studyDailyLog: days
        )
    }
}

private struct TagJSON: Codable {
    var id: String
    var name: String
    var color: String

    init(_ tag: LibraryTag) {
        id = tag.id.uuidString
        name = tag.name
        color = tag.colorHex
    }

    var libraryTag: LibraryTag? {
        let trimmed = LibraryTag.normalizedName(name)
        guard !trimmed.isEmpty else { return nil }
        return LibraryTag(
            id: UUID(uuidString: id) ?? UUID(),
            name: trimmed,
            colorHex: color
        )
    }
}

private struct CardJSON: Codable {
    var id: String
    var createdAt: Date
    var sourceText: String
    var markdown: String
    var audioFileName: String?
    var category: String?

    init(_ card: Card) {
        id = card.id.uuidString
        createdAt = card.createdAt
        sourceText = card.sourceText
        markdown = card.markdown
        audioFileName = card.audioFileName
        let category = LibraryTag.normalizedName(card.category)
        self.category = category.isEmpty ? nil : category
    }

    var card: Card? {
        guard let id = UUID(uuidString: id) else { return nil }
        return Card(
            id: id,
            createdAt: createdAt,
            sourceText: sourceText,
            markdown: markdown,
            audioFileName: audioFileName,
            category: category ?? ""
        )
    }
}

private struct StudyJSON: Codable {
    var progress: [ProgressJSON]
    var days: [DayJSON]
}

private struct ProgressJSON: Codable {
    var cardId: String
    var easeFactor: Double
    var intervalDays: Double
    var repetitions: Int
    var nextReviewAt: Date
    var lastReviewedAt: Date?
    var reviewCount: Int
    var correctCount: Int
    var incorrectCount: Int

    init(_ progress: StudyProgress) {
        cardId = progress.cardID.uuidString
        easeFactor = progress.easeFactor
        intervalDays = progress.intervalDays
        repetitions = progress.repetitions
        nextReviewAt = progress.nextReviewAt
        lastReviewedAt = progress.lastReviewedAt
        reviewCount = progress.reviewCount
        correctCount = progress.correctCount
        incorrectCount = progress.incorrectCount
    }

    var studyProgress: StudyProgress? {
        guard let id = UUID(uuidString: cardId) else { return nil }
        return StudyProgress(
            cardID: id,
            easeFactor: max(StudyProgress.minimumEase, easeFactor),
            intervalDays: max(0, intervalDays),
            repetitions: max(0, repetitions),
            nextReviewAt: nextReviewAt,
            lastReviewedAt: lastReviewedAt,
            reviewCount: max(0, reviewCount),
            correctCount: max(0, correctCount),
            incorrectCount: max(0, incorrectCount)
        )
    }
}

private struct DayJSON: Codable {
    var date: String
    var reviews: Int
    var correct: Int

    init(_ record: StudyDayRecord) {
        date = record.dayKey
        reviews = record.reviews
        correct = record.correct
    }

    var dayRecord: StudyDayRecord? {
        guard let day = StudyDayRecord.parseDayKey(date) else { return nil }
        return StudyDayRecord(day: day, reviews: max(0, reviews), correct: max(0, correct))
    }
}

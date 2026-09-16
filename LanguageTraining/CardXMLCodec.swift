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

enum CardXMLCodec {
    static let rootName = "englishCard"
    static let version = "1"

    static func encode(cards: [Card]) throws -> Data {
        var xml = """
        <?xml version="1.0" encoding="utf-8"?>
        <EnglishCardData version="\(version)">
          <cards>

        """

        for card in cards {
            xml += "    <card id=\"\(escapeAttribute(card.id.uuidString))\" createdAt=\"\(iso8601Fractional.string(from: card.createdAt))\""
            if let audioFileName = Card.sanitizedAudioFileName(card.audioFileName) {
                xml += " audioFileName=\"\(escapeAttribute(audioFileName))\""
            }
            let category = CardCategory.normalized(card.category)
            if !category.isEmpty {
                xml += " category=\"\(escapeAttribute(category))\""
            }
            xml += ">\n"
            xml += "      <sourceText>\(escapeText(card.sourceText))</sourceText>\n"
            xml += "      <markdown>\(escapeText(card.markdown))</markdown>\n"
            xml += "    </card>\n"
        }

        xml += """
          </cards>
        </EnglishCardData>
        """

        guard let data = xml.data(using: .utf8) else {
            throw CardXMLError.unreadableCards
        }
        return data
    }

    static func decode(data: Data) throws -> [Card] {
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

        return delegate.cards.sorted { $0.createdAt > $1.createdAt }
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
    var cards: [Card] = []
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
        if elementName == "card" {
            cardNodeCount += 1
            currentID = UUID(uuidString: attributeDict["id"] ?? "")
            currentCreatedAt = CardXMLCodec.parseDate(attributeDict["createdAt"] ?? "")
            currentAudioFileName = attributeDict["audioFileName"]
            currentCategory = CardCategory.normalized(attributeDict["category"])
            currentSourceText = ""
            currentMarkdown = ""
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
        } else if elementName == "card" {
            if let id = currentID, let createdAt = currentCreatedAt {
                cards.append(Card(
                    id: id,
                    createdAt: createdAt,
                    sourceText: currentSourceText,
                    markdown: currentMarkdown,
                    audioFileName: Card.sanitizedAudioFileName(currentAudioFileName),
                    category: currentCategory
                ))
            }
            currentID = nil
            currentCreatedAt = nil
            currentAudioFileName = nil
            currentCategory = ""
        }
        currentElement = nil
        textBuffer = ""
    }

    func parser(_ parser: XMLParser, parseErrorOccurred parseError: Error) {
        self.parseError = parseError
    }
}

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
        let doc = XMLDocument(rootElement: XMLElement(name: "EnglishCardData"))
        doc.characterEncoding = "utf-8"
        doc.version = "1.0"

        let root = doc.rootElement()!
        if let versionAttr = XMLNode.attribute(withName: "version", stringValue: version) as? XMLNode {
            root.addAttribute(versionAttr)
        }

        let cardsElement = XMLElement(name: "cards")
        root.addChild(cardsElement)

        for card in cards {
            let cardElement = XMLElement(name: "card")
            if let idAttr = XMLNode.attribute(withName: "id", stringValue: card.id.uuidString) as? XMLNode {
                cardElement.addAttribute(idAttr)
            }
            if let createdAtAttr = XMLNode.attribute(withName: "createdAt", stringValue: iso8601Fractional.string(from: card.createdAt)) as? XMLNode {
                cardElement.addAttribute(createdAtAttr)
            }
            
            if let audioFileName = Card.sanitizedAudioFileName(card.audioFileName),
               let audioAttr = XMLNode.attribute(withName: "audioFileName", stringValue: audioFileName) as? XMLNode {
                cardElement.addAttribute(audioAttr)
            }

            let source = XMLElement(name: "sourceText", stringValue: card.sourceText)
            let markdown = XMLElement(name: "markdown")
            markdown.setStringValue(card.markdown, resolvingEntities: false)

            cardElement.addChild(source)
            cardElement.addChild(markdown)
            cardsElement.addChild(cardElement)
        }

        return doc.xmlData(options: [.nodePrettyPrint])
    }

    static func decode(data: Data) throws -> [Card] {
        let doc = try XMLDocument(data: data, options: [.nodePreserveAll])
        guard let root = doc.rootElement(), root.name == "EnglishCardData" else {
            throw CardXMLError.invalidRoot
        }

        guard let cardsElement = root.elements(forName: "cards").first else {
            throw CardXMLError.missingCardsElement
        }

        let nodes = cardsElement.elements(forName: "card")
        var cards: [Card] = []

        for node in nodes {
            guard
                let idString = node.attribute(forName: "id")?.stringValue,
                let id = UUID(uuidString: idString),
                let createdAtString = node.attribute(forName: "createdAt")?.stringValue,
                let createdAt = parseDate(createdAtString)
            else { continue }

            let sourceText = node.elements(forName: "sourceText").first?.stringValue ?? ""
            let markdown = node.elements(forName: "markdown").first?.stringValue ?? ""
            let audioFileName = Card.sanitizedAudioFileName(node.attribute(forName: "audioFileName")?.stringValue)

            cards.append(Card(
                id: id,
                createdAt: createdAt,
                sourceText: sourceText,
                markdown: markdown,
                audioFileName: audioFileName
            ))
        }

        if cards.isEmpty && !nodes.isEmpty {
            throw CardXMLError.unreadableCards
        }

        cards.sort { $0.createdAt > $1.createdAt }
        return cards
    }

    private static func parseDate(_ string: String) -> Date? {
        if let date = iso8601Fractional.date(from: string) {
            return date
        }
        return iso8601.date(from: string)
    }

    private static let iso8601Fractional: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    private static let iso8601: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()
}

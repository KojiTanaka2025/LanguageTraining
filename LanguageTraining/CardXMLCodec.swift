import Foundation

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
            if let createdAtAttr = XMLNode.attribute(withName: "createdAt", stringValue: iso8601.string(from: card.createdAt)) as? XMLNode {
                cardElement.addAttribute(createdAtAttr)
            }
            
            // 音声ファイル名を属性として追加
            if let audioFileName = card.audioFileName,
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
            return []
        }

        guard let cardsElement = root.elements(forName: "cards").first else {
            return []
        }

        var cards: [Card] = []

        for node in cardsElement.elements(forName: "card") {
            guard
                let idString = node.attribute(forName: "id")?.stringValue,
                let id = UUID(uuidString: idString),
                let createdAtString = node.attribute(forName: "createdAt")?.stringValue,
                let createdAt = iso8601.date(from: createdAtString)
            else { continue }

            let sourceText = node.elements(forName: "sourceText").first?.stringValue ?? ""
            let markdown = node.elements(forName: "markdown").first?.stringValue ?? ""
            let audioFileName = node.attribute(forName: "audioFileName")?.stringValue

            cards.append(Card(
                id: id,
                createdAt: createdAt,
                sourceText: sourceText,
                markdown: markdown,
                audioFileName: audioFileName
            ))
        }

        // 新しいものを上に
        cards.sort { $0.createdAt > $1.createdAt }
        return cards
    }

    private static let iso8601: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()
}


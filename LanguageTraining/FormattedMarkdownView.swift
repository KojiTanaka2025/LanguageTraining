import SwiftUI
import AppKit

/// NSTextViewを使用してMarkdownをフォーマット済みで表示するビュー
struct FormattedMarkdownView: NSViewRepresentable {
    let markdown: String

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSTextView.scrollableTextView()
        scrollView.drawsBackground = false
        scrollView.hasHorizontalScroller = false

        guard let textView = scrollView.documentView as? NSTextView else {
            return scrollView
        }

        textView.isEditable = false
        textView.isSelectable = true
        textView.drawsBackground = false
        textView.backgroundColor = .clear
        textView.textContainerInset = NSSize(width: 24, height: 22)
        textView.textContainer?.lineFragmentPadding = 0
        textView.textContainer?.lineBreakMode = .byWordWrapping
        textView.textColor = .labelColor
        textView.allowsUndo = false
        textView.isRichText = true
        textView.usesAdaptiveColorMappingForDarkAppearance = true

        return scrollView
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    final class Coordinator {
        var lastMarkdown: String?
        var lastAppearance: NSAppearance.Name?
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? NSTextView else {
            return
        }

        let appearance = scrollView.effectiveAppearance.bestMatch(from: [.aqua, .darkAqua])
        let markdownChanged = context.coordinator.lastMarkdown != markdown
        let appearanceChanged = context.coordinator.lastAppearance != appearance
        guard markdownChanged || appearanceChanged else { return }

        let savedOffset = scrollView.contentView.bounds.origin
        context.coordinator.lastMarkdown = markdown
        context.coordinator.lastAppearance = appearance

        textView.textStorage?.setAttributedString(MarkdownFormatter.format(markdown))

        if !markdownChanged {
            scrollView.contentView.scroll(to: savedOffset)
            scrollView.reflectScrolledClipView(scrollView.contentView)
        }
    }
}

private enum MarkdownFormatter {
    private static let bodySize: CGFloat = 15
    private static let titleSize: CGFloat = 24
    private static let sectionSize: CGFloat = 17
    private static let subsectionSize: CGFloat = 15

    static func format(_ text: String) -> NSAttributedString {
        let output = NSMutableAttributedString()
        let lines = text.components(separatedBy: .newlines)

        for (index, line) in lines.enumerated() {
            output.append(processLine(line))
            if index < lines.count - 1 {
                output.append(NSAttributedString(string: "\n"))
            }
        }

        return output
    }

    private static func processLine(_ line: String) -> NSAttributedString {
        let trimmed = line.trimmingCharacters(in: .whitespaces)

        if trimmed.hasPrefix("# ") {
            return heading(String(trimmed.dropFirst(2)), size: titleSize, weight: .bold, spaceBefore: 4, spaceAfter: 14)
        }
        if trimmed.hasPrefix("## ") {
            return heading(String(trimmed.dropFirst(3)), size: sectionSize, weight: .semibold, spaceBefore: 22, spaceAfter: 8)
        }
        if trimmed.hasPrefix("### ") {
            return heading(String(trimmed.dropFirst(4)), size: subsectionSize, weight: .semibold, spaceBefore: 14, spaceAfter: 6)
        }
        if trimmed.hasPrefix("#### ") {
            return heading(String(trimmed.dropFirst(5)), size: subsectionSize, weight: .medium, spaceBefore: 12, spaceAfter: 4, color: .secondaryLabelColor)
        }
        if trimmed == "---" || trimmed == "***" {
            return heading(" ", size: 6, weight: .regular, spaceBefore: 8, spaceAfter: 8, color: .tertiaryLabelColor)
        }
        if trimmed.hasPrefix("- ") || trimmed.range(of: #"^\d+\.\s"#, options: .regularExpression) != nil {
            return formatListItem(line)
        }
        if trimmed.isEmpty {
            return NSAttributedString(string: "")
        }

        return formatInlineStyles(line, paragraphStyle: bodyParagraphStyle())
    }

    private static func heading(
        _ title: String,
        size: CGFloat,
        weight: NSFont.Weight,
        spaceBefore: CGFloat,
        spaceAfter: CGFloat,
        color: NSColor = .labelColor
    ) -> NSAttributedString {
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = 2
        paragraphStyle.paragraphSpacingBefore = spaceBefore
        paragraphStyle.paragraphSpacing = spaceAfter
        return formatInlineStyles(
            title,
            paragraphStyle: paragraphStyle,
            font: NSFont.systemFont(ofSize: size, weight: weight),
            color: color
        )
    }

    private static func formatListItem(_ line: String) -> NSAttributedString {
        let leadingSpaces = line.prefix(while: { $0 == " " }).count
        let level = min(leadingSpaces / 2, 3)
        let baseIndent = 18 + CGFloat(level) * 16

        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = 4
        paragraphStyle.paragraphSpacing = 6
        paragraphStyle.firstLineHeadIndent = baseIndent
        paragraphStyle.headIndent = baseIndent + 18

        let trimmed = line.trimmingCharacters(in: .whitespaces)
        let marker: String
        let content: String

        if trimmed.hasPrefix("- ") {
            marker = level == 0 ? "•" : "◦"
            content = String(trimmed.dropFirst(2))
        } else if let range = trimmed.range(of: #"^\d+\.\s"#, options: .regularExpression) {
            marker = String(trimmed[range]).trimmingCharacters(in: .whitespaces)
            content = String(trimmed[range.upperBound...])
        } else {
            return formatInlineStyles(line, paragraphStyle: paragraphStyle)
        }

        let attributed = NSMutableAttributedString()
        attributed.append(NSAttributedString(
            string: marker + "  ",
            attributes: [
                .font: NSFont.systemFont(ofSize: bodySize, weight: .regular),
                .foregroundColor: NSColor.tertiaryLabelColor,
                .paragraphStyle: paragraphStyle
            ]
        ))
        attributed.append(formatLabeledContent(content, paragraphStyle: paragraphStyle))
        return attributed
    }

    /// `- ラベル: 本文` を、ラベルだけ少し強調して読みやすくする
    private static func formatLabeledContent(_ content: String, paragraphStyle: NSParagraphStyle) -> NSAttributedString {
        if let colon = content.firstIndex(of: ":") {
            let label = String(content[..<colon]).trimmingCharacters(in: .whitespaces)
            let remainder = String(content[colon...])
            if !label.isEmpty, label.count <= 40, !label.contains("**") {
                let result = NSMutableAttributedString()
                result.append(formatInlineStyles(
                    label,
                    paragraphStyle: paragraphStyle,
                    font: NSFont.systemFont(ofSize: bodySize, weight: .medium)
                ))
                result.append(formatInlineStyles(remainder, paragraphStyle: paragraphStyle))
                return result
            }
        }
        return formatInlineStyles(content, paragraphStyle: paragraphStyle)
    }

    private static func bodyParagraphStyle() -> NSMutableParagraphStyle {
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = 5
        paragraphStyle.paragraphSpacing = 8
        return paragraphStyle
    }

    private static func formatInlineStyles(
        _ text: String,
        paragraphStyle: NSParagraphStyle? = nil,
        font: NSFont = NSFont.systemFont(ofSize: bodySize),
        color: NSColor = .labelColor
    ) -> NSAttributedString {
        var attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: color
        ]
        if let paragraphStyle {
            attributes[.paragraphStyle] = paragraphStyle
        }

        let attributed = NSMutableAttributedString(string: text, attributes: attributes)

        formatPattern(in: attributed, pattern: #"\*\*([^*]+)\*\*"#, attributes: merged(
            base: attributes,
            [
                .font: NSFont.systemFont(ofSize: font.pointSize, weight: .semibold),
                .foregroundColor: NSColor.labelColor
            ]
        ))

        formatPattern(in: attributed, pattern: #"(?<!\*)\*([^*]+)\*(?!\*)"#, attributes: merged(
            base: attributes,
            [
                .font: italicFont(size: font.pointSize),
                .foregroundColor: NSColor.labelColor
            ]
        ))

        formatPattern(in: attributed, pattern: #"`([^`]+)`"#, attributes: merged(
            base: attributes,
            [
                .font: NSFont.monospacedSystemFont(ofSize: max(font.pointSize - 1, 12), weight: .regular),
                .foregroundColor: NSColor.labelColor,
                .backgroundColor: NSColor.quaternaryLabelColor.withAlphaComponent(0.18)
            ]
        ))

        return attributed
    }

    private static func merged(
        base: [NSAttributedString.Key: Any],
        _ overlay: [NSAttributedString.Key: Any]
    ) -> [NSAttributedString.Key: Any] {
        var result = base
        overlay.forEach { result[$0.key] = $0.value }
        return result
    }

    private static func italicFont(size: CGFloat) -> NSFont {
        let base = NSFont.systemFont(ofSize: size)
        let descriptor = base.fontDescriptor.withSymbolicTraits(.italic)
        return NSFont(descriptor: descriptor, size: size) ?? base
    }

    private static func formatPattern(
        in attributedString: NSMutableAttributedString,
        pattern: String,
        attributes: [NSAttributedString.Key: Any]
    ) {
        let string = attributedString.string
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
            return
        }

        let matches = regex.matches(in: string, options: [], range: NSRange(string.startIndex..., in: string))
        for match in matches.reversed() {
            guard match.numberOfRanges >= 2,
                  let contentRange = Range(match.range(at: 1), in: string) else {
                continue
            }
            let content = String(string[contentRange])
            attributedString.replaceCharacters(
                in: match.range(at: 0),
                with: NSAttributedString(string: content, attributes: attributes)
            )
        }
    }
}

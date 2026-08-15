import SwiftUI

#if os(macOS)
import AppKit
private typealias PlatformColor = NSColor
private typealias PlatformFont = NSFont
private typealias PlatformFontDescriptor = NSFontDescriptor

private extension NSColor {
    static var label: NSColor { .labelColor }
    static var secondaryLabel: NSColor { .secondaryLabelColor }
    static var tertiaryLabel: NSColor { .tertiaryLabelColor }
    static var quaternaryLabel: NSColor { .quaternaryLabelColor }
}
#else
import UIKit
private typealias PlatformColor = UIColor
private typealias PlatformFont = UIFont
private typealias PlatformFontDescriptor = UIFontDescriptor
#endif

struct FormattedMarkdownView: View {
    let markdown: String

    var body: some View {
        MarkdownTextView(markdown: markdown)
    }
}

#if os(macOS)
private struct MarkdownTextView: NSViewRepresentable {
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
        textView.textContainerInset = NSSize(width: 36, height: 28)
        textView.textContainer?.lineFragmentPadding = 0
        textView.textContainer?.lineBreakMode = .byWordWrapping
        textView.textColor = .labelColor
        textView.font = ReadingFont.body(size: ReadingMetrics.bodySize)
        textView.allowsUndo = false
        textView.isRichText = true
        textView.usesAdaptiveColorMappingForDarkAppearance = false
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
        guard let textView = scrollView.documentView as? NSTextView else { return }
        let appearance = scrollView.effectiveAppearance.bestMatch(from: [.aqua, .darkAqua])
        let markdownChanged = context.coordinator.lastMarkdown != markdown
        let appearanceChanged = context.coordinator.lastAppearance != appearance
        guard markdownChanged || appearanceChanged else { return }

        let savedOffset = scrollView.contentView.bounds.origin
        context.coordinator.lastMarkdown = markdown
        context.coordinator.lastAppearance = appearance
        scrollView.effectiveAppearance.performAsCurrentDrawingAppearance {
            textView.textStorage?.setAttributedString(MarkdownFormatter.format(markdown))
        }

        if !markdownChanged {
            scrollView.contentView.scroll(to: savedOffset)
            scrollView.reflectScrolledClipView(scrollView.contentView)
        }
    }
}
#else
private final class SizingTextView: UITextView {
    override var intrinsicContentSize: CGSize {
        let width = bounds.width > 0 ? bounds.width : UIScreen.main.bounds.width
        let fitting = sizeThatFits(CGSize(width: width, height: .greatestFiniteMagnitude))
        return CGSize(width: UIView.noIntrinsicMetric, height: fitting.height)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        invalidateIntrinsicContentSize()
    }
}

private struct MarkdownTextView: UIViewRepresentable {
    let markdown: String

    func makeUIView(context: Context) -> SizingTextView {
        let textView = SizingTextView()
        textView.isEditable = false
        textView.isSelectable = true
        textView.isScrollEnabled = false
        textView.backgroundColor = .clear
        textView.textContainerInset = UIEdgeInsets(top: 16, left: 22, bottom: 28, right: 22)
        textView.textContainer.lineFragmentPadding = 0
        textView.adjustsFontForContentSizeCategory = true
        textView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        return textView
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    final class Coordinator {
        var lastMarkdown: String?
        var lastStyle: UIUserInterfaceStyle?
    }

    func updateUIView(_ textView: SizingTextView, context: Context) {
        let style = textView.traitCollection.userInterfaceStyle
        let markdownChanged = context.coordinator.lastMarkdown != markdown
        let appearanceChanged = context.coordinator.lastStyle != style
        guard markdownChanged || appearanceChanged else { return }

        context.coordinator.lastMarkdown = markdown
        context.coordinator.lastStyle = style
        textView.traitCollection.performAsCurrent {
            textView.attributedText = MarkdownFormatter.format(markdown)
        }
        textView.invalidateIntrinsicContentSize()
    }
}
#endif

// MARK: - Reading typography

private enum ReadingMetrics {
    static let bodySize: CGFloat = 16.5
    static let titleSize: CGFloat = 28
    static let sectionSize: CGFloat = 21
    static let captionSize: CGFloat = 13
}

private enum ReadingPalette {
    static var ink: PlatformColor { .label }
    static var heading: PlatformColor { .label }
    static var muted: PlatformColor { .secondaryLabel }
    static var faint: PlatformColor { .tertiaryLabel }
}

private enum ReadingFont {
    static func body(size: CGFloat, bold: Bool = false) -> PlatformFont {
        scaled(cascadeSerif(size: size, bold: bold), textStyle: .body)
    }

    static func heading(size: CGFloat) -> PlatformFont {
        scaled(cascadeSerif(size: size, bold: true), textStyle: .headline)
    }

    static func italic(size: CGFloat) -> PlatformFont {
        let base = cascadeSerif(size: size, bold: false)
        #if os(macOS)
        let descriptor = base.fontDescriptor.withSymbolicTraits(.italic)
        return PlatformFont(descriptor: descriptor, size: size) ?? base
        #else
        guard let descriptor = base.fontDescriptor.withSymbolicTraits(.traitItalic) else { return base }
        return PlatformFont(descriptor: descriptor, size: size)
        #endif
    }

    static func mono(size: CGFloat) -> PlatformFont {
        scaled(PlatformFont.monospacedSystemFont(ofSize: size, weight: .regular), textStyle: .body)
    }

    /// New York for Latin, Hiragino Mincho for Japanese.
    private static func cascadeSerif(size: CGFloat, bold: Bool) -> PlatformFont {
        let weight: PlatformFont.Weight = bold ? .semibold : .medium
        let system = PlatformFont.systemFont(ofSize: size, weight: weight)
        let serifDescriptor = system.fontDescriptor.withDesign(.serif) ?? system.fontDescriptor
        let minchoName = bold ? "HiraMinProN-W6" : "HiraMinProN-W3"
        let minchoDescriptor = PlatformFontDescriptor(name: minchoName, size: size)

        #if os(macOS)
        let cascaded = serifDescriptor.addingAttributes([
            .cascadeList: [minchoDescriptor]
        ])
        return PlatformFont(descriptor: cascaded, size: size)
            ?? PlatformFont(name: minchoName, size: size)
            ?? system
        #else
        let cascaded = serifDescriptor.addingAttributes([
            .cascadeList: [minchoDescriptor]
        ])
        return PlatformFont(descriptor: cascaded, size: size)
        #endif
    }

    private static func scaled(_ font: PlatformFont, textStyle: PlatformFont.TextStyle) -> PlatformFont {
        #if os(macOS)
        _ = textStyle
        return font
        #else
        return UIFontMetrics(forTextStyle: textStyle).scaledFont(for: font)
        #endif
    }
}

private enum MarkdownFormatter {
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
            return heading(
                String(trimmed.dropFirst(2)),
                font: ReadingFont.heading(size: ReadingMetrics.titleSize),
                color: ReadingPalette.ink,
                spaceBefore: 6,
                spaceAfter: 10,
                lineHeight: 1.22
            )
        }
        if trimmed.hasPrefix("## ") {
            return heading(
                String(trimmed.dropFirst(3)),
                font: ReadingFont.heading(size: ReadingMetrics.sectionSize),
                color: ReadingPalette.heading,
                spaceBefore: 20,
                spaceAfter: 6,
                lineHeight: 1.28
            )
        }
        if trimmed.hasPrefix("### ") {
            return heading(
                String(trimmed.dropFirst(4)),
                font: ReadingFont.heading(size: ReadingMetrics.bodySize),
                color: ReadingPalette.heading,
                spaceBefore: 18,
                spaceAfter: 8,
                lineHeight: 1.28
            )
        }
        if trimmed.hasPrefix("#### ") {
            return heading(
                String(trimmed.dropFirst(5)),
                font: ReadingFont.body(size: ReadingMetrics.captionSize, bold: true),
                color: ReadingPalette.muted,
                spaceBefore: 14,
                spaceAfter: 6,
                lineHeight: 1.3
            )
        }
        if trimmed == "---" || trimmed == "***" {
            return heading(
                "—",
                font: ReadingFont.body(size: ReadingMetrics.captionSize),
                color: ReadingPalette.faint,
                spaceBefore: 18,
                spaceAfter: 10,
                lineHeight: 1.2
            )
        }
        if trimmed.hasPrefix("- ") || trimmed.range(of: #"^\d+\.\s"#, options: .regularExpression) != nil {
            return formatListItem(line)
        }
        if trimmed.isEmpty {
            return NSAttributedString(string: "")
        }

        return formatInlineStyles(line, paragraphStyle: bodyParagraphStyle(), color: ReadingPalette.ink)
    }

    private static func heading(
        _ title: String,
        font: PlatformFont,
        color: PlatformColor,
        spaceBefore: CGFloat,
        spaceAfter: CGFloat,
        lineHeight: CGFloat
    ) -> NSAttributedString {
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineHeightMultiple = lineHeight
        paragraphStyle.paragraphSpacingBefore = spaceBefore
        paragraphStyle.paragraphSpacing = spaceAfter
        return formatInlineStyles(
            title,
            paragraphStyle: paragraphStyle,
            font: font,
            color: color
        )
    }

    private static func formatListItem(_ line: String) -> NSAttributedString {
        let leadingSpaces = line.prefix(while: { $0 == " " }).count
        let level = min(leadingSpaces / 2, 3)
        let baseIndent = 14 + CGFloat(level) * 18

        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineHeightMultiple = 1.26
        paragraphStyle.paragraphSpacing = 5
        paragraphStyle.firstLineHeadIndent = baseIndent
        paragraphStyle.headIndent = baseIndent + 16
        paragraphStyle.lineBreakMode = .byWordWrapping

        let trimmed = line.trimmingCharacters(in: .whitespaces)
        let marker: String
        let content: String

        if trimmed.hasPrefix("- ") {
            marker = "·"
            content = String(trimmed.dropFirst(2))
        } else if let range = trimmed.range(of: #"^\d+\.\s"#, options: .regularExpression) {
            marker = String(trimmed[range]).trimmingCharacters(in: .whitespaces)
            content = String(trimmed[range.upperBound...])
        } else {
            return formatInlineStyles(line, paragraphStyle: paragraphStyle, color: ReadingPalette.ink)
        }

        let attributed = NSMutableAttributedString()
        attributed.append(NSAttributedString(
            string: marker + "  ",
            attributes: [
                .font: ReadingFont.body(size: ReadingMetrics.bodySize),
                .foregroundColor: ReadingPalette.faint,
                .paragraphStyle: paragraphStyle,
                .ligature: 1
            ]
        ))
        attributed.append(formatLabeledContent(content, paragraphStyle: paragraphStyle))
        return attributed
    }

    private static func formatLabeledContent(_ content: String, paragraphStyle: NSParagraphStyle) -> NSAttributedString {
        if let colon = content.firstIndex(of: ":") {
            let label = String(content[..<colon]).trimmingCharacters(in: .whitespaces)
            let remainder = String(content[colon...])
            if !label.isEmpty, label.count <= 40, !label.contains("**") {
                let result = NSMutableAttributedString()
                result.append(formatInlineStyles(
                    label,
                    paragraphStyle: paragraphStyle,
                    font: ReadingFont.body(size: ReadingMetrics.bodySize, bold: true),
                    color: ReadingPalette.muted
                ))
                result.append(formatInlineStyles(
                    remainder,
                    paragraphStyle: paragraphStyle,
                    color: ReadingPalette.ink
                ))
                return result
            }
        }
        return formatInlineStyles(content, paragraphStyle: paragraphStyle, color: ReadingPalette.ink)
    }

    private static func bodyParagraphStyle() -> NSMutableParagraphStyle {
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineHeightMultiple = 1.28
        paragraphStyle.paragraphSpacing = 6
        paragraphStyle.lineBreakMode = .byWordWrapping
        return paragraphStyle
    }

    private static func formatInlineStyles(
        _ text: String,
        paragraphStyle: NSParagraphStyle? = nil,
        font: PlatformFont = ReadingFont.body(size: ReadingMetrics.bodySize),
        color: PlatformColor = ReadingPalette.ink
    ) -> NSAttributedString {
        var attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: color,
            .ligature: 1,
            .kern: 0.15
        ]
        if let paragraphStyle {
            attributes[.paragraphStyle] = paragraphStyle
        }

        let attributed = NSMutableAttributedString(string: text, attributes: attributes)

        formatPattern(in: attributed, pattern: #"\*\*([^*]+)\*\*"#, attributes: merged(
            base: attributes,
            [
                .font: ReadingFont.body(size: font.pointSize, bold: true),
                .foregroundColor: ReadingPalette.ink,
                .kern: 0.2
            ]
        ))

        formatPattern(in: attributed, pattern: #"(?<!\*)\*([^*]+)\*(?!\*)"#, attributes: merged(
            base: attributes,
            [
                .font: ReadingFont.italic(size: max(font.pointSize - 1, ReadingMetrics.captionSize)),
                .foregroundColor: ReadingPalette.muted,
                .kern: 0.1
            ]
        ))

        formatPattern(in: attributed, pattern: #"`([^`]+)`"#, attributes: merged(
            base: attributes,
            [
                .font: ReadingFont.mono(size: max(font.pointSize - 1.5, 12)),
                .foregroundColor: ReadingPalette.ink,
                .backgroundColor: PlatformColor.quaternaryLabel.withAlphaComponent(0.12),
                .kern: 0
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

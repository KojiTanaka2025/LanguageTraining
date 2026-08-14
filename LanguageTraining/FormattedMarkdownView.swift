import SwiftUI
import AppKit

/// NSTextViewを使用してMarkdownをフォーマット済みで表示するビュー
struct FormattedMarkdownView: NSViewRepresentable {
    let markdown: String
    
    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSTextView.scrollableTextView()
        
        guard let textView = scrollView.documentView as? NSTextView else {
            return scrollView
        }
        
        // テキストビューの設定
        textView.isEditable = false
        textView.isSelectable = true
        textView.backgroundColor = .clear
        textView.textContainerInset = NSSize(width: 20, height: 20)
        textView.textContainer?.lineFragmentPadding = 0
        
        // デフォルトのテキストカラー
        textView.textColor = .labelColor
        
        // リッチテキストを有効化
        textView.allowsUndo = false
        textView.isRichText = true
        
        return scrollView
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    final class Coordinator {
        var lastMarkdown: String?
    }
    
    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? NSTextView else {
            return
        }
        guard context.coordinator.lastMarkdown != markdown else {
            return
        }
        context.coordinator.lastMarkdown = markdown
        
        let attributedString = formatMarkdown(markdown)
        textView.textStorage?.setAttributedString(attributedString)
    }
    
    private func formatMarkdown(_ text: String) -> NSAttributedString {
        let attributedString = NSMutableAttributedString()
        
        // 段落スタイルのデフォルト設定
        let defaultParagraphStyle = NSMutableParagraphStyle()
        defaultParagraphStyle.lineSpacing = 4
        defaultParagraphStyle.paragraphSpacing = 12
        
        // 行ごとに処理
        let lines = text.components(separatedBy: .newlines)
        
        for (index, line) in lines.enumerated() {
            let processedLine = processLine(line)
            attributedString.append(processedLine)
            
            // 最後の行以外は改行を追加
            if index < lines.count - 1 {
                attributedString.append(NSAttributedString(string: "\n"))
            }
        }
        
        return attributedString
    }
    
    private func processLine(_ line: String) -> NSAttributedString {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        
        // 段落スタイル
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = 3
        
        // 見出し1 (# Title)
        if trimmed.hasPrefix("# ") {
            let title = String(trimmed.dropFirst(2))
            paragraphStyle.paragraphSpacing = 16
            paragraphStyle.paragraphSpacingBefore = 8
            return NSAttributedString(
                string: title,
                attributes: [
                    .font: NSFont.systemFont(ofSize: 28, weight: .bold),
                    .foregroundColor: NSColor.labelColor,
                    .paragraphStyle: paragraphStyle
                ]
            )
        }
        
        // 見出し2 (## Title)
        if trimmed.hasPrefix("## ") {
            let title = String(trimmed.dropFirst(3))
            paragraphStyle.paragraphSpacing = 12
            paragraphStyle.paragraphSpacingBefore = 16
            return NSAttributedString(
                string: title,
                attributes: [
                    .font: NSFont.systemFont(ofSize: 22, weight: .bold),
                    .foregroundColor: NSColor.labelColor,
                    .paragraphStyle: paragraphStyle
                ]
            )
        }
        
        // 見出し3 (### Title)
        if trimmed.hasPrefix("### ") {
            let title = String(trimmed.dropFirst(4))
            paragraphStyle.paragraphSpacing = 10
            paragraphStyle.paragraphSpacingBefore = 12
            return NSAttributedString(
                string: title,
                attributes: [
                    .font: NSFont.systemFont(ofSize: 18, weight: .semibold),
                    .foregroundColor: NSColor.labelColor,
                    .paragraphStyle: paragraphStyle
                ]
            )
        }
        
        // 見出し4 (#### Title) - AIの出力でよく使われる
        if trimmed.hasPrefix("#### ") {
            let title = String(trimmed.dropFirst(5))
            paragraphStyle.paragraphSpacing = 8
            paragraphStyle.paragraphSpacingBefore = 12
            return NSAttributedString(
                string: title,
                attributes: [
                    .font: NSFont.systemFont(ofSize: 16, weight: .semibold),
                    .foregroundColor: NSColor.systemBlue,
                    .paragraphStyle: paragraphStyle
                ]
            )
        }
        
        // リスト項目 (- Item または 1. Item)
        if trimmed.hasPrefix("- ") || trimmed.range(of: #"^\d+\.\s"#, options: .regularExpression) != nil {
            paragraphStyle.paragraphSpacing = 4
            paragraphStyle.firstLineHeadIndent = 0
            paragraphStyle.headIndent = 20
            return formatListItem(line, paragraphStyle: paragraphStyle)
        }
        
        // 空行
        if trimmed.isEmpty {
            return NSAttributedString(string: "")
        }
        
        // 通常のテキスト（太字やイタリックを処理）
        paragraphStyle.paragraphSpacing = 6
        return formatInlineStyles(line, paragraphStyle: paragraphStyle)
    }
    
    private func formatListItem(_ line: String, paragraphStyle: NSMutableParagraphStyle) -> NSAttributedString {
        let attributed = NSMutableAttributedString()
        
        // インデントを保持
        let leadingSpaces = line.prefix(while: { $0 == " " }).count
        let baseIndent = CGFloat(leadingSpaces * 8)
        
        paragraphStyle.firstLineHeadIndent = baseIndent
        paragraphStyle.headIndent = baseIndent + 20
        
        // リスト記号または番号を処理
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        if trimmed.hasPrefix("- ") {
            attributed.append(NSAttributedString(
                string: "•  ",
                attributes: [
                    .font: NSFont.systemFont(ofSize: 15, weight: .bold),
                    .foregroundColor: NSColor.systemBlue,
                    .paragraphStyle: paragraphStyle
                ]
            ))
            let content = String(trimmed.dropFirst(2))
            attributed.append(formatInlineStyles(content, paragraphStyle: paragraphStyle))
        } else if let range = trimmed.range(of: #"^\d+\.\s"#, options: .regularExpression) {
            let number = String(trimmed[range])
            attributed.append(NSAttributedString(
                string: number + " ",
                attributes: [
                    .font: NSFont.systemFont(ofSize: 15, weight: .semibold),
                    .foregroundColor: NSColor.systemBlue,
                    .paragraphStyle: paragraphStyle
                ]
            ))
            let content = String(trimmed[range.upperBound...])
            attributed.append(formatInlineStyles(content, paragraphStyle: paragraphStyle))
        }
        
        return attributed
    }
    
    private func formatInlineStyles(_ text: String, paragraphStyle: NSMutableParagraphStyle? = nil) -> NSAttributedString {
        var attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 15),
            .foregroundColor: NSColor.labelColor
        ]
        
        if let paragraphStyle = paragraphStyle {
            attributes[.paragraphStyle] = paragraphStyle
        }
        
        let attributed = NSMutableAttributedString(
            string: text,
            attributes: attributes
        )
        
        // 太字 (**text**)
        formatPattern(in: attributed, pattern: #"\*\*([^*]+)\*\*"#, attributes: [
            .font: NSFont.systemFont(ofSize: 15, weight: .bold),
            .foregroundColor: NSColor.labelColor
        ])
        
        // イタリック (*text*)
        formatPattern(in: attributed, pattern: #"(?<!\*)\*([^*]+)\*(?!\*)"#, attributes: [
            .font: NSFont.systemFont(ofSize: 15).italicized,
            .foregroundColor: NSColor.secondaryLabelColor
        ])
        
        // コード (`code`)
        formatPattern(in: attributed, pattern: #"`([^`]+)`"#, attributes: [
            .font: NSFont.monospacedSystemFont(ofSize: 14, weight: .regular),
            .foregroundColor: NSColor.systemPink,
            .backgroundColor: NSColor.systemGray.withAlphaComponent(0.15)
        ])
        
        return attributed
    }
    
    private func formatPattern(in attributedString: NSMutableAttributedString, pattern: String, attributes: [NSAttributedString.Key: Any]) {
        let string = attributedString.string
        
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
            return
        }
        
        let matches = regex.matches(in: string, options: [], range: NSRange(string.startIndex..., in: string))
        
        // 後ろから処理（インデックスがずれないように）
        for match in matches.reversed() {
            if match.numberOfRanges >= 2 {
                let fullRange = match.range(at: 0)
                let contentRange = match.range(at: 1)
                
                if let contentSwiftRange = Range(contentRange, in: string) {
                    let content = String(string[contentSwiftRange])
                    let replacement = NSAttributedString(string: content, attributes: attributes)
                    attributedString.replaceCharacters(in: fullRange, with: replacement)
                }
            }
        }
    }
}

extension NSFont {
    var italicized: NSFont {
        let descriptor = fontDescriptor.withSymbolicTraits(.italic)
        return NSFont(descriptor: descriptor, size: pointSize) ?? self
    }
}

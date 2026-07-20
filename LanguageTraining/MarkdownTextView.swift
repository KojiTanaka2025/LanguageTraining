import SwiftUI

/// SwiftUIでMarkdownを表示するためのビュー
struct MarkdownTextView: View {
    let markdown: String
    
    var body: some View {
        if #available(macOS 12.0, *) {
            Text(.init(markdown))
                .textSelection(.enabled)
                .font(.body)
        } else {
            // フォールバック：プレーンテキスト表示
            Text(markdown)
                .textSelection(.enabled)
                .font(.body)
        }
    }
}

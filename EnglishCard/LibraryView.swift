import SwiftUI
import SwiftUI
import Combine
import AppKit

struct LibraryView: View {
    @EnvironmentObject private var store: CardStore
    @EnvironmentObject private var settings: AppSettings

    @State private var query: String = ""
    @State private var selected: Card.ID?
    
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                TextField("検索（単語/本文/解説）", text: $query)
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 420)

                Spacer()

                Text("\(filtered.count)件")
                    .foregroundStyle(.secondary)
            }
            .padding(16)

            Divider()

            if filtered.isEmpty && !query.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 42))
                        .foregroundStyle(.secondary)
                    Text("検索結果が見つかりません")
                        .font(.title3)
                        .bold()
                    Text("別のキーワードで検索してください")
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if store.cards.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "tray")
                        .font(.system(size: 42))
                        .foregroundStyle(.secondary)
                    Text("まだカードがありません")
                        .font(.title3)
                        .bold()
                    Text("「英語解説」タブで単語や文を解説してカードを作成しましょう")
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 420)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(selection: $selected) {
                    ForEach(filtered) { card in
                        CardRow(card: card)
                            .tag(card.id)
                            .contentShape(Rectangle())
                            .onTapGesture(count: 2) {
                                openDetailWindow(for: card)
                            }
                            .contextMenu {
                                Button("詳細を表示") {
                                    openDetailWindow(for: card)
                                }
                                Divider()
                                Button("削除", role: .destructive) {
                                    deleteCard(card)
                                }
                            }
                    }
                }
                .listStyle(.inset)
            }
            
            if let errorMessage {
                HStack {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                        .font(.callout)
                    Spacer()
                    Button("閉じる") {
                        self.errorMessage = nil
                    }
                }
                .padding(12)
                .background(Color(nsColor: .controlBackgroundColor))
            }
        }
    }

    private var filtered: [Card] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return store.cards }
        return store.cards.filter { c in
            c.sourceText.localizedCaseInsensitiveContains(q) || c.markdown.localizedCaseInsensitiveContains(q)
        }
    }
    
    private func deleteCard(_ card: Card) {
        do {
            try store.deleteCard(card)
            if selected == card.id {
                selected = nil
            }
        } catch {
            errorMessage = "削除に失敗しました: \(error.localizedDescription)"
        }
    }
    
    private func openDetailWindow(for card: Card) {
        let detailView = CardDetailView(card: card)
            .environmentObject(settings)
        let hostingController = NSHostingController(rootView: detailView)
        
        let window = NSWindow(contentViewController: hostingController)
        window.title = "学習カード詳細"
        window.styleMask = [.titled, .closable, .resizable]
        window.setContentSize(NSSize(width: 700, height: 600))
        window.center()
        window.makeKeyAndOrderFront(nil)
        
        // ウィンドウを保持
        NSApp.activate(ignoringOtherApps: true)
    }
}

private struct CardRow: View {
    let card: Card

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                // 音声アイコン（音声がある場合のみ表示）
                if card.audioFileName != nil {
                    Image(systemName: "speaker.wave.2.fill")
                        .foregroundStyle(.blue)
                        .font(.caption)
                        .help("音声データあり")
                }
                
                Text(card.sourceText.replacingOccurrences(of: "\n", with: " "))
                    .font(.headline)
                    .lineLimit(1)
                Spacer()
                Text(card.createdAt, style: .date)
                    .foregroundStyle(.secondary)
                    .font(.caption)
            }
            Text(previewText(from: card.markdown))
                .foregroundStyle(.secondary)
                .font(.subheadline)
                .lineLimit(2)
        }
        .padding(.vertical, 6)
    }

    private func previewText(from markdown: String) -> String {
        let collapsed = markdown
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\n", with: " ")
        return collapsed.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}


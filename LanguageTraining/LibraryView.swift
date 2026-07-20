import SwiftUI
import Combine
import AppKit

struct LibraryView: View {
    @EnvironmentObject private var store: CardStore
    @EnvironmentObject private var settings: AppSettings

    @State private var query: String = ""
    @State private var selected: Card.ID?
    
    @State private var errorMessage: String?
    @State private var cardPendingDeletion: Card?
    
    // 音声再生用
    @StateObject private var audioPlayer = AudioPlayerService.shared
    @State private var isLoadingAudio = false
    @State private var audioErrorMessage: String?

    var body: some View {
        VStack(spacing: 0) {
            // 検索バー
            HStack(spacing: 12) {
                TextField("Search words, text, or explanations", text: $query)
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 420)

                Spacer()

                Text("\(filtered.count) cards")
                    .foregroundStyle(.secondary)
            }
            .padding(16)

            Divider()

            // メインコンテンツエリア
            if filtered.isEmpty && !query.isEmpty {
                // 検索結果なし
                VStack(spacing: 12) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 42))
                        .foregroundStyle(.secondary)
                    Text("No results found")
                        .font(.title3)
                        .bold()
                    Text("Try a different keyword.")
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if store.cards.isEmpty {
                // カードが空
                VStack(spacing: 12) {
                    Image(systemName: "tray")
                        .font(.system(size: 42))
                        .foregroundStyle(.secondary)
                    Text("No cards yet")
                        .font(.title3)
                        .bold()
                    Text("Use the Explain tab to create cards from text in any language, including Vietnamese.")
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 420)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                // 左右分割レイアウト
                HSplitView {
                    // 左ペイン: カード一覧
                    VStack(spacing: 0) {
                        List(selection: $selected) {
                            ForEach(filtered) { card in
                                CardRow(card: card)
                                    .tag(card.id)
                                    .contentShape(Rectangle())
                                    .contextMenu {
                                        Button("Delete", role: .destructive) {
                                            cardPendingDeletion = card
                                        }
                                    }
                            }
                        }
                        .listStyle(.sidebar)
                    }
                    .frame(minWidth: 300, idealWidth: 350, maxWidth: 500)
                    
                    // 右ペイン: 詳細表示
                    if let selectedCard = filtered.first(where: { $0.id == selected }) {
                        CardDetailPane(
                            card: selectedCard,
                            isLoadingAudio: $isLoadingAudio,
                            audioErrorMessage: $audioErrorMessage,
                            onPlayAudio: { playPronunciation(for: selectedCard) }
                        )
                    } else {
                        // 未選択時のプレースホルダー
                        VStack(spacing: 16) {
                            Image(systemName: "hand.point.left.fill")
                                .font(.system(size: 48))
                                .foregroundStyle(.tertiary)
                            Text("Select a card from the list.")
                                .font(.title3)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color(nsColor: .textBackgroundColor))
                    }
                }
            }
            
            // エラーメッセージ
            if let errorMessage {
                HStack {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                        .font(.callout)
                    Spacer()
                    Button("Close") {
                        self.errorMessage = nil
                    }
                }
                .padding(12)
                .background(Color(nsColor: .controlBackgroundColor))
            }
        }
        .alert(item: $cardPendingDeletion) { card in
            Alert(
                title: Text("Delete this card?"),
                message: Text("This will delete \"\(card.sourceText.replacingOccurrences(of: "\n", with: " "))\". This action cannot be undone."),
                primaryButton: .destructive(Text("Delete")) {
                    deleteCard(card)
                },
                secondaryButton: .cancel(Text("Cancel"))
            )
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
            errorMessage = "Failed to delete the card: \(error.localizedDescription)"
        }
    }
    
    private func playPronunciation(for card: Card) {
        Task {
            isLoadingAudio = true
            audioErrorMessage = nil
            
            do {
                // 保存済みの音声があればそれを再生
                if let audioURL = card.audioFileURL(),
                   FileManager.default.fileExists(atPath: audioURL.path) {
                    try audioPlayer.play(fileURL: audioURL, text: card.sourceText, deleteAfterPlay: false)
                } else {
                    // 音声がない場合は新規生成
                    guard let baseURL = URL(string: settings.openAIBaseURL) else {
                        throw OpenAIError.invalidBaseURL
                    }
                    
                    let client = OpenAIClient(
                        baseURL: baseURL,
                        apiKey: settings.apiKey,
                        model: settings.openAIModel
                    )
                    
                    let audioURL = try await client.textToSpeech(
                        text: card.sourceText,
                        voice: OpenAIClient.defaultTTSVoice,
                        speed: 0.9
                    )
                    
                    try audioPlayer.play(fileURL: audioURL, text: card.sourceText, deleteAfterPlay: true)
                }
                
            } catch let error as OpenAIError {
                audioErrorMessage = error.errorDescription
            } catch {
                audioErrorMessage = "Failed to generate audio: \(error.localizedDescription)"
            }
            
            isLoadingAudio = false
        }
    }
}

// MARK: - 右ペイン: カード詳細表示

private struct CardDetailPane: View {
    let card: Card
    @Binding var isLoadingAudio: Bool
    @Binding var audioErrorMessage: String?
    let onPlayAudio: () -> Void
    
    @StateObject private var audioPlayer = AudioPlayerService.shared
    
    var body: some View {
        VStack(spacing: 0) {
            // ヘッダー
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Label("Original Text", systemImage: "textformat.abc")
                        .font(.headline)
                        .foregroundStyle(.blue)
                    
                    Text("Created: \(card.createdAt.formatted(date: .long, time: .shortened))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                // 音声再生ボタン
                Button(action: onPlayAudio) {
                    HStack(spacing: 6) {
                        if isLoadingAudio {
                            ProgressView()
                                .controlSize(.small)
                                .frame(width: 16, height: 16)
                        } else if audioPlayer.isPlaying && audioPlayer.currentText == card.sourceText {
                            Image(systemName: "speaker.wave.2.fill")
                                .foregroundStyle(.blue)
                        } else {
                            Image(systemName: card.audioFileName != nil ? "speaker.wave.2.fill" : "speaker.wave.2")
                        }
                        Text(card.audioFileName != nil ? "Play Audio" : "Generate Audio")
                            .font(.callout)
                    }
                }
                .disabled(isLoadingAudio || (audioPlayer.isPlaying && audioPlayer.currentText == card.sourceText))
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }
            .padding(20)
            
            Divider()
            
            // 英文表示
            ScrollView {
                Text(card.sourceText)
                    .font(.title3)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
            }
            .frame(height: 100)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(nsColor: .controlBackgroundColor))
            )
            .padding(.horizontal, 20)
            .padding(.top, 12)
            
            // エラーメッセージ
            if let audioErrorMessage {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                    Text(audioErrorMessage)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
            }
            
            Divider()
                .padding(.vertical, 16)
            
            // Markdown解説
            VStack(alignment: .leading, spacing: 8) {
                Label("AI Explanation", systemImage: "sparkles")
                    .font(.headline)
                    .foregroundStyle(.purple)
                    .padding(.horizontal, 20)
                
                FormattedMarkdownView(markdown: card.markdown)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color(nsColor: .controlBackgroundColor))
                    )
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)
            }
        }
        .background(Color(nsColor: .textBackgroundColor))
    }
}

// MARK: - 左ペイン: カード行

private struct CardRow: View {
    let card: Card

    var body: some View {
        HStack(spacing: 8) {
            // 音声アイコン（音声がある場合のみ表示）
            if card.audioFileName != nil {
                Image(systemName: "speaker.wave.2.fill")
                    .foregroundStyle(.blue)
                    .font(.caption)
                    .help("Audio saved")
            }
            
            // 英文・単語
            Text(card.sourceText.replacingOccurrences(of: "\n", with: " "))
                .font(.body)
                .lineLimit(1)
            
            Spacer()
            
            // 作成日時
            Text(card.createdAt, style: .date)
                .foregroundStyle(.secondary)
                .font(.caption)
        }
        .padding(.vertical, 4)
    }
}

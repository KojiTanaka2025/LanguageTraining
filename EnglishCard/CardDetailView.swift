import SwiftUI

/// カードの詳細を表示するビュー
struct CardDetailView: View {
    let card: Card
    
    @EnvironmentObject private var settings: AppSettings
    @StateObject private var audioPlayer = AudioPlayerService.shared
    
    @State private var isLoadingAudio = false
    @State private var errorMessage: String?
    
    var body: some View {
        VStack(spacing: 0) {
            // ヘッダー
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("学習カード詳細")
                        .font(.title2)
                        .bold()
                    Text("作成日時: \(card.createdAt.formatted(date: .long, time: .shortened))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
            }
            .padding(20)
            
            Divider()
            
            // コンテンツエリア
            VStack(spacing: 0) {
                // 元の英文
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Label("元の英文・単語", systemImage: "textformat.abc")
                            .font(.headline)
                            .foregroundStyle(.blue)
                        
                        Spacer()
                        
                        // 音声再生ボタン
                        Button(action: playPronunciation) {
                            HStack(spacing: 4) {
                                if isLoadingAudio {
                                    ProgressView()
                                        .controlSize(.small)
                                        .frame(width: 14, height: 14)
                                } else if audioPlayer.isPlaying && audioPlayer.currentText == card.sourceText {
                                    Image(systemName: "speaker.wave.2.fill")
                                } else {
                                    Image(systemName: card.audioFileName != nil ? "speaker.wave.2.fill" : "speaker.wave.2")
                                }
                                Text(card.audioFileName != nil ? "発音を聞く（保存済み）" : "発音を聞く")
                                    .font(.caption)
                            }
                        }
                        .disabled(isLoadingAudio || (audioPlayer.isPlaying && audioPlayer.currentText == card.sourceText))
                        .buttonStyle(.bordered)
                    }
                    
                    ScrollView {
                        Text(card.sourceText)
                            .font(.title3)
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(12)
                    }
                    .frame(maxHeight: 100)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color(nsColor: .controlBackgroundColor))
                    )
                    
                    // エラーメッセージ
                    if let errorMessage {
                        HStack(spacing: 4) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(.orange)
                            Text(errorMessage)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.top, 4)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                
                Divider()
                    .padding(.vertical, 16)
                
                // Markdown解説
                VStack(alignment: .leading, spacing: 8) {
                    Label("AI解説", systemImage: "sparkles")
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
        }
    }
    
    // MARK: - Actions
    
    private func playPronunciation() {
        Task {
            isLoadingAudio = true
            errorMessage = nil
            
            do {
                // 保存済みの音声があればそれを再生
                if let audioURL = card.audioFileURL(),
                   FileManager.default.fileExists(atPath: audioURL.path) {
                    // 保存済み音声を再生（削除しない）
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
                    
                    // 音声ファイルを取得
                    let audioURL = try await client.textToSpeech(
                        text: card.sourceText,
                        voice: "onyx",
                        speed: 0.9
                    )
                    
                    // 再生（一時ファイルなので削除）
                    try audioPlayer.play(fileURL: audioURL, text: card.sourceText, deleteAfterPlay: true)
                }
                
            } catch let error as OpenAIError {
                errorMessage = error.errorDescription
            } catch {
                errorMessage = "音声の取得に失敗しました: \(error.localizedDescription)"
            }
            
            isLoadingAudio = false
        }
    }
}


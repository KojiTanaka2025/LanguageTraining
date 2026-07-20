import SwiftUI
import AppKit
import Combine

struct ExplainView: View {
    @EnvironmentObject private var store: CardStore
    @EnvironmentObject private var settings: AppSettings

    @State private var clipboardText: String = ""
    @State private var markdown: String = ""

    @State private var isLoading = false
    @State private var errorMessage: String?

    @State private var didSave = false
    
    // 音声再生関連
    @StateObject private var audioPlayer = AudioPlayerService.shared
    @State private var isLoadingAudio = false
    @State private var audioErrorMessage: String?
    @State private var lastGeneratedAudioURL: URL? // 最後に生成した音声の一時URL
    @State private var saveAudioWithCard = true // 音声をカードに保存するか
    
    // 初回起動フラグ
    @State private var hasLoadedOnce = false

    var body: some View {
        VStack(spacing: 0) {
            // 上部：入力エリア
            VStack(alignment: .leading, spacing: 12) {
                GroupBox("Clipboard") {
                    VStack(alignment: .leading, spacing: 8) {
                        TextEditor(text: $clipboardText)
                            .font(.body)
                            .frame(minHeight: 72, idealHeight: 96, maxHeight: 120)

                        HStack {
                            Button("Load Clipboard and Explain") {
                                Task {
                                    await loadAndExplain()
                                }
                            }
                            .keyboardShortcut(.return, modifiers: [.command])
                            .disabled(isLoading || isLoadingAudio)
                            
                            // 音声再生ボタン
                            Button(action: playPronunciation) {
                                HStack(spacing: 4) {
                                    if isLoadingAudio {
                                        ProgressView()
                                            .controlSize(.small)
                                            .frame(width: 12, height: 12)
                                    } else if audioPlayer.isPlaying && audioPlayer.currentText == clipboardText {
                                        Image(systemName: "speaker.wave.2.fill")
                                    } else {
                                        Image(systemName: "speaker.wave.2")
                                    }
                                }
                            }
                            .disabled(
                                clipboardText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                                isLoadingAudio ||
                                (audioPlayer.isPlaying && audioPlayer.currentText == clipboardText)
                            )
                            .help("Listen to the pasted text")

                            Spacer()
                        }
                    }
                    .padding(.top, 4)
                }

                if let errorMessage {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(errorMessage)
                            .foregroundStyle(.red)
                            .font(.callout)
                            .textSelection(.enabled)
                            .padding(8)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(Color.red.opacity(0.1))
                            )
                        
                        // デバッグ情報
                        if let debugURL = constructedAPIURL {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Debug Info:")
                                    .font(.caption)
                                    .bold()
                                Text("Base URL: \(settings.openAIBaseURL)")
                                    .font(.caption)
                                    .textSelection(.enabled)
                                Text("Resolved URL: \(debugURL)")
                                    .font(.caption)
                                    .textSelection(.enabled)
                            }
                            .foregroundStyle(.secondary)
                            .padding(8)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(Color.secondary.opacity(0.1))
                            )
                        }
                    }
                }

                if let audioErrorMessage {
                    HStack(spacing: 6) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                        Text(audioErrorMessage)
                            .foregroundStyle(.secondary)
                            .font(.callout)
                            .textSelection(.enabled)
                    }
                    .padding(8)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.orange.opacity(0.12))
                    )
                }

                if didSave {
                    Text("Saved to your library.")
                        .foregroundStyle(.secondary)
                        .font(.callout)
                }

            }
            .padding(16)
            .frame(maxWidth: .infinity)

            Divider()

            // 下部：解説表示エリア
            VStack(spacing: 0) {
                HStack(alignment: .center) {
                    Text("Explanation")
                        .font(.headline)
                    Spacer()
                    
                    // 音声保存オプション
                    Toggle(isOn: $saveAudioWithCard) {
                        HStack(spacing: 4) {
                            Image(systemName: saveAudioWithCard ? "speaker.wave.2.fill" : "speaker.slash")
                            Text("Save audio")
                                .font(.caption)
                        }
                    }
                    .toggleStyle(.checkbox)
                    .help("Save audio with this card")
                    
                    if isLoading {
                        ProgressView()
                            .controlSize(.small)
                    }
                    Button("Save to Library") {
                        Task { await saveCard() }
                    }
                    .disabled(markdown.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isLoading)
                }
                .padding(16)

                Divider()

                if markdown.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "doc.text.magnifyingglass")
                            .font(.system(size: 42))
                            .foregroundStyle(.secondary)
                        Text("No explanation yet")
                            .font(.title3)
                            .bold()
                        Text("Load text in any language, including Vietnamese, and generate an AI explanation.")
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: 420)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(40)
                } else {
                    FormattedMarkdownView(markdown: markdown)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color(nsColor: .textBackgroundColor))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .onAppear {
            // 初回のみクリップボードを読み込む（API呼び出しはしない）
            if !hasLoadedOnce {
                hasLoadedOnce = true
                loadClipboardOnly()
            }
        }
    }
    
    // MARK: - Methods
    
    /// クリップボードのみ読み込む（API呼び出しなし）
    private func loadClipboardOnly() {
        cleanupTempAudio()
        
        let pb = NSPasteboard.general
        if let text = pb.string(forType: .string)?.trimmingCharacters(in: .whitespacesAndNewlines),
           !text.isEmpty {
            clipboardText = text
        }
    }
    
    /// クリップボードから読み込んで、音声と解説を並行取得
    private func loadAndExplain() async {
        didSave = false
        errorMessage = nil
        audioErrorMessage = nil
        
        // 古い一時音声ファイルをクリーンアップ
        cleanupTempAudio()
        
        // クリップボードから読み込み
        let pb = NSPasteboard.general
        guard let text = pb.string(forType: .string)?.trimmingCharacters(in: .whitespacesAndNewlines),
              !text.isEmpty else {
            clipboardText = ""
            return
        }
        
        clipboardText = text
        
        // APIキーチェック
        guard !settings.apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            errorMessage = "API key is not set. Open Settings and enter your API key."
            return
        }
        
        // 音声と解説を並行取得
        isLoading = true
        isLoadingAudio = true
        
        async let audioTask: URL? = fetchAudio(text: text)
        async let explanationTask: String? = fetchExplanationText(text: text)
        
        let (audio, explanation) = await (audioTask, explanationTask)
        
        // 結果を反映
        if let audio = audio {
            lastGeneratedAudioURL = audio
            // 音声を自動再生
            try? audioPlayer.play(fileURL: audio, text: text, deleteAfterPlay: false)
        }
        
        if let explanation = explanation {
            markdown = explanation
        }
        
        isLoading = false
        isLoadingAudio = false
    }
    
    /// 音声を取得（エラーは内部でハンドリング）
    private func fetchAudio(text: String) async -> URL? {
        do {
            return try await client().textToSpeech(
                text: text,
                voice: OpenAIClient.defaultTTSVoice,
                speed: 0.9
            )
        } catch let error as OpenAIError {
            audioErrorMessage = error.errorDescription
            return nil
        } catch {
            audioErrorMessage = "Failed to generate audio: \(error.localizedDescription)"
            return nil
        }
    }
    
    /// 解説を取得（エラーは内部でハンドリング）
    private func fetchExplanationText(text: String) async -> String? {
        do {
            return try await client().explainEnglish(
                text: text,
                explanationLanguage: settings.explanationLanguage
            )
        } catch {
            errorMessage = error.localizedDescription
            return nil
        }
    }
    
    /// 一時音声ファイルをクリーンアップ
    private func cleanupTempAudio() {
        if let tempURL = lastGeneratedAudioURL {
            try? FileManager.default.removeItem(at: tempURL)
            lastGeneratedAudioURL = nil
        }
    }

    private func client() throws -> OpenAIClient {
        let trimmed = settings.openAIBaseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let base = URL(string: trimmed) else { throw OpenAIError.invalidBaseURL }
        return OpenAIClient(baseURL: base, apiKey: settings.apiKey, model: settings.openAIModel)
    }

    private func saveCard() async {
        didSave = false
        errorMessage = nil
        let source = clipboardText.trimmingCharacters(in: .whitespacesAndNewlines)
        let md = markdown.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !source.isEmpty, !md.isEmpty else { return }
        
        do {
            var audioFileName: String? = nil
            
            // 音声保存オプションが有効な場合
            if saveAudioWithCard {
                // 既に生成済みの音声があればそれを使用、なければ新規生成
                let audioURL: URL
                if let existing = lastGeneratedAudioURL {
                    audioURL = existing
                } else {
                    audioURL = try await client().textToSpeech(
                        text: source,
                        voice: OpenAIClient.defaultTTSVoice,
                        speed: 0.9
                    )
                }
                
                // カードIDを生成
                let cardID = UUID()
                
                // 音声ファイルを永続化
                audioFileName = try store.saveAudioFile(from: audioURL, for: cardID)
                
                // 一時ファイルを削除
                try? FileManager.default.removeItem(at: audioURL)
                lastGeneratedAudioURL = nil
                
                // カードを保存（カスタムIDと音声ファイル名を指定）
                let card = Card(
                    id: cardID,
                    sourceText: source,
                    markdown: md,
                    audioFileName: audioFileName
                )
                try store.appendCard(card)
            } else {
                // 音声なしで保存（念のため一時ファイルがあればクリーンアップ）
                cleanupTempAudio()
                try await store.appendCard(sourceText: source, markdown: md, audioFileName: nil)
            }
            
            didSave = true
        } catch {
            errorMessage = error.localizedDescription
            // エラー時も一時ファイルをクリーンアップ
            cleanupTempAudio()
        }
    }
    
    private var constructedAPIURL: String? {
        let trimmed = settings.openAIBaseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let base = URL(string: trimmed) else { return nil }
        var urlString = base.absoluteString
        while urlString.hasSuffix("/") {
            urlString.removeLast()
        }
        urlString += "/v1/chat/completions"
        return urlString
    }
    
    // MARK: - Audio Playback
    
    private func playPronunciation() {
        Task {
            let text = clipboardText.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty else { return }
            
            // 既に音声が生成済みの場合は再生するだけ
            if let existingAudio = lastGeneratedAudioURL,
               FileManager.default.fileExists(atPath: existingAudio.path) {
                try? audioPlayer.play(fileURL: existingAudio, text: text, deleteAfterPlay: false)
                return
            }
            
            // 音声が未生成の場合は新規取得
            isLoadingAudio = true
            audioErrorMessage = nil
            
            do {
                // 音声ファイルを取得
                let audioURL = try await client().textToSpeech(
                    text: text,
                    voice: OpenAIClient.defaultTTSVoice,
                    speed: 0.9
                )
                
                // 一時URLを保存（後でカード保存時に使用）
                lastGeneratedAudioURL = audioURL
                
                // 再生（一時ファイルは保存時まで保持するため削除しない）
                try audioPlayer.play(fileURL: audioURL, text: text, deleteAfterPlay: false)
                
            } catch let error as OpenAIError {
                audioErrorMessage = error.errorDescription
            } catch {
            audioErrorMessage = "Failed to generate audio: \(error.localizedDescription)"
            }
            
            isLoadingAudio = false
        }
    }
}

import SwiftUI
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
    @ObservedObject private var audioPlayer = AudioPlayerService.shared
    @State private var isLoadingAudio = false
    @State private var audioErrorMessage: String?
    @State private var lastGeneratedAudioURL: URL?
    @State private var lastGeneratedAudioText: String?
    @State private var saveAudioWithCard = true // 音声をカードに保存するか
    @State private var selectedCategory: String = ""
    @State private var isPresentingNewTag = false
    
    // 初回起動フラグ
    @State private var hasLoadedOnce = false

    private var sourceText: String {
        clipboardText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var hasExplanation: Bool {
        !markdown.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var isPlayingCurrentText: Bool {
        audioPlayer.isPlaying && audioPlayer.currentText == clipboardText
    }

    var body: some View {
        Group {
            #if os(macOS)
            VSplitView {
                sourcePane
                    .frame(minHeight: 160)
                    .background(SplitViewPersistence(key: LayoutPersistence.explainSplitKey))

                explanationPane
                    .frame(minHeight: 280)
            }
            #else
            VStack(spacing: 0) {
                sourcePane
                    .frame(minHeight: 180, maxHeight: 260)
                Divider()
                explanationPane
            }
            #endif
        }
        .onAppear {
            if !hasLoadedOnce {
                hasLoadedOnce = true
                loadClipboardOnly()
                let last = settings.lastSaveCategory
                if last.isEmpty || store.tags.contains(where: { $0.name == last }) {
                    selectedCategory = last
                } else {
                    selectedCategory = LibraryTag.builtInDefaults[0].name
                }
            }
        }
        .sheet(isPresented: $isPresentingNewTag) {
            NewTagSheet(isPresented: $isPresentingNewTag) { name, colorHex in
                do {
                    guard try store.addTag(name: name, colorHex: colorHex) != nil else { return false }
                    selectedCategory = name
                    settings.lastSaveCategory = name
                    return true
                } catch {
                    errorMessage = error.localizedDescription
                    return false
                }
            }
        }
        .onChange(of: didSave) { _, saved in
            guard saved else { return }
            Task {
                try? await Task.sleep(for: .seconds(2.5))
                didSave = false
            }
        }
    }

    private var sourcePane: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text("Source text")
                    .font(.headline)
                Spacer()
                if !sourceText.isEmpty {
                    Text("\(sourceText.count) characters")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }

            ZStack(alignment: .topLeading) {
                TextEditor(text: $clipboardText)
                    .font(.body)
                    .scrollContentBackground(.hidden)
                    .padding(4)

                if clipboardText.isEmpty {
                    Text("Paste a word, phrase, or sentence in any language.")
                        .foregroundStyle(.tertiary)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 12)
                        .allowsHitTesting(false)
                }
            }
            .background(Color.appTextBackground, in: RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.appSeparator.opacity(0.5), lineWidth: 1)
            )

            HStack(spacing: 8) {
                Button("Load Clipboard", action: loadClipboardOnly)
                    .disabled(isLoading || isLoadingAudio)
                    .help("Replace the text field with the current clipboard contents")

                Button(action: togglePronunciation) {
                    Label {
                        Text(isPlayingCurrentText ? "Stop" : "Listen")
                    } icon: {
                        if isLoadingAudio {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            Image(systemName: isPlayingCurrentText ? "stop.fill" : "speaker.wave.2")
                        }
                    }
                }
                .disabled(sourceText.isEmpty || isLoadingAudio)
                .help("Play pronunciation of the source text")

                Spacer()

                Button("Explain") {
                    Task { await explainCurrentText() }
                }
                .keyboardShortcut(.return, modifiers: [.command])
                .buttonStyle(.borderedProminent)
                .disabled(sourceText.isEmpty || isLoading || isLoadingAudio)
                .help("Generate an explanation from the text in the editor")
            }

            if let errorMessage {
                notice(errorMessage, tone: .error)
            }

            if let audioErrorMessage {
                notice(audioErrorMessage, tone: .warning)
            }

            if didSave {
                Label("Saved to your library.", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .font(.callout)
            }
        }
        .padding(16)
    }

    private var explanationPane: some View {
        VStack(spacing: 0) {
            HStack(alignment: .center, spacing: 12) {
                Text("Explanation")
                    .font(.headline)
                if isLoading {
                    ProgressView()
                        .controlSize(.small)
                    Text("Generating…")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()

                Toggle(isOn: $saveAudioWithCard) {
                    Text("Save audio")
                }
                #if os(macOS)
                .toggleStyle(.checkbox)
                #endif
                .help("Save pronunciation audio with this card")

                Menu {
                    ForEach(store.tags) { tag in
                        Button {
                            selectedCategory = tag.name
                        } label: {
                            tagMenuLabel(tag.name, colorHex: tag.colorHex, selected: selectedCategory == tag.name)
                        }
                    }
                    Button {
                        selectedCategory = LibraryTag.uncategorizedID
                    } label: {
                        tagMenuLabel(
                            LibraryTag.uncategorizedLabel,
                            colorHex: LibraryTag.defaultColorHex,
                            selected: selectedCategory.isEmpty
                        )
                    }
                    Divider()
                    Button("New Tag…") {
                        isPresentingNewTag = true
                    }
                } label: {
                    HStack(spacing: 6) {
                        TagSwatch(
                            colorHex: selectedCategory.isEmpty
                                ? LibraryTag.defaultColorHex
                                : store.colorHex(forCategory: selectedCategory)
                        )
                        Text(LibraryTag.displayName(selectedCategory))
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                .help("Tag saved with this card")

                Button("Save to Library") {
                    Task { await saveCard() }
                }
                .keyboardShortcut("s", modifiers: [.command])
                .buttonStyle(.borderedProminent)
                .disabled(!hasExplanation || isLoading || store.loadErrorMessage != nil)
                .help("Save this card to your library")
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            Divider()

            if isLoading && !hasExplanation {
                VStack(spacing: 10) {
                    ProgressView()
                    Text("Generating explanation…")
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if !hasExplanation {
                VStack(spacing: 8) {
                    Image(systemName: "text.book.closed")
                        .font(.system(size: 36))
                        .foregroundStyle(.tertiary)
                    Text("No explanation yet")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                    Text("Paste text, then press Explain.")
                        .font(.callout)
                        .foregroundStyle(.tertiary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(40)
            } else {
                FormattedMarkdownView(markdown: Card.displayMarkdown(from: markdown, sourceText: sourceText))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.appTextBackground)
            }
        }
    }

    private func tagMenuLabel(_ name: String, colorHex: String, selected: Bool) -> some View {
        Label {
            Text(name)
        } icon: {
            if selected {
                Image(systemName: "checkmark")
            } else {
                TagSwatch(colorHex: colorHex)
            }
        }
    }

    private enum NoticeTone {
        case error
        case warning
    }

    private func notice(_ message: String, tone: NoticeTone) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: tone == .error ? "exclamationmark.octagon.fill" : "exclamationmark.triangle.fill")
                .foregroundStyle(tone == .error ? Color.red : Color.orange)
            Text(message)
                .font(.callout)
                .textSelection(.enabled)
                .foregroundStyle(.primary)
            Spacer(minLength: 0)
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill((tone == .error ? Color.red : Color.orange).opacity(0.1))
        )
    }
    
    // MARK: - Methods
    
    /// クリップボードのみ読み込む（API呼び出しなし）
    private func loadClipboardOnly() {
        cleanupTempAudio()
        
        if let text = Clipboard.string()?.trimmingCharacters(in: .whitespacesAndNewlines),
           !text.isEmpty {
            clipboardText = text
        }
    }
    
    /// エディタの本文から音声と解説を並行取得
    private func explainCurrentText() async {
        didSave = false
        errorMessage = nil
        audioErrorMessage = nil

        let text = clipboardText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        if lastGeneratedAudioText != text {
            cleanupTempAudio()
        }
        
        guard !settings.apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            errorMessage = "API key is not set. Open Settings and enter your API key."
            return
        }
        
        isLoading = true
        let needsNewAudio = matchingGeneratedAudioURL(for: text) == nil
        if needsNewAudio {
            isLoadingAudio = true
        }
        
        async let audioTask: URL? = audioURL(for: text)
        async let explanationTask: ExplanationResult? = fetchExplanationText(text: text)
        
        let (audio, explanation) = await (audioTask, explanationTask)
        
        if let audio = audio {
            lastGeneratedAudioURL = audio
            lastGeneratedAudioText = text
            try? audioPlayer.play(fileURL: audio, text: text, deleteAfterPlay: false)
        }
        
        if let explanation = explanation {
            let chargedForNewAudio = needsNewAudio && audio != nil
            let chatUSD = APICost.chatUSD(model: settings.openAIModel, usage: explanation.usage)
            let audioUSD = chargedForNewAudio ? APICost.ttsUSD(spokenText: text) : 0
            markdown = APICost.appendingFooter(
                to: Card.displayMarkdown(from: explanation.markdown),
                usd: chatUSD + audioUSD,
                explanationLanguage: settings.explanationLanguage,
                includedAudio: chargedForNewAudio
            )
        }
        
        isLoading = false
        isLoadingAudio = false
    }
    
    /// 一致する生成済み音声があればそれを返し、なければ新規生成する
    private func audioURL(for text: String) async -> URL? {
        if let existing = matchingGeneratedAudioURL(for: text) {
            return existing
        }
        return await fetchAudio(text: text)
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
    private func fetchExplanationText(text: String) async -> ExplanationResult? {
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
        lastGeneratedAudioText = nil
    }

    private func matchingGeneratedAudioURL(for text: String) -> URL? {
        guard lastGeneratedAudioText == text,
              let existing = lastGeneratedAudioURL,
              FileManager.default.fileExists(atPath: existing.path) else {
            return nil
        }
        return existing
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
        let md = Card.displayMarkdown(from: markdown)
        let category = LibraryTag.normalizedName(selectedCategory)
        guard !source.isEmpty, !md.isEmpty else { return }
        
        do {
            var audioFileName: String? = nil
            
            // 音声保存オプションが有効な場合
            if saveAudioWithCard {
                let audioURL: URL
                if let existing = matchingGeneratedAudioURL(for: source) {
                    audioURL = existing
                } else {
                    audioURL = try await client().textToSpeech(
                        text: source,
                        voice: OpenAIClient.defaultTTSVoice,
                        speed: 0.9
                    )
                    lastGeneratedAudioURL = audioURL
                    lastGeneratedAudioText = source
                }
                
                // カードIDを生成
                let cardID = UUID()
                
                // 音声ファイルを永続化
                audioFileName = try store.saveAudioFile(from: audioURL, for: cardID)
                
                // 一時ファイルを削除
                try? FileManager.default.removeItem(at: audioURL)
                lastGeneratedAudioURL = nil
                lastGeneratedAudioText = nil
                
                // カードを保存（カスタムIDと音声ファイル名を指定）
                let card = Card(
                    id: cardID,
                    sourceText: source,
                    markdown: md,
                    audioFileName: audioFileName,
                    category: category
                )
                try store.appendCard(card)
            } else {
                // 音声なしで保存（念のため一時ファイルがあればクリーンアップ）
                cleanupTempAudio()
                try await store.appendCard(
                    sourceText: source,
                    markdown: md,
                    audioFileName: nil,
                    category: category
                )
            }

            settings.lastSaveCategory = category
            didSave = true
        } catch {
            errorMessage = error.localizedDescription
            // エラー時も一時ファイルをクリーンアップ
            cleanupTempAudio()
        }
    }

    private func togglePronunciation() {
        if isPlayingCurrentText {
            audioPlayer.stop()
            return
        }
        playPronunciation()
    }
    
    private func playPronunciation() {
        Task {
            let text = clipboardText.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty else { return }
            
            if let existingAudio = matchingGeneratedAudioURL(for: text) {
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
                
                lastGeneratedAudioURL = audioURL
                lastGeneratedAudioText = text
                
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

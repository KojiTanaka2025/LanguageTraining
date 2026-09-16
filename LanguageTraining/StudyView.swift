import SwiftUI
import Combine

struct StudyView: View {
    @EnvironmentObject private var store: CardStore
    @EnvironmentObject private var settings: AppSettings

    @State private var direction: StudyDirection = .japaneseToEnglish
    @State private var tagFilter: String = LibraryTag.allFilterID
    @State private var queue: [UUID] = []
    @State private var index: Int = 0
    @State private var isShowingAnswer = false
    @State private var isInSession = false
    @State private var sessionCorrect = 0
    @State private var sessionReviewed = 0
    @State private var errorMessage: String?
    @State private var isLoadingAudio = false
    @ObservedObject private var audioPlayer = AudioPlayerService.shared

    var body: some View {
        NavigationStack {
            Group {
                if isInSession {
                    sessionBody
                } else {
                    homeBody
                }
            }
            .navigationTitle("Study")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .safeAreaInset(edge: .bottom) {
                if let errorMessage {
                    HStack {
                        Text(errorMessage)
                            .foregroundStyle(.red)
                            .font(.callout)
                        Spacer()
                        Button("Close") { self.errorMessage = nil }
                    }
                    .padding(12)
                    .background(.bar)
                }
            }
        }
    }

    private var stats: StudyStatsSummary { store.studyStats }

    private var homeBody: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                StudyStatsDashboard(stats: stats)

                VStack(alignment: .leading, spacing: 10) {
                    Text("Mode")
                        .font(.headline)
                    Picker("Mode", selection: $direction) {
                        ForEach(StudyDirection.allCases) { mode in
                            Text(mode.title).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    Text(direction.subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                VStack(alignment: .leading, spacing: 10) {
                    Text("Tag filter")
                        .font(.headline)
                    Picker("Tag", selection: $tagFilter) {
                        Text(LibraryTag.allFilterLabel).tag(LibraryTag.allFilterID)
                        ForEach(store.tags) { tag in
                            Text(tag.name).tag(tag.name)
                        }
                        Text(LibraryTag.uncategorizedLabel).tag(LibraryTag.uncategorizedID)
                    }
                    .pickerStyle(.menu)
                }

                Text("Cards due today are shown first. Weaker cards and a little randomness are mixed in so the order is not fixed.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Button {
                    startSession()
                } label: {
                    Label("Start Study", systemImage: "rectangle.on.rectangle.angled")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(stats.studyableCards == 0)

                if stats.studyableCards == 0 {
                    Text("Study needs cards with a Japanese meaning line (自然な日本語訳). Create cards in Explain with Explanation Language set to Japanese.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(20)
            .frame(maxWidth: 720)
            .frame(maxWidth: .infinity)
        }
        .background(Color.appTextBackground.opacity(0.35))
    }

    @ViewBuilder
    private var sessionBody: some View {
        if queue.isEmpty || index >= queue.count {
            sessionFinished
        } else if let card = store.cards.first(where: { $0.id == queue[index] }),
                  let content = CardStudyContent.make(from: card) {
            let sides = content.sides(for: direction)
            VStack(spacing: 0) {
                HStack {
                    Text("\(index + 1) / \(queue.count)")
                        .font(.subheadline.monospacedDigit())
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(direction.title)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Button("End") {
                        endSession()
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)

                ProgressView(value: Double(index), total: Double(max(queue.count, 1)))
                    .padding(.horizontal, 16)

                Spacer(minLength: 12)

                flashcard(prompt: sides.prompt, answer: sides.answer, card: card)
                    .padding(.horizontal, 20)

                Spacer(minLength: 12)

                sessionControls(card: card, english: content.english)
                    .padding(16)
            }
        } else {
            VStack(spacing: 12) {
                Text("This card could not be studied.")
                Button("Skip") { advance() }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private var sessionFinished: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 44))
                .foregroundStyle(.green)
            Text("Session complete")
                .font(.title2)
            Text("Reviewed \(sessionReviewed) · Remembered \(sessionCorrect)")
                .foregroundStyle(.secondary)
            Button("Back to Study") {
                endSession()
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func flashcard(prompt: String, answer: String, card: Card) -> some View {
        VStack(spacing: 16) {
            Text(isShowingAnswer ? "Answer" : "Prompt")
                .font(.caption)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)

            Text(isShowingAnswer ? answer : prompt)
                .font(.title2)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .padding(24)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.appTextBackground)
                        .shadow(color: .black.opacity(0.06), radius: 8, y: 2)
                )
                .animation(.easeInOut(duration: 0.18), value: isShowingAnswer)

            if !card.category.isEmpty {
                TagLabel(name: card.category, colorHex: store.colorHex(forCategory: card.category), font: .caption)
            }
        }
        .frame(maxWidth: 640)
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
        .onTapGesture {
            guard !isShowingAnswer else { return }
            withAnimation { isShowingAnswer = true }
        }
    }

    private func sessionControls(card: Card, english: String) -> some View {
        VStack(spacing: 12) {
            HStack(spacing: 10) {
                Button {
                    Task { await playEnglish(card: card, english: english) }
                } label: {
                    Label(
                        audioPlayer.isPlaying && audioPlayer.currentText == english ? "Stop" : "Pronounce",
                        systemImage: audioPlayer.isPlaying && audioPlayer.currentText == english ? "stop.fill" : "speaker.wave.2"
                    )
                }
                .disabled(isLoadingAudio)

                if isLoadingAudio {
                    ProgressView()
                        .controlSize(.small)
                }

                Spacer()

                if !isShowingAnswer {
                    Button("Show Answer") {
                        withAnimation { isShowingAnswer = true }
                        if direction == .japaneseToEnglish {
                            Task { await playEnglish(card: card, english: english) }
                        }
                    }
                    .buttonStyle(.borderedProminent)
                }
            }

            if isShowingAnswer {
                HStack(spacing: 12) {
                    Button {
                        grade(.again)
                    } label: {
                        Text("Again")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)

                    Button {
                        grade(.good)
                    } label: {
                        Text("Got it")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
        }
        .frame(maxWidth: 640)
        .frame(maxWidth: .infinity)
    }

    private func startSession() {
        let filter = tagFilter == LibraryTag.allFilterID ? nil : tagFilter
        queue = store.studyQueue(tagFilter: filter)
        index = 0
        isShowingAnswer = false
        sessionCorrect = 0
        sessionReviewed = 0
        isInSession = true
        audioPlayer.stop()

        if queue.isEmpty {
            errorMessage = "No studyable cards match this filter."
            isInSession = false
        } else if direction == .englishToJapanese, let card = store.cards.first(where: { $0.id == queue[0] }) {
            Task {
                if let content = CardStudyContent.make(from: card) {
                    await playEnglish(card: card, english: content.english)
                }
            }
        }
    }

    private func endSession() {
        isInSession = false
        queue = []
        index = 0
        isShowingAnswer = false
        audioPlayer.stop()
    }

    private func grade(_ grade: StudyGrade) {
        guard index < queue.count else { return }
        let cardID = queue[index]
        do {
            try store.recordStudy(cardID: cardID, grade: grade)
            sessionReviewed += 1
            if grade == .good { sessionCorrect += 1 }
            advance()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func advance() {
        audioPlayer.stop()
        isShowingAnswer = false
        index += 1
        if index < queue.count,
           direction == .englishToJapanese,
           let card = store.cards.first(where: { $0.id == queue[index] }),
           let content = CardStudyContent.make(from: card) {
            Task { await playEnglish(card: card, english: content.english) }
        }
    }

    private func playEnglish(card: Card, english: String) async {
        if audioPlayer.isPlaying && audioPlayer.currentText == english {
            audioPlayer.stop()
            return
        }
        isLoadingAudio = true
        defer { isLoadingAudio = false }
        do {
            if let url = card.audioFileURL() {
                try? await CoordinatedFile.ensureLocalCopy(at: url)
                if FileManager.default.fileExists(atPath: url.path) {
                    try audioPlayer.play(fileURL: url, text: english)
                    return
                }
            }
            let client = try makeClient()
            let temp = try await client.textToSpeech(
                text: english,
                voice: OpenAIClient.defaultTTSVoice,
                speed: 0.9
            )
            let fileName = try store.saveAudioFile(from: temp, for: card.id)
            try? FileManager.default.removeItem(at: temp)
            var updated = card
            updated.audioFileName = fileName
            try store.updateCard(updated)
            if let saved = updated.audioFileURL() {
                try audioPlayer.play(fileURL: saved, text: english)
            }
        } catch {
            errorMessage = "Could not play pronunciation: \(error.localizedDescription)"
        }
    }

    private func makeClient() throws -> OpenAIClient {
        let trimmed = settings.openAIBaseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let base = URL(string: trimmed) else { throw OpenAIError.invalidBaseURL }
        return OpenAIClient(baseURL: base, apiKey: settings.apiKey, model: settings.openAIModel)
    }
}

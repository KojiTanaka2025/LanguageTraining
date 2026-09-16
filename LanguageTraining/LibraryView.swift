import SwiftUI
import Combine

struct LibraryView: View {
    @EnvironmentObject private var store: CardStore
    @EnvironmentObject private var settings: AppSettings

    @State private var query: String = ""
    @State private var selected: Card.ID?
    @State private var categoryFilter: String = LibraryTag.allFilterID
    @State private var isPresentingNewTag = false
    @State private var newTagTargetCardID: Card.ID?
    
    @State private var errorMessage: String?
    @State private var cardPendingDeletion: Card?
    
    @ObservedObject private var audioPlayer = AudioPlayerService.shared
    @State private var isLoadingAudio = false
    @State private var audioErrorMessage: String?

    var body: some View {
        NavigationStack {
            Group {
                if store.isLoading && store.cards.isEmpty {
                    VStack(spacing: 10) {
                        ProgressView()
                        Text("Loading library…")
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if store.cards.isEmpty, let loadError = store.loadErrorMessage {
                    emptyState(
                        icon: "exclamationmark.triangle",
                        title: "Library could not be loaded",
                        message: loadError,
                        showsRetry: true
                    )
                } else if filtered.isEmpty && (!query.isEmpty || categoryFilter != LibraryTag.allFilterID) {
                    emptyState(
                        icon: "magnifyingglass",
                        title: "No results",
                        message: categoryFilter == LibraryTag.allFilterID
                            ? "Try a different keyword."
                            : "No cards tagged “\(LibraryTag.displayName(categoryFilter))”."
                    )
                } else if store.cards.isEmpty {
                    emptyState(
                        icon: "tray",
                        title: "No cards yet",
                        message: "Create a card from the Explain tab."
                    )
                } else {
                    librarySplit
                }
            }
            .navigationTitle("Library")
            .searchable(text: $query, prompt: "Search cards")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Button {
                            categoryFilter = LibraryTag.allFilterID
                        } label: {
                            filterMenuLabel(LibraryTag.allFilterLabel, colorHex: nil, selected: categoryFilter == LibraryTag.allFilterID)
                        }
                        ForEach(store.tags) { tag in
                            Button {
                                categoryFilter = tag.name
                            } label: {
                                filterMenuLabel(tag.name, colorHex: tag.colorHex, selected: categoryFilter == tag.name)
                            }
                        }
                        Button {
                            categoryFilter = LibraryTag.uncategorizedID
                        } label: {
                            filterMenuLabel(
                                LibraryTag.uncategorizedLabel,
                                colorHex: LibraryTag.defaultColorHex,
                                selected: categoryFilter == LibraryTag.uncategorizedID
                            )
                        }
                        Divider()
                        Button("New Tag…") {
                            newTagTargetCardID = nil
                            isPresentingNewTag = true
                        }
                    } label: {
                        HStack(spacing: 6) {
                            if categoryFilter == LibraryTag.allFilterID {
                                Text(LibraryTag.allFilterLabel)
                            } else {
                                TagSwatch(
                                    colorHex: categoryFilter.isEmpty
                                        ? LibraryTag.defaultColorHex
                                        : store.colorHex(forCategory: categoryFilter)
                                )
                                Text(LibraryTag.displayName(categoryFilter))
                            }
                            Image(systemName: "chevron.up.chevron.down")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .help("Show all cards or only one tag")
                }
                ToolbarItem(placement: .status) {
                    Text(cardCountLabel)
                        .foregroundStyle(.secondary)
                }
            }
            .onAppear {
                #if os(macOS)
                selectFirstAvailableCard()
                #endif
            }
            .onChange(of: filtered.map(\.id)) { _, _ in
                #if os(macOS)
                selectFirstAvailableCard()
                #endif
            }
            .onChange(of: categoryFilter) { _, _ in
                #if os(macOS)
                selectFirstAvailableCard()
                #endif
            }
            #if os(macOS)
            .onDeleteCommand {
                if let card = filtered.first(where: { $0.id == selected }) {
                    cardPendingDeletion = card
                }
            }
            #endif
        }
        .safeAreaInset(edge: .bottom) {
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
                .background(.bar)
            }
        }
        .sheet(isPresented: $isPresentingNewTag) {
            NewTagSheet(isPresented: $isPresentingNewTag) { name, colorHex in
                do {
                    guard try store.addTag(name: name, colorHex: colorHex) != nil else { return false }
                    if let cardID = newTagTargetCardID,
                       let card = store.cards.first(where: { $0.id == cardID }) {
                        setCategory(name, for: card)
                    }
                    newTagTargetCardID = nil
                    return true
                } catch {
                    errorMessage = error.localizedDescription
                    return false
                }
            }
        }
        .alert("Delete this card?", isPresented: Binding(
            get: { cardPendingDeletion != nil },
            set: { if !$0 { cardPendingDeletion = nil } }
        )) {
            Button("Delete", role: .destructive) {
                if let card = cardPendingDeletion {
                    deleteCard(card)
                }
                cardPendingDeletion = nil
            }
            Button("Cancel", role: .cancel) {
                cardPendingDeletion = nil
            }
        } message: {
            if let card = cardPendingDeletion {
                Text("This will delete “\(card.sourceText.replacingOccurrences(of: "\n", with: " "))”. This cannot be undone.")
            }
        }
    }

    private var librarySplit: some View {
        #if os(macOS)
        HSplitView {
            cardList
                .frame(minWidth: 260, idealWidth: 320)
                .background(SplitViewPersistence(key: LayoutPersistence.librarySplitKey))
            cardDetail
        }
        #else
        List {
            ForEach(filtered) { card in
                NavigationLink {
                    CardDetailPane(
                        card: card,
                        isLoadingAudio: $isLoadingAudio,
                        audioErrorMessage: $audioErrorMessage,
                        onPlayAudio: { playPronunciation(for: card) }
                    )
                    .navigationTitle("Card")
                    .navigationBarTitleDisplayMode(.inline)
                } label: {
                    CardRow(
                        card: card,
                        colorHex: store.colorHex(forCategory: card.category),
                        onSelectTag: { setCategory($0, for: card) },
                        onNewTag: {
                            newTagTargetCardID = card.id
                            isPresentingNewTag = true
                        }
                    )
                }
                .contextMenu {
                    Button("Copy Text") {
                        copySourceText(card.sourceText)
                    }
                    categoryMenu(for: card)
                    Button("Delete", role: .destructive) {
                        cardPendingDeletion = card
                    }
                }
            }
            .onDelete { offsets in
                if let index = offsets.first {
                    cardPendingDeletion = filtered[index]
                }
            }
        }
        .listStyle(.plain)
        #endif
    }

    @ViewBuilder
    private var cardDetail: some View {
        if let selectedCard = filtered.first(where: { $0.id == selected }) {
            CardDetailPane(
                card: selectedCard,
                isLoadingAudio: $isLoadingAudio,
                audioErrorMessage: $audioErrorMessage,
                onPlayAudio: { playPronunciation(for: selectedCard) }
            )
        } else {
            emptyState(
                icon: "sidebar.left",
                title: "Select a card",
                message: "Choose a card from the list to review it."
            )
            .background(Color.appTextBackground)
        }
    }

    private var cardCountLabel: String {
        let total = store.cards.count
        let shown = filtered.count
        if categoryFilter == LibraryTag.allFilterID,
           query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return total == 1 ? "1 card" : "\(total) cards"
        }
        return "\(shown) of \(total)"
    }

    @ViewBuilder
    private func filterMenuLabel(_ title: String, colorHex: String?, selected: Bool) -> some View {
        Label {
            Text(title)
        } icon: {
            if selected {
                Image(systemName: "checkmark")
            } else if let colorHex {
                TagSwatch(colorHex: colorHex)
            } else {
                Image(systemName: "line.3.horizontal.decrease.circle")
            }
        }
    }

    @ViewBuilder
    private func categoryMenu(for card: Card) -> some View {
        Menu("Tag") {
            ForEach(store.tags) { tag in
                Button {
                    setCategory(tag.name, for: card)
                } label: {
                    filterMenuLabel(tag.name, colorHex: tag.colorHex, selected: card.category == tag.name)
                }
            }
            Button {
                setCategory(LibraryTag.uncategorizedID, for: card)
            } label: {
                filterMenuLabel(
                    LibraryTag.uncategorizedLabel,
                    colorHex: LibraryTag.defaultColorHex,
                    selected: card.category.isEmpty
                )
            }
            Divider()
            Button("New Tag…") {
                newTagTargetCardID = card.id
                isPresentingNewTag = true
            }
        }
    }

    private var cardList: some View {
        List(selection: $selected) {
            ForEach(filtered) { card in
                CardRow(
                    card: card,
                    colorHex: store.colorHex(forCategory: card.category),
                    onSelectTag: { setCategory($0, for: card) },
                    onNewTag: {
                        newTagTargetCardID = card.id
                        isPresentingNewTag = true
                    }
                )
                    .tag(card.id)
                    .contextMenu {
                        Button("Copy Text") {
                            copySourceText(card.sourceText)
                        }
                        categoryMenu(for: card)
                        Button("Delete", role: .destructive) {
                            cardPendingDeletion = card
                        }
                    }
            }
            .onDelete { offsets in
                if let index = offsets.first {
                    cardPendingDeletion = filtered[index]
                }
            }
        }
        .listStyle(.sidebar)
    }

    private func emptyState(icon: String, title: String, message: String, showsRetry: Bool = false) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 32))
                .foregroundStyle(.tertiary)
            Text(title)
                .font(.title3)
            Text(message)
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .textSelection(.enabled)
                .frame(maxWidth: 380)
            if showsRetry {
                Button("Retry") {
                    store.reloadData()
                }
                .padding(.top, 4)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(40)
    }

    private var filtered: [Card] {
        var cards = store.cards
        if categoryFilter != LibraryTag.allFilterID {
            cards = cards.filter { $0.category == categoryFilter }
        }
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return cards }
        return cards.filter { c in
            c.sourceText.localizedCaseInsensitiveContains(q)
                || c.markdown.localizedCaseInsensitiveContains(q)
                || LibraryTag.displayName(c.category).localizedCaseInsensitiveContains(q)
        }
    }

    private func setCategory(_ category: String, for card: Card) {
        var updated = card
        updated.category = LibraryTag.normalizedName(category)
        do {
            try store.updateCard(updated)
        } catch {
            errorMessage = "Failed to update the tag: \(error.localizedDescription)"
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

    private func selectFirstAvailableCard() {
        if selected == nil || !filtered.contains(where: { $0.id == selected }) {
            selected = filtered.first?.id
        }
    }

    private func copySourceText(_ text: String) {
        Clipboard.setString(text)
    }
    
    private func playPronunciation(for card: Card) {
        Task {
            isLoadingAudio = true
            audioErrorMessage = nil

            let current = store.cards.first(where: { $0.id == card.id }) ?? card
            
            do {
                if let audioURL = current.audioFileURL() {
                    try? await CoordinatedFile.ensureLocalCopy(at: audioURL)
                    if FileManager.default.fileExists(atPath: audioURL.path) {
                        try audioPlayer.play(fileURL: audioURL, text: current.sourceText, deleteAfterPlay: false)
                        isLoadingAudio = false
                        return
                    }
                }

                guard !settings.apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                    audioErrorMessage = "API key is not set. Open Settings and enter your API key."
                    isLoadingAudio = false
                    return
                }

                guard let baseURL = URL(string: settings.openAIBaseURL) else {
                    throw OpenAIError.invalidBaseURL
                }

                let client = OpenAIClient(
                    baseURL: baseURL,
                    apiKey: settings.apiKey,
                    model: settings.openAIModel
                )

                let audioURL = try await client.textToSpeech(
                    text: current.sourceText,
                    voice: OpenAIClient.defaultTTSVoice,
                    speed: 0.9
                )

                let fileName = try store.saveAudioFile(from: audioURL, for: current.id)
                var updated = current
                updated.audioFileName = fileName
                try store.updateCard(updated)
                try? FileManager.default.removeItem(at: audioURL)

                if let savedURL = updated.audioFileURL() {
                    try? await CoordinatedFile.ensureLocalCopy(at: savedURL)
                    try audioPlayer.play(fileURL: savedURL, text: updated.sourceText, deleteAfterPlay: false)
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
    
    @ObservedObject private var audioPlayer = AudioPlayerService.shared
    
    var body: some View {
        #if os(macOS)
        macBody
        #else
        iOSBody
        #endif
    }

    #if os(macOS)
    private var macBody: some View {
        VStack(spacing: 0) {
            header
            audioErrorBanner
            Divider()
            FormattedMarkdownView(markdown: card.displayMarkdown)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.appTextBackground)
        }
        .background(Color.appTextBackground)
    }
    #else
    private var iOSBody: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                header
                audioErrorBanner
                Divider()
                FormattedMarkdownView(markdown: card.displayMarkdown)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .background(Color.appTextBackground)
    }
    #endif

    private var header: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Explanation")
                    .font(.headline)
                Text(card.createdAt.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button(action: toggleAudio) {
                Label {
                    Text(audioButtonTitle)
                } icon: {
                    if isLoadingAudio {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Image(systemName: audioButtonSymbol)
                    }
                }
            }
            .disabled(isLoadingAudio)
            .help(isPlayingThisCard ? "Stop playback" : "Play pronunciation")
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
    }

    @ViewBuilder
    private var audioErrorBanner: some View {
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
    }

    private var isPlayingThisCard: Bool {
        audioPlayer.isPlaying && audioPlayer.currentText == card.sourceText
    }

    private var audioButtonTitle: String {
        if isPlayingThisCard { return "Stop" }
        return card.audioFileName != nil ? "Play" : "Generate Audio"
    }

    private var audioButtonSymbol: String {
        if isPlayingThisCard { return "stop.fill" }
        return card.audioFileName != nil ? "speaker.wave.2.fill" : "speaker.wave.2"
    }

    private func toggleAudio() {
        if isPlayingThisCard {
            audioPlayer.stop()
        } else {
            onPlayAudio()
        }
    }
}

// MARK: - 左ペイン: カード行

private struct CardRow: View {
    let card: Card
    let colorHex: String
    var onSelectTag: ((String) -> Void)?
    var onNewTag: (() -> Void)?
    @EnvironmentObject private var store: CardStore

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Text(card.sourceText.replacingOccurrences(of: "\n", with: " "))
                    .font(.body)
                    .lineLimit(1)
                Spacer(minLength: 8)
                if card.audioFileName != nil {
                    Image(systemName: "speaker.wave.2.fill")
                        .foregroundStyle(.secondary)
                        .font(.caption2)
                        .help("Audio saved")
                }
            }
            HStack(spacing: 6) {
                #if os(macOS)
                if let onSelectTag {
                    Menu {
                        ForEach(store.tags) { tag in
                            Button {
                                onSelectTag(tag.name)
                            } label: {
                                Label {
                                    Text(tag.name)
                                } icon: {
                                    if card.category == tag.name {
                                        Image(systemName: "checkmark")
                                    } else {
                                        TagSwatch(colorHex: tag.colorHex)
                                    }
                                }
                            }
                        }
                        Button {
                            onSelectTag(LibraryTag.uncategorizedID)
                        } label: {
                            Label {
                                Text(LibraryTag.uncategorizedLabel)
                            } icon: {
                                if card.category.isEmpty {
                                    Image(systemName: "checkmark")
                                } else {
                                    TagSwatch(colorHex: LibraryTag.defaultColorHex)
                                }
                            }
                        }
                        if let onNewTag {
                            Divider()
                            Button("New Tag…", action: onNewTag)
                        }
                    } label: {
                        TagLabel(name: card.category, colorHex: colorHex)
                    }
                    .menuStyle(.borderlessButton)
                    .fixedSize()
                    .help("Change tag")
                } else {
                    TagLabel(name: card.category, colorHex: colorHex)
                }
                #else
                TagLabel(name: card.category, colorHex: colorHex)
                #endif
                Text("·")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                Text(card.createdAt, format: .relative(presentation: .named))
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 2)
    }
}

# LanguageTraining App Notes

LanguageTraining is a macOS language-learning app built with SwiftUI. It turns copied words, phrases, or sentences into saved learning cards with AI-generated explanations and pronunciation audio.

This app was originally named EnglishCard. Some legacy names remain in code and data migration paths so existing users can keep their saved cards and Keychain settings.

## Main Features

### Explain

- Load text from the clipboard, or edit the source text directly
- Generate a learner-friendly Markdown explanation with the OpenAI API
- Include simple meaning, pronunciation, grammar (articles, prepositions, tense, and related forms), useful words, examples, and common mistakes
- Choose the explanation language in Settings
- Generate pronunciation audio with OpenAI text-to-speech
- Save the source text, explanation, and audio as a learning card
- Play or stop audio before saving

### Library

- Search saved cards from the toolbar
- Open card details from the list
- Replay saved pronunciation audio without calling the API again
- Generate missing audio and save it to the card
- Copy source text or delete a card from the context menu
- Delete the selected card with the Delete key

### Data Management

- Export cards and audio files as a ZIP archive
- Import exported archives
- Validate archive contents and card XML before replacing local data
- Preserve compatibility with legacy EnglishCard exports
- Back up existing data before import
- Disable saving if the library file cannot be loaded, so `cards.xml` is not overwritten

## Technical Overview

- Language: Swift
- UI framework: SwiftUI
- Concurrency: Swift Concurrency with async/await
- Storage: XML files and local audio files in Application Support
- Secrets: OpenAI API keys are stored in macOS Keychain
- Network: HTTPS-only API requests
- Security: App Sandbox enabled with outgoing network access and user-selected file access
- Distribution: signed `.app` bundle for personal use, installed with `scripts/install-app.sh`

## Project Structure

```text
LanguageTraining/
├── EnglishCardApp.swift
├── ContentView.swift
├── ExplainView.swift
├── LibraryView.swift
├── SettingsView.swift
├── FormattedMarkdownView.swift
├── Card.swift
├── CardStore.swift
├── AppSettings.swift
├── AppStorage.swift
├── OpenAIClient.swift
├── AudioPlayerService.swift
├── CardXMLCodec.swift
├── Keychain.swift
├── LanguageTraining.entitlements
├── Info.plist
└── Assets.xcassets
```

Top-level helper files:

```text
DataManager.swift
scripts/install-app.sh
scripts/generate-app-icon.swift
```

## Setup

1. Open `LanguageTraining.xcodeproj` in Xcode, or run `./scripts/install-app.sh`.
2. Launch LanguageTraining.
3. Open Settings with `Command + ,`.
4. Enter an OpenAI API key.
5. Keep the Base URL set to `https://api.openai.com` unless you intentionally use a trusted compatible provider.
6. Click Save.

Japanese explanations are often easier for Japanese learners. Change Explanation Language in Settings if needed.

## Data Locations

Current app data:

```text
~/Library/Application Support/LanguageTraining/
```

Legacy data imported from the previous app name:

```text
~/Library/Application Support/EnglishCard/
```

Backups:

```text
~/Library/Application Support/LanguageTraining_Backups/
```

## Security Notes

- Do not commit API keys, exported user data, or local build output.
- The OpenAI API key is saved in Keychain.
- Custom API endpoints receive the same API key, so only use endpoints you trust.
- Imported ZIP archives are validated, and `cards.xml` must decode successfully, before local data is replaced.
- If the library file is damaged, the app shows an error and blocks saving so existing data is not overwritten.

## Future Ideas

- Card editing
- Tags or categories
- Review reminders
- iCloud sync
- iOS and iPadOS versions
- Additional export formats such as Anki

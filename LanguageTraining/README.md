# LanguageTraining App Notes

LanguageTraining is a macOS language-learning app built with SwiftUI. It turns copied words, phrases, or sentences into saved learning cards with AI-generated explanations and pronunciation audio.

This app was originally named EnglishCard. Some legacy names remain in code and data migration paths so existing users can keep their saved cards and Keychain settings.

## Main Features

### Explanation View

- Load text from the clipboard
- Generate structured Markdown explanations with the OpenAI API
- Choose the explanation language
- Generate pronunciation audio with OpenAI text-to-speech
- Save the source text, explanation, and audio as a learning card

### Library View

- Search saved cards
- Open card details from the list
- Replay saved pronunciation audio without calling the API again
- Delete cards from the context menu
- Review card creation dates

### Data Management

- Export cards and audio files as a ZIP archive
- Import exported archives
- Preserve compatibility with legacy EnglishCard exports
- Back up existing data before import

## Technical Overview

- Language: Swift
- UI framework: SwiftUI
- Concurrency: Swift Concurrency with async/await
- Storage: XML files and local audio files in Application Support
- Secrets: OpenAI API keys are stored in macOS Keychain
- Network: HTTPS-only API requests
- Security: App Sandbox enabled with outgoing network access and user-selected file access

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
└── Assets.xcassets
```

Top-level helper files:

```text
AppIconGenerator.swift
DataManager.swift
```

## Setup

1. Open `LanguageTraining.xcodeproj` in Xcode.
2. Select the `LanguageTraining` scheme.
3. Build and run the app.
4. Open Settings.
5. Enter an OpenAI API key.
6. Keep the Base URL set to `https://api.openai.com` unless you intentionally use a trusted compatible provider.

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
- Imported ZIP archives are validated before replacing local data.

## Future Ideas

- Card editing
- Tags or categories
- Review reminders
- iCloud sync
- iOS and iPadOS versions
- Additional export formats such as Anki


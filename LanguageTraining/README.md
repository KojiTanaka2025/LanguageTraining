# LanguageTraining App Notes

LanguageTraining is a macOS and iPhone language-learning app built with SwiftUI. It turns copied words, phrases, or sentences into saved learning cards with AI-generated explanations and pronunciation audio.

This app was originally named EnglishCard. Some legacy names remain in code and data migration paths so existing users can keep their saved cards and Keychain settings.

The Mac target (`LanguageTraining`) and the iPhone target (`LanguageTraining iOS`) share the same SwiftUI sources. Mac-only ZIP panels stay in `DataManager.swift`.

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

- Search saved cards
- Open card details from the list. On iPhone, tap a card to open the explanation on the next screen
- Replay saved pronunciation audio without calling the API again
- Generate missing audio and save it to the card
- Copy source text or delete a card from the context menu
- Delete a card with the Delete key on Mac, or swipe to delete on iPhone

### Data Management

- Sync cards and audio through the iCloud Drive folder `LanguageTraining`
- On iPhone, choose that folder once in Settings with the Files picker (Browse → iCloud Drive)
- Fall back to local Application Support if iCloud Drive is unavailable
- Copy an existing local Mac library into iCloud Drive once, if that folder is empty
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
- Storage: XML files and local audio files in iCloud Drive, with Application Support as a fallback
- Secrets: OpenAI API keys are stored in Keychain on each device
- Network: HTTPS-only API requests
- Security: App Sandbox enabled on Mac, with outgoing network access and user-selected file access
- Distribution: signed `.app` bundle for personal Mac use, installed with `scripts/install-app.sh`; iPhone builds use the `LanguageTraining iOS` scheme
- iCloud: a personal development team cannot use the iCloud container capability, so both apps share an iCloud Drive folder instead

## Project Structure

```text
LanguageTraining/
├── EnglishCardApp.swift
├── ContentView.swift
├── ExplainView.swift
├── LibraryView.swift
├── SettingsView.swift
├── FormattedMarkdownView.swift
├── DocumentFolderPicker.swift
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

iPhone-only files:

```text
LanguageTrainingiOS/
├── Info.plist
└── LanguageTrainingiOS.entitlements
```

Top-level helper files:

```text
DataManager.swift
scripts/install-app.sh
scripts/generate-app-icon.swift
```

## Setup

1. Open `LanguageTraining.xcodeproj` in Xcode, or run `./scripts/install-app.sh` for Mac.
2. Select `LanguageTraining` for Mac or `LanguageTraining iOS` for iPhone.
3. Launch LanguageTraining.
4. Open Settings with `Command + ,` on Mac, or the Settings tab on iPhone.
5. Enter an OpenAI API key.
6. Keep the Base URL set to `https://api.openai.com` unless you intentionally use a trusted compatible provider.
7. Click Save.

Japanese explanations are often easier for Japanese learners. Change Explanation Language in Settings if needed.

## Data Locations

iCloud library (when iCloud Drive is in use):

```text
iCloud Drive/LanguageTraining/
```

On iPhone, this folder is selected once through Settings → Choose Folder. If iCloud Drive is missing from Files Locations, enable it in iPhone Settings → Apple ID → iCloud → iCloud Drive, or in the Files picker under … → Edit.

Local fallback on Mac:

```text
~/Library/Application Support/LanguageTraining/
```

Legacy data imported from the previous app name:

```text
~/Library/Application Support/EnglishCard/
```

Backups stay on the device:

```text
~/Library/Application Support/LanguageTraining_Backups/
```

## Security Notes

- Do not commit API keys, exported user data, or local build output.
- The OpenAI API key is saved in Keychain on each device.
- Custom API endpoints receive the same API key, so only use endpoints you trust.
- Imported ZIP archives are validated, and `cards.xml` must decode successfully, before local data is replaced.
- If the library file is damaged, the app shows an error and blocks saving so existing data is not overwritten.
- If two devices edit the library at the same time, iCloud keeps the last written `cards.xml`. Avoid editing on both devices at once.

## Future Ideas

- Card editing
- Tags or categories
- Review reminders
- Additional export formats such as Anki

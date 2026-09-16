# LanguageTraining App Notes

LanguageTraining is a macOS and iPhone language-learning app built with SwiftUI. It turns copied words, phrases, or sentences into saved learning cards with AI-generated explanations and pronunciation audio.

This app was originally named EnglishCard. Some legacy names remain in code and data migration paths so existing users can keep their saved cards and Keychain settings.

The Mac target (`LanguageTraining`) and the iPhone target (`LanguageTraining iOS`) share the same SwiftUI sources. Mac-only ZIP panels stay in `DataManager.swift`.

## Main Features

### Explain

- Load text from the clipboard, or edit the source text directly
- Generate a Markdown explanation with the OpenAI API, aimed at an adult English learner (about CEFR A2) who wants to work at a foreign company
- Include meaning, pronunciation, structure, grammar, vocabulary, examples, and notes, using short adult section titles
- Keep English in the structure and vocabulary sections; add a gloss in the explanation language. Do not break down the translation
- Put the original text at the top of the explanation
- Show an approximate API cost at the end of the explanation, in a currency matching the explanation language
- Choose the explanation language in Settings
- Generate pronunciation audio with OpenAI text-to-speech
- Choose a colored tag when saving (仕事用, 日常会話, custom tags, or 未分類), and add a new tag from the same menu
- Save the source text, explanation, tag, and audio as a learning card
- Play or stop audio before saving

### Library

- Filter cards by colored tag (all, one tag, or uncategorized)
- Search saved cards by text or tag name
- Open card details from the list. On iPhone, tap a card to open the explanation on the next screen
- Show the explanation only in the detail pane, with the original text as the explanation title so it is not duplicated
- Replay saved pronunciation audio without calling the API again
- Generate missing audio and save it to the card
- Change a card’s tag from the row dropdown or the context menu; add a new tag from either place
- Copy source text or delete a card from the context menu
- Delete a card with the Delete key on Mac, or swipe to delete on iPhone

### Settings

- Manage library tags: add, pick a color, or delete (tags live in `cards.xml` and sync with the library)

### Mac layout

- Remember the main window position and size across launches
- Remember Explain (top/bottom) and Library (left/right) split-pane sizes

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
- Load the iCloud library in the background and show “Loading library…” instead of freezing the UI

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
- File coordination: iCloud downloads wait off the main thread, then the library snapshot is applied on the main actor

## Project Structure

```text
LanguageTraining/
├── EnglishCardApp.swift
├── ContentView.swift
├── ExplainView.swift
├── LibraryView.swift
├── SettingsView.swift
├── FormattedMarkdownView.swift
├── APICost.swift
├── LayoutPersistence.swift
├── DocumentFolderPicker.swift
├── CoordinatedFile.swift
├── LibraryArchive.swift
├── PlatformSupport.swift
├── ZipArchive.swift
├── Card.swift
├── LibraryTag.swift
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

Japanese explanations are written for adult Japanese learners of English. Change Explanation Language in Settings if needed. See [Verified usage](#verified-usage).

## Verified usage

The app has been checked in the pattern it was built for: **a Japanese speaker learning English**, with Explanation Language set to Japanese.

It has **not** been verified for other patterns, such as:

- Explanation Language other than Japanese
- Source text in a language other than English
- A learner profile other than an adult Japanese speaker of English

Those settings still generate cards, but the wording, layout, and translations may not have been reviewed.

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
- If two devices edit the library at the same time, iCloud keeps the last saved `cards.xml`. After saving on one device, wait for iCloud Drive to finish syncing before editing on the other.

## Verify that the app does not misuse the API key

The app is meant to send your OpenAI API key only as an `Authorization: Bearer` header to the Base URL you set in Settings (default `https://api.openai.com`), and only for explanation (`/v1/chat/completions`) and speech (`/v1/audio/speech`). It stores the key in Keychain, not in the card library. You can check that yourself.

### 1. Search the source

From the repository root:

```text
rg -n "apiKey|Bearer |Authorization|Keychain" --glob "*.swift"
```

Confirm that:

- `LanguageTraining/OpenAIClient.swift` is the only place that attaches `Bearer` to an HTTP request
- Those requests go to `{Base URL}/v1/chat/completions` and `{Base URL}/v1/audio/speech`
- Both paths reject a non-`https` URL
- `LanguageTraining/AppSettings.swift` and `LanguageTraining/Keychain.swift` save the key to Keychain (`service` `LanguageTraining`, `account` `OPENAI_API_KEY`)
- The key is not written into `cards.xml`, ZIP exports, logs, or analytics

The iPhone target uses the same Swift sources.

### 2. Confirm the key is not in library files

After creating a card, open `cards.xml` in `iCloud Drive/LanguageTraining/` (or the local Application Support fallback). Search for `sk-` or a distinctive fragment of your key. It should not appear. Exported ZIP archives should also contain only card text and audio, not the key.

### 3. Watch live traffic

On Mac, capture HTTPS while you click Explain (and Listen, if you generate audio):

1. Keep Base URL set to `https://api.openai.com`.
2. Use a local HTTPS inspector you trust (for example Proxyman or Charles) with the Mac app as the client.
3. Generate one explanation.

You should see POST requests only to:

- `https://api.openai.com/v1/chat/completions`
- `https://api.openai.com/v1/audio/speech` (when audio is generated)

The `Authorization` header should be sent to that host only. There should be no request that includes the key to any other domain.

App Sandbox on Mac allows outgoing client connections but does not by itself prove the destination. The capture does.

### 4. Compare with the OpenAI usage dashboard

1. Note the time, then generate one card in the app.
2. Open [OpenAI usage](https://platform.openai.com/account/usage).
3. You should see usage for the model in Settings and, if audio ran, `gpt-4o-mini-tts`, at that time.
4. Leave the app idle. No further billed calls should appear until you Explain, Listen, or generate library audio again.

If usage appears while you are not using those actions, treat that as a problem.

### 5. Custom Base URL

Settings lets you change Base URL. The same API key is sent to whatever HTTPS host you enter. To verify OpenAI-only use, leave the default `https://api.openai.com`. Do not point Base URL at a host you do not trust.

## Future Ideas

- Card editing
- Tags or categories
- Review reminders
- Additional export formats such as Anki

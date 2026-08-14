# LanguageTraining

LanguageTraining is a macOS and iPhone app for creating language-learning cards from copied text. It uses the OpenAI API to generate structured explanations and pronunciation audio, then stores the result in iCloud Drive so you can review the same library on Mac and iPhone.

The project was originally named EnglishCard and was renamed to LanguageTraining. Some legacy identifiers remain intentionally so existing local data and Keychain entries can be migrated.

## Features

- Create learning cards from pasted or clipboard text
- Generate beginner-friendly explanations with meaning, pronunciation, grammar, examples, and common mistakes
- Choose the explanation language
- Generate and save pronunciation audio with OpenAI text-to-speech
- Search and review saved cards
- Import and export learning data as ZIP archives
- Store API keys in Keychain
- Share the card library between Mac and iPhone through an iCloud Drive folder

## Requirements

- macOS 26.2 or later for the Mac app
- iOS 18 or later for the iPhone app
- Xcode
- An Apple ID signed in to iCloud Drive (for Mac and iPhone sharing)
- OpenAI API key

## Install as a Mac app

Build a Release `.app` and install it next to other applications (Launchpad, Spotlight, Dock):

```text
./scripts/install-app.sh
```

This installs `LanguageTraining.app` to `/Applications` when possible, otherwise to `~/Applications`. The install is intended for personal use on this Mac.

After changing the source, run the same script again to replace the installed app.

## Setup in Xcode

1. Clone the repository.
2. Open `LanguageTraining.xcodeproj` in Xcode.
3. Select the `LanguageTraining` scheme for Mac, or `LanguageTraining iOS` for iPhone.
4. Build and run. For the Mac app you can also run `./scripts/install-app.sh`.
5. Open Settings and enter your OpenAI API key. On iPhone, use the Settings tab. Enter the key on each device; it is stored in that device's Keychain.

The API key is not stored in the repository.

For first-run details, sharing, and iPhone Files setup, see `LanguageTraining/QUICKSTART.md`.

## Run on iPhone

1. Connect an iPhone, or choose an iOS 18 simulator.
2. Select the `LanguageTraining iOS` scheme and that device.
3. Confirm Signing & Capabilities uses your Apple ID team and Automatic signing.
4. Press `Command + R`.

On a physical iPhone, enable Developer Mode and trust the developer certificate under Settings → General → VPN & Device Management. A personal team certificate expires after about seven days; run the app from Xcode again to renew it.

## Data Storage

When iCloud Drive is available on Mac, cards and audio are stored in:

```text
iCloud Drive/LanguageTraining/
```

A personal Apple ID cannot use a paid iCloud app container, so sharing uses this ordinary iCloud Drive folder instead.

On iPhone, open Settings and tap Choose Folder. In Files, tap Browse, then iCloud Drive, then LanguageTraining, then Open. If iCloud Drive is missing from Locations, turn it on in iPhone Settings → Apple ID → iCloud → iCloud Drive, or tap … in Files → Edit and enable iCloud Drive.

If iCloud Drive is off, or iPhone has not chosen the folder, the app uses local storage. On Mac that is:

```text
~/Library/Application Support/LanguageTraining/
```

The app can also import legacy data from:

```text
~/Library/Application Support/EnglishCard/
```

Import backs up existing data here (this folder stays on the device):

```text
~/Library/Application Support/LanguageTraining_Backups/
```

## Project Structure

```text
LanguageTraining/
├── LanguageTraining.xcodeproj
├── LanguageTraining/
│   ├── EnglishCardApp.swift
│   ├── ContentView.swift
│   ├── ExplainView.swift
│   ├── LibraryView.swift
│   ├── SettingsView.swift
│   ├── FormattedMarkdownView.swift
│   ├── Card.swift
│   ├── CardStore.swift
│   ├── CardXMLCodec.swift
│   ├── OpenAIClient.swift
│   ├── AppSettings.swift
│   ├── AppStorage.swift
│   ├── AudioPlayerService.swift
│   ├── DocumentFolderPicker.swift
│   ├── Keychain.swift
│   └── Assets.xcassets
├── LanguageTrainingiOS/
│   ├── Info.plist
│   └── LanguageTrainingiOS.entitlements
├── DataManager.swift
├── scripts/
│   ├── install-app.sh
│   └── generate-app-icon.swift
└── README.md
```

## Notes

- Do not commit API keys or local user data.
- The repository is currently private, but this README is written with future public release in mind.
- Licensing has not been finalized yet.
- Signing uses an Apple Development certificate, which is enough for personal use on this Mac and on an iPhone registered to the same team.

# LanguageTraining

LanguageTraining is a macOS app for creating language-learning cards from copied text. It uses the OpenAI API to generate structured explanations and pronunciation audio, then stores the result locally so you can review it later.

The project was originally named EnglishCard and was renamed to LanguageTraining. Some legacy identifiers remain intentionally so existing local data and Keychain entries can be migrated.

## Features

- Create learning cards from pasted or clipboard text
- Generate beginner-friendly explanations with meaning, pronunciation, grammar, examples, and common mistakes
- Choose the explanation language
- Generate and save pronunciation audio with OpenAI text-to-speech
- Search and review saved cards
- Import and export learning data as ZIP archives
- Store API keys in macOS Keychain

## Requirements

- macOS 26.2 or later
- Xcode
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
3. Select the `LanguageTraining` scheme.
4. Build and run the app, or run `./scripts/install-app.sh`.
5. Open Settings (`Command + ,`) and enter your OpenAI API key.
6. Click Save.

The API key is saved in Keychain and is not stored in the repository.

For first-run details, see `LanguageTraining/QUICKSTART.md`.

## Data Storage

Cards are stored in the user's Application Support directory:

```text
~/Library/Application Support/LanguageTraining/
```

The app can also import legacy data from:

```text
~/Library/Application Support/EnglishCard/
```

Import backs up existing data here:

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
│   ├── Keychain.swift
│   └── Assets.xcassets
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
- Signing uses an Apple Development certificate, which is enough for personal use on this Mac.

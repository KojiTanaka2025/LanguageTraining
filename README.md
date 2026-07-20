# LanguageTraining

LanguageTraining is a macOS app for creating language-learning cards from copied text. It uses the OpenAI API to generate structured explanations and text-to-speech audio, then stores the result locally so you can review it later.

The project was originally named EnglishCard and was renamed to LanguageTraining. Some legacy identifiers remain intentionally so existing local data and Keychain entries can be migrated.

## Features

- Generate learning-card explanations from clipboard text
- Choose the explanation language
- Generate pronunciation audio with OpenAI text-to-speech
- Save cards locally with explanation text and audio
- Search and review saved cards
- Import and export learning data as ZIP archives
- Store API keys in macOS Keychain

## Requirements

- macOS
- Xcode
- OpenAI API key

## Setup

1. Clone the repository.
2. Open `LanguageTraining.xcodeproj` in Xcode.
3. Select the `LanguageTraining` scheme.
4. Build and run the app.
5. Open Settings in the app and enter your OpenAI API key.

The API key is saved in Keychain and is not stored in the repository.

## Data Storage

Cards are stored in the user's Application Support directory:

```text
~/Library/Application Support/LanguageTraining/
```

The app can also import legacy data from:

```text
~/Library/Application Support/EnglishCard/
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
│   ├── CardStore.swift
│   ├── CardXMLCodec.swift
│   ├── OpenAIClient.swift
│   ├── AppSettings.swift
│   ├── AppStorage.swift
│   └── Assets.xcassets
├── AppIconGenerator.swift
├── DataManager.swift
└── README.md
```

## Notes

- Do not commit API keys or local user data.
- The repository is currently private, but this README is written with future public release in mind.
- Licensing has not been finalized yet.


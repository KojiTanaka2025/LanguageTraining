# LanguageTraining Quick Start

This guide explains the basic workflow for setting up LanguageTraining, creating learning cards, and reviewing saved cards.

## Install

For personal use as a normal Mac app:

```text
./scripts/install-app.sh
```

This installs `LanguageTraining.app` to `/Applications` when possible. You can then open it from Launchpad, Spotlight, or the Dock.

## First Launch

1. Launch LanguageTraining.
2. Open Settings from the app menu or press `Command + ,`.
3. Enter your OpenAI API key.
4. Keep the default model unless you need a different one.
5. Keep the Base URL as `https://api.openai.com` unless you use a trusted OpenAI-compatible provider.
6. Optionally set Explanation Language. Japanese is often easier to read for Japanese learners of English.
7. Click Save.

The API key is stored in macOS Keychain.

## Create A Learning Card

Basic flow:

```text
Copy text -> Load Clipboard (optional) -> Explain -> Save to Library
```

### 1. Copy Text

Copy a word, phrase, or sentence from a browser, PDF reader, editor, or another app.

Example:

```text
procrastinate
```

Another example:

```text
The company will postpone making a decision until next month.
```

### 2. Put Text In The Editor

1. Open the Explain tab.
2. Click Load Clipboard, or paste into Source text.

The app also loads clipboard text automatically the first time Explain appears. You can edit the text before generating an explanation. Explain uses the editor contents, not a fresh clipboard read.

### 3. Generate An Explanation

1. Click Explain, or press `Command + Return`.
2. Wait for the explanation to appear.

You can listen to the source text with Listen, and stop playback with Stop.

Generated cards can include:

- A simple meaning and when to use the expression
- Pronunciation and stress
- How the sentence is built
- Grammar that appears in the text, such as articles, prepositions, and tense
- Useful words and collocations
- Short everyday examples
- Similar expressions and common mistakes
- A short summary to remember
- Pronunciation audio

### 4. Save The Card

Review the generated explanation, then click Save to Library or press `Command + S`.

Turn off Save audio if you do not want to store pronunciation with the card.

Saved cards include the original text, explanation, creation date, and audio when available.

## Review Saved Cards

1. Open the Library tab.
2. Use the toolbar search field to filter cards.
3. Select a card to view the full explanation.
4. Play saved audio, or generate audio if none is saved. Newly generated library audio is stored on the card.
5. Copy the source text or delete a card from the context menu. You can also press Delete after selecting a card.

## Keyboard Shortcuts

| Shortcut | Action |
| --- | --- |
| `Command + ,` | Open Settings |
| `Command + Return` | Generate an explanation from the editor text |
| `Command + S` | Save the current card to the library |
| `Delete` | Delete the selected library card |
| `Command + W` | Close the window |
| `Command + Q` | Quit the app |

## Data Management

Cards are stored here:

```text
~/Library/Application Support/LanguageTraining/
```

Legacy data may exist here:

```text
~/Library/Application Support/EnglishCard/
```

Use Settings to export or import learning data. Importing an archive validates the files first and backs up existing data automatically.

If the library cannot be loaded, the app shows an error and disables saving so your existing `cards.xml` is not overwritten. Use Retry after fixing the file, or restore a backup from:

```text
~/Library/Application Support/LanguageTraining_Backups/
```

## Troubleshooting

### API Key Not Set

Open Settings (`Command + ,`) and enter your OpenAI API key, then click Save.

### Authentication Error

The API key may be invalid or expired. Check the key in your OpenAI dashboard and update it in Settings.

### Slow Explanation Generation

Check your internet connection. OpenAI API availability and model latency can also affect response time.

### Cards Do Not Appear

Check whether the data folder exists:

```text
~/Library/Application Support/LanguageTraining/
```

If you recently renamed from EnglishCard, check the legacy folder as well:

```text
~/Library/Application Support/EnglishCard/
```

If the app says the library could not be loaded, do not save a new card until the error is resolved.

### App Does Not Connect To The API

Check `NETWORK_TROUBLESHOOTING.md` for network and App Sandbox diagnostics.

## Study Tips

- Save useful words and phrases as soon as you encounter them.
- Include full example sentences when possible.
- Review older cards regularly.
- Search by topic before tests or focused study sessions.
- Use the audio feature for pronunciation practice.

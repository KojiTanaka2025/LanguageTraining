# LanguageTraining Quick Start

This guide explains the basic workflow for setting up LanguageTraining, creating learning cards, and reviewing saved cards.

## First Launch

1. Launch the app.
2. Open Settings from the app menu or press `Command + ,`.
3. Enter your OpenAI API key.
4. Keep the default model unless you need a different one.
5. Keep the Base URL as `https://api.openai.com` unless you use a trusted OpenAI-compatible provider.
6. Click Save.

The API key is stored in macOS Keychain.

## Create A Learning Card

Basic flow:

```text
Copy text -> Load clipboard -> Generate explanation -> Save card
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

### 2. Load From Clipboard

1. Open the Explain tab.
2. Click Load from Clipboard.

The app may also load clipboard text automatically when the view appears.

### 3. Generate An Explanation

1. Click the AI explanation button, or press `Command + Return`.
2. Wait for the explanation to appear.

Generated cards can include:

- Source language detection
- Translation
- Grammar and structure
- Important vocabulary
- Example sentences
- Common pitfalls
- Key takeaways
- Pronunciation audio

### 4. Save The Card

Review the generated explanation, then save it to the library.

Saved cards include the original text, explanation, creation date, and audio when available.

## Review Saved Cards

1. Open the Library tab.
2. Use the search field to filter cards.
3. Open a card to view the full explanation.
4. Play saved audio when available.
5. Delete cards you no longer need from the context menu.

## Keyboard Shortcuts

| Shortcut | Action |
| --- | --- |
| `Command + ,` | Open Settings |
| `Command + Return` | Generate an AI explanation |
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

Use Settings to export or import learning data. Importing an archive backs up existing data first.

## Troubleshooting

### API Key Not Set

Open Settings and enter your OpenAI API key.

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

### App Does Not Connect To The API

Check `NETWORK_TROUBLESHOOTING.md` for network and App Sandbox diagnostics.

## Study Tips

- Save useful words and phrases as soon as you encounter them.
- Include full example sentences when possible.
- Review older cards regularly.
- Search by topic before tests or focused study sessions.
- Use the audio feature for pronunciation practice.


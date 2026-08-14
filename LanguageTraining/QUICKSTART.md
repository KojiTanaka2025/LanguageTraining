# LanguageTraining Quick Start

This guide explains the basic workflow for setting up LanguageTraining on Mac and iPhone, sharing the library through iCloud Drive, creating learning cards, and reviewing saved cards.

## Install On Mac

For personal use as a normal Mac app:

```text
./scripts/install-app.sh
```

This installs `LanguageTraining.app` to `/Applications` when possible. You can then open it from Launchpad, Spotlight, or the Dock.

## Install On iPhone

1. Open `LanguageTraining.xcodeproj` in Xcode.
2. Select the `LanguageTraining iOS` scheme.
3. Choose an iPhone (or an iOS 18 simulator) as the destination.
4. Press `Command + R`.

On a physical iPhone:

- Enable Developer Mode under Settings → Privacy & Security.
- Trust the developer app under Settings → General → VPN & Device Management.
- A personal team install lasts about seven days. Run the app from Xcode again when it expires.

## iCloud Sharing

Use the same Apple ID on Mac and iPhone, with iCloud Drive turned on. Sharing uses the ordinary iCloud Drive folder `LanguageTraining`, not a paid iCloud app container.

1. Open LanguageTraining on the Mac first if you already have cards there. The app copies the local library into `iCloud Drive/LanguageTraining` when that folder is empty.
2. On iPhone, open the Settings tab and tap Choose Folder.
3. In Files, tap Browse (not Recents).
4. Open iCloud Drive, then LanguageTraining, then tap Open. Selecting iCloud Drive itself also works; the app uses a LanguageTraining folder inside it.
5. Settings should show Library as iCloud Drive.
6. New cards and audio appear on both devices after iCloud Drive finishes uploading.

If iCloud Drive is off, or the iPhone has not chosen the folder yet, each device keeps its own local library.

The API key is stored in Keychain on each device. Enter it once on Mac and once on iPhone.

### iCloud Drive Does Not Appear In Locations

The Files picker may show On My iPhone, Google Drive, or other locations without iCloud Drive.

1. On iPhone, open Settings → your name → iCloud → iCloud Drive, and turn on sync for this iPhone.
2. Confirm the iPhone uses the same Apple ID as the Mac.
3. In the Files picker, tap … (top right) → Edit, and enable iCloud Drive.
4. Return to LanguageTraining and tap Choose Folder again.

## First Launch

### Mac

1. Launch LanguageTraining.
2. Open Settings from the app menu or press `Command + ,`.
3. Enter your OpenAI API key.
4. Keep the default model unless you need a different one.
5. Keep the Base URL as `https://api.openai.com` unless you use a trusted OpenAI-compatible provider.
6. Optionally set Explanation Language. Japanese is often easier to read for Japanese learners of English.
7. Click Save.

### iPhone

1. Launch LanguageTraining.
2. Open the Settings tab.
3. Enter the same OpenAI settings as on Mac, then tap Save.
4. Tap Choose Folder and select `iCloud Drive/LanguageTraining` as described above.

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

1. Click Explain, or press `Command + Return` on Mac.
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

Review the generated explanation, then click Save to Library or press `Command + S` on Mac.

Turn off Save audio if you do not want to store pronunciation with the card.

Saved cards include the original text, explanation, creation date, and audio when available. If iCloud Drive sharing is set up, the new card appears on the other device after it uploads.

## Review Saved Cards

1. Open the Library tab.
2. Use search to filter cards.
3. Open a card to view the full explanation. On Mac, select it in the list. On iPhone, tap the card; the explanation opens on the next screen.
4. Play saved audio, or generate audio if none is saved. Newly generated library audio is stored on the card.
5. Copy the source text or delete a card from the context menu. On Mac you can also press Delete after selecting a card. On iPhone you can swipe to delete.

## Keyboard Shortcuts

These shortcuts apply to the Mac app.

| Shortcut | Action |
| --- | --- |
| `Command + ,` | Open Settings |
| `Command + Return` | Generate an explanation from the editor text |
| `Command + S` | Save the current card to the library |
| `Delete` | Delete the selected library card |
| `Command + W` | Close the window |
| `Command + Q` | Quit the app |

## Data Management

Shared library (when iCloud Drive is in use):

```text
iCloud Drive/LanguageTraining/
```

Local fallback on Mac:

```text
~/Library/Application Support/LanguageTraining/
```

Legacy data may exist here:

```text
~/Library/Application Support/EnglishCard/
```

Use Settings to export or import learning data as a ZIP archive. Importing an archive validates the files first and backs up existing data automatically.

If the library cannot be loaded, the app shows an error and disables saving so your existing `cards.xml` is not overwritten. Use Retry after fixing the file, or restore a backup from:

```text
~/Library/Application Support/LanguageTraining_Backups/
```

Avoid editing the library on Mac and iPhone at the same time. The last written `cards.xml` wins.

## Troubleshooting

### API Key Not Set

On Mac, open Settings (`Command + ,`). On iPhone, open the Settings tab. Enter your OpenAI API key, then tap Save.

### Authentication Error

The API key may be invalid or expired. Check the key in your OpenAI dashboard and update it in Settings on that device.

### Slow Explanation Generation

Check your internet connection. OpenAI API availability and model latency can also affect response time.

### Cards Do Not Appear

On Mac, check `iCloud Drive/LanguageTraining/` and:

```text
~/Library/Application Support/LanguageTraining/
```

On iPhone, confirm Settings shows Library as iCloud Drive, and that you selected the `LanguageTraining` folder.

If the app says the library could not be loaded, do not save a new card until the error is resolved.

### iPhone Library Tap Does Nothing

Use a build that opens a card on the next screen when you tap a row. Rebuild and reinstall `LanguageTraining iOS` from Xcode if an older build is still on the phone.

### iCloud Drive Missing In The Files Picker

See [iCloud Drive Does Not Appear In Locations](#icloud-drive-does-not-appear-in-locations) above.

### App Does Not Connect To The API

Check `NETWORK_TROUBLESHOOTING.md` for network and App Sandbox diagnostics.

## Study Tips

- Save useful words and phrases as soon as you encounter them.
- Include full example sentences when possible.
- Review older cards regularly.
- Search by topic before tests or focused study sessions.
- Use the audio feature for pronunciation practice.

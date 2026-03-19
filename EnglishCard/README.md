# EnglishCard

Mac用の英語学習支援アプリケーションです。クリップボードから英単語や英文をコピーし、AIで詳しい解説を取得して学習カードとして保存できます。

## 主な機能

### 🌟 英語解説モード
- **クリップボード連携**: ボタン一つで自動的にクリップボードの内容を読み込み
- **AI解説生成**: OpenAI APIを使って詳しい英語解説をMarkdown形式で取得
- **リアルタイムプレビュー**: 生成された解説をその場で確認
- **簡単保存**: ボタン一つで学習カードとして保存

### 📚 学習カード一覧モード
- **検索機能**: 単語や解説内容で素早く検索
- **ダブルクリック表示**: カードをダブルクリックで詳細モーダルを表示
- **コンテキストメニュー**: 右クリックで詳細表示や削除
- **日付表示**: 作成日時を確認して学習の進捗を把握

## 技術仕様

### アーキテクチャ
- **言語**: Swift
- **フレームワーク**: SwiftUI (macOS 12.0+)
- **並行処理**: Swift Concurrency (async/await)
- **データ永続化**: XML形式でApplication Supportフォルダに保存
- **セキュリティ**: APIキーはKeychainに安全に保存

### ファイル構造

```
EnglishCard/
├── EnglishCardApp.swift          # アプリエントリーポイント
├── ContentView.swift              # メインビュー（タブ方式）
├── AlternativeContentView.swift   # 代替レイアウト（サイドバー方式）
│
├── Views/
│   ├── ExplainView.swift          # 英語解説画面
│   ├── LibraryView.swift          # カード一覧画面
│   ├── CardDetailView.swift       # カード詳細モーダル
│   ├── SettingsView.swift         # 設定画面
│   └── MarkdownTextView.swift     # Markdownレンダリング
│
├── Models/
│   ├── Card.swift                 # カードデータモデル
│   ├── CardStore.swift            # カード管理（ObservableObject）
│   └── AppSettings.swift          # アプリ設定（ObservableObject）
│
└── Services/
    ├── OpenAIClient.swift         # OpenAI API通信
    ├── CardXMLCodec.swift         # XML エンコード/デコード
    └── Keychain.swift             # Keychain操作ユーティリティ
```

## セットアップ

### 必要要件
- macOS 12.0 (Monterey) 以降
- Xcode 14.0 以降
- OpenAI APIキー

### 初回起動
1. アプリを起動
2. メニューバーから「設定…」を選択（または ⌘,）
3. OpenAI APIキーを入力
4. 必要に応じてモデル名やBase URLを変更
5. 「保存」をクリック

## 使い方

### 英語解説の取得

1. **英語解説**タブを開く
2. Webブラウザなどで英単語や英文をコピー
3. 「クリップボードから読み込み」をクリック（または起動時に自動読み込み）
4. 「AIで解説を取得」をクリック（⌘↩）
5. 解説が表示されたら「保存して一覧へ」をクリック

### 学習カードの確認

1. **一覧**タブを開く
2. 検索バーでキーワード検索（任意）
3. カードをダブルクリックで詳細表示
4. 右クリックメニューから削除も可能

## カスタマイズ

### レイアウトの変更

デフォルトではタブ形式（`ContentView`）を使用していますが、サイドバー形式（`AlternativeContentView`）に変更することもできます。

`EnglishCardApp.swift`を以下のように変更：

```swift
WindowGroup("EnglishCard") {
    AlternativeContentView()  // ContentView() から変更
        .environmentObject(store)
        .environmentObject(settings)
        .frame(minWidth: 980, minHeight: 640)
}
```

### OpenAI設定のカスタマイズ

設定画面で以下を変更可能：
- **モデル**: `gpt-4o-mini`（デフォルト）、`gpt-4o`、`gpt-3.5-turbo` など
- **Base URL**: OpenAI互換のAPIエンドポイント（Azure OpenAI等）

## データの保存場所

学習カードは以下の場所に保存されます：

```
~/Library/Application Support/EnglishCard/cards.xml
```

### バックアップ

上記のXMLファイルをコピーすることでデータをバックアップできます。

## トラブルシューティング

### APIエラーが発生する
- APIキーが正しく設定されているか確認
- インターネット接続を確認
- OpenAIのAPI利用制限を確認

### 解説が表示されない
- クリップボードに有効なテキストがあるか確認
- APIキーの有効期限を確認

### データが消えた
- `~/Library/Application Support/EnglishCard/cards.xml`が存在するか確認
- バックアップから復元

## ライセンス

このアプリケーションはサンプルプロジェクトです。自由に改変・使用してください。

## 今後の拡張案

- [ ] カードの編集機能
- [ ] タグやカテゴリー機能
- [ ] エクスポート機能（PDF、Anki形式など）
- [ ] 復習リマインダー
- [ ] 音声読み上げ機能
- [ ] iCloud同期
- [ ] iOS/iPadOSアプリ版

## 開発者向けメモ

### ビルド設定
- Deployment Target: macOS 12.0
- Swift Language Version: Swift 5.9+

### 依存関係
このプロジェクトは外部ライブラリに依存せず、Appleのネイティブフレームワークのみを使用しています。

---

**EnglishCard** - あなたの英語学習をスマートにサポート 📚✨

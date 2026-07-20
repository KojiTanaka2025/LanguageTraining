# ネットワーク接続エラーのトラブルシューティング

「サーバーが見つかりません」エラーが出る場合の解決方法です。

## 🔧 Xcodeプロジェクト設定の確認

### 1. App Sandboxとネットワーク権限

Xcodeでプロジェクトを開き、以下を確認してください：

1. **プロジェクトナビゲーターで、プロジェクト名（EnglishCard）をクリック**
2. **TARGETSでEnglishCardを選択**
3. **「Signing & Capabilities」タブを開く**

#### App Sandboxが有効な場合：
- **「+ Capability」ボタンをクリック**
- **「App Sandbox」を追加（既にあればスキップ）**
- **「Network」セクションで以下をチェック：**
  - ✅ **Outgoing Connections (Client)** ← これが重要！

#### entitlementsファイルの設定：
プロジェクトに `EnglishCard.entitlements` ファイルが追加されているか確認し、以下の内容が含まれているか確認：

```xml
<key>com.apple.security.network.client</key>
<true/>
```

### 2. ビルド設定の確認

**Build Settings** タブで以下を確認：

- **Code Signing Entitlements**: `EnglishCard.entitlements` が設定されているか

---

## 🧪 接続テストの実行

アプリを再ビルドして起動後：

1. **「英語解説」タブを開く**
2. **「🔍 接続テスト」ボタンをクリック**
3. 結果を確認：
   - ✅ **「サーバーに接続成功！（認証エラーは正常...）」** → 問題なし！APIキーを確認してください
   - ❌ **エラーメッセージ** → 以下の対処法を試してください

---

## 🔍 よくある問題と解決方法

### 問題1: 「DNSでホスト名を解決できません」

**原因:** インターネット接続、DNS設定、またはVPNの問題

**解決方法:**
1. **インターネット接続を確認**
   - Safari等で https://www.google.com にアクセスできるか確認
   
2. **DNSキャッシュをクリア**（ターミナルで実行）:
   ```bash
   sudo dscacheutil -flushcache
   sudo killall -HUP mDNSResponder
   ```

3. **VPNを使用している場合**
   - VPNを一時的に無効化して再度テスト
   - VPNの設定でOpenAI APIへのアクセスを許可

4. **DNSサーバーを変更**
   - システム環境設定 → ネットワーク → 詳細 → DNS
   - Google DNS（8.8.8.8, 8.8.4.4）やCloudflare DNS（1.1.1.1）を追加

### 問題2: 「接続がタイムアウトしました」

**原因:** ファイアウォールやセキュリティソフトウェアがブロックしている

**解決方法:**
1. **macOSファイアウォール設定を確認**
   - システム環境設定 → セキュリティとプライバシー → ファイアウォール
   - 「ファイアウォールオプション...」をクリック
   - EnglishCardアプリが許可されているか確認

2. **サードパーティのセキュリティソフトを確認**
   - アンチウイルスソフトやファイアウォールアプリを一時的に無効化してテスト

### 問題3: 「App Transport Securityの制限」

**原因:** HTTPSの設定に問題がある（通常は発生しません）

**解決方法:**
- Base URLが `https://api.openai.com` で始まっているか確認（`http://` ではなく `https://`）

### 問題4: App Sandboxが接続をブロックしている

**原因:** ネットワーク権限が正しく設定されていない

**解決方法:**
1. **Xcodeで再設定:**
   - Signing & Capabilities → App Sandbox → Outgoing Connections (Client) をチェック

2. **プロジェクトをクリーンビルド:**
   - Xcode: Product → Clean Build Folder (Shift + Command + K)
   - 再ビルド: Product → Build (Command + B)

3. **派生データを削除:**（ターミナルで実行）
   ```bash
   rm -rf ~/Library/Developer/Xcode/DerivedData
   ```

---

## 🛠 手動でentitlementsファイルを追加する方法

もしentitlementsファイルがプロジェクトに含まれていない場合：

1. **Xcodeでプロジェクトを開く**
2. **File → New → File...**
3. **「Property List」を選択**
4. **ファイル名を `EnglishCard.entitlements` にする**
5. **以下の内容を追加:**

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>com.apple.security.app-sandbox</key>
	<true/>
	<key>com.apple.security.network.client</key>
	<true/>
</dict>
</plist>
```

6. **Build Settings → Code Signing Entitlements に `EnglishCard.entitlements` を設定**

---

## ✅ 最終確認チェックリスト

- [ ] インターネット接続が正常
- [ ] Xcodeの「Signing & Capabilities」で「Outgoing Connections (Client)」がチェック済み
- [ ] entitlementsファイルが正しく設定されている
- [ ] プロジェクトをクリーンビルドした
- [ ] ファイアウォールがアプリをブロックしていない
- [ ] Base URLが `https://api.openai.com` （末尾のスラッシュなし）
- [ ] OpenAI APIキーが正しく入力されている
- [ ] 接続テストで「✅ サーバーに接続成功！」と表示される

---

## 📞 それでも解決しない場合

接続テストの結果（エラーメッセージ全体）をコピーして、以下の情報と一緒に報告してください：

- macOSバージョン
- Xcodeバージョン
- VPN使用の有無
- 接続テストの完全なエラーメッセージ
- Base URL設定
- 構築されたURL

---

## 🌐 ブラウザでの確認方法

ターミナルで以下のコマンドを実行して、OpenAI APIに到達できるか確認：

```bash
curl -X POST https://api.openai.com/v1/chat/completions \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_API_KEY" \
  -d '{"model":"gpt-3.5-turbo","messages":[{"role":"user","content":"test"}]}'
```

**YOUR_API_KEY** を実際のAPIキーに置き換えて実行してください。

**期待される結果:**
- エラーが返ってくる（APIキーが無効な場合）または
- JSON形式のレスポンスが返ってくる（APIキーが有効な場合）

**「Could not resolve host」エラーが出る場合:**
- DNS/ネットワークの問題です

**正常にレスポンスが返ってくる場合:**
- ターミナルからは接続できているので、アプリのSandbox設定の問題です

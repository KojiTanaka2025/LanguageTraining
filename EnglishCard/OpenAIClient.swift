import Foundation
import AVFoundation

struct OpenAIClient {
    let baseURL: URL
    let apiKey: String
    let model: String

    func explainEnglish(text: String) async throws -> String {
        // URLを正しく構築（末尾のスラッシュを考慮）
        var urlString = baseURL.absoluteString
        // 末尾のスラッシュを削除
        while urlString.hasSuffix("/") {
            urlString.removeLast()
        }
        urlString += "/v1/chat/completions"
        
        guard let url = URL(string: urlString) else {
            throw OpenAIError.invalidBaseURL
        }

        let system = """
あなたは英語学習の先生です。ユーザーが貼り付けた英単語/英熟語/英文を学習用カードとして解説します。
必ずMarkdownで、見出しと箇条書きを多用し、読みやすい日本語で出力してください。

重要：
- 「学習カード：」などの前置きは一切不要です
- 単語や文章そのものを見出しとして始めてください

要件:
- 単語の場合：品詞/意味/語源/コロケーション/例文（日本語訳付き）/注意点を含める
- 英文の場合：
  - まず日本語訳を明記
  - 文型・主要構文・修飾関係を説明
  - 時制/助動詞/関係詞/前置詞などの文法要素を解説
  - 重要単語・熟語の解説
  - 例文がある場合は必ず日本語訳を付ける
- 最後に「覚えるポイント」を3〜7個でまとめる
"""

        let user = """
次の内容を解説してください。

\(text)
"""

        let body = ChatCompletionsRequest(
            model: model,
            messages: [
                .init(role: "system", content: system),
                .init(role: "user", content: user)
            ],
            temperature: 0.2
        )

        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        req.httpBody = try JSONEncoder().encode(body)

        let (data, resp): (Data, URLResponse)
        do {
            (data, resp) = try await URLSession.shared.data(for: req)
        } catch {
            // ネットワークエラーをキャッチしてわかりやすくする
            throw OpenAIError.networkError(url: url.absoluteString, underlying: error)
        }
        
        guard let http = resp as? HTTPURLResponse else { throw OpenAIError.invalidResponse }
        if !(200...299).contains(http.statusCode) {
            let apiError = (try? JSONDecoder().decode(OpenAIAPIErrorEnvelope.self, from: data))?.error
            let responseBody = String(data: data, encoding: .utf8)
            throw OpenAIError.http(status: http.statusCode, message: apiError?.message ?? responseBody)
        }

        let decoded = try JSONDecoder().decode(ChatCompletionsResponse.self, from: data)
        let content = decoded.choices.first?.message.content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let content, !content.isEmpty else { throw OpenAIError.emptyCompletion }
        return content
    }
    
    /// テキストを音声に変換して再生する
    /// - Parameters:
    ///   - text: 読み上げるテキスト
    ///   - voice: 音声の種類 (alloy, echo, fable, onyx, nova, shimmer)
    ///   - speed: 読み上げ速度 (0.25〜4.0)
    /// - Returns: 音声データの一時ファイルURL
    func textToSpeech(text: String, voice: String = "onyx", speed: Double = 0.9) async throws -> URL {
        var urlString = baseURL.absoluteString
        while urlString.hasSuffix("/") {
            urlString.removeLast()
        }
        urlString += "/v1/audio/speech"
        
        guard let url = URL(string: urlString) else {
            throw OpenAIError.invalidBaseURL
        }
        
        let body = TTSRequest(
            model: "tts-1",
            voice: voice,
            input: text,
            speed: speed
        )
        
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        req.httpBody = try JSONEncoder().encode(body)
        
        let (data, resp): (Data, URLResponse)
        do {
            (data, resp) = try await URLSession.shared.data(for: req)
        } catch {
            throw OpenAIError.networkError(url: url.absoluteString, underlying: error)
        }
        
        guard let http = resp as? HTTPURLResponse else { throw OpenAIError.invalidResponse }
        if !(200...299).contains(http.statusCode) {
            let apiError = (try? JSONDecoder().decode(OpenAIAPIErrorEnvelope.self, from: data))?.error
            let responseBody = String(data: data, encoding: .utf8)
            throw OpenAIError.http(status: http.statusCode, message: apiError?.message ?? responseBody)
        }
        
        // 一時ファイルに保存
        let tempDir = FileManager.default.temporaryDirectory
        let tempFile = tempDir.appendingPathComponent(UUID().uuidString).appendingPathExtension("mp3")
        try data.write(to: tempFile)
        
        return tempFile
    }
}

// MARK: - Types

private struct TTSRequest: Codable {
    let model: String
    let voice: String
    let input: String
    let speed: Double
}

private struct ChatCompletionsRequest: Codable {
    struct Message: Codable {
        let role: String
        let content: String
    }
    let model: String
    let messages: [Message]
    let temperature: Double?
}

private struct ChatCompletionsResponse: Codable {
    struct Choice: Codable {
        struct Message: Codable {
            let role: String
            let content: String
        }
        let index: Int
        let message: Message
    }
    let choices: [Choice]
}

private struct OpenAIAPIErrorEnvelope: Codable {
    struct APIError: Codable {
        let message: String
        let type: String?
        let code: String?
    }
    let error: APIError
}

enum OpenAIError: Error, LocalizedError {
    case invalidBaseURL
    case invalidResponse
    case http(status: Int, message: String?)
    case emptyCompletion
    case networkError(url: String, underlying: Error)

    var errorDescription: String? {
        switch self {
        case .invalidBaseURL:
            return "Base URLが不正です。設定を確認してください。"
        case .invalidResponse:
            return "API応答が不正です。"
        case .http(let status, let message):
            // 特定のステータスコードに対して分かりやすいメッセージを表示
            if status == 429 {
                return """
                ⚠️ クォータ超過エラー (429)
                
                OpenAI APIの使用量制限に達しました。
                
                📊 対処方法:
                1. OpenAIダッシュボードで残高を確認
                   https://platform.openai.com/account/usage
                
                2. 支払い方法を追加（必要な場合）
                   https://platform.openai.com/account/billing
                
                3. 使用量制限を増やす
                
                詳細: \(message ?? "情報なし")
                """
            } else if status == 401 {
                return """
                🔑 認証エラー (401)
                
                APIキーが無効または期限切れです。
                
                対処方法:
                1. 設定画面（⌘,）でAPIキーを確認
                2. OpenAIで新しいAPIキーを生成
                   https://platform.openai.com/api-keys
                
                詳細: \(message ?? "情報なし")
                """
            } else if status == 403 {
                return """
                🚫 アクセス拒否 (403)
                
                このAPIキーにはアクセス権限がありません。
                
                対処方法:
                1. OpenAIのアカウント設定を確認
                2. 組織の権限設定を確認
                
                詳細: \(message ?? "情報なし")
                """
            } else if (500...599).contains(status) {
                return """
                🔧 サーバーエラー (\(status))
                
                OpenAI側で一時的な問題が発生しています。
                
                対処方法:
                1. 数分後に再試行
                2. OpenAIのステータスページを確認
                   https://status.openai.com
                
                詳細: \(message ?? "情報なし")
                """
            }
            
            if let message, !message.isEmpty {
                return "APIエラー（\(status)）: \(message)"
            }
            return "APIエラー（\(status)）"
        case .emptyCompletion:
            return "AIの出力が空でした。"
        case .networkError(let url, let underlying):
            if (underlying as NSError).domain == NSURLErrorDomain {
                let code = (underlying as NSError).code
                if code == NSURLErrorCannotFindHost {
                    return "サーバーが見つかりません。\n接続先: \(url)\n\n設定画面でBase URLを確認してください。\n正しいURL: https://api.openai.com"
                } else if code == NSURLErrorNotConnectedToInternet {
                    return "インターネット接続がありません。"
                } else if code == NSURLErrorTimedOut {
                    return "接続がタイムアウトしました。"
                }
            }
            return "ネットワークエラー: \(underlying.localizedDescription)\n接続先: \(url)"
        }
    }
}


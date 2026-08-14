import Foundation
import AVFoundation

struct OpenAIClient {
    let baseURL: URL
    let apiKey: String
    let model: String

    nonisolated static let defaultTTSModel = "gpt-4o-mini-tts"
    nonisolated static let defaultTTSVoice = "marin"
    nonisolated static let defaultTTSInstructions = "Speak clearly for language learners. Use a calm, natural pace with crisp articulation, natural intonation, and slightly emphasized word boundaries."

    func explainEnglish(text: String, explanationLanguage: String = "English") async throws -> String {
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
        guard url.scheme?.lowercased() == "https" else {
            throw OpenAIError.invalidBaseURL
        }

        let template = Self.localizedExplanationTemplate(for: explanationLanguage)
        let styleGuide = Self.writingStyle(for: explanationLanguage)
        let system = """
You are a patient English teacher for beginner to intermediate learners (about CEFR A2–B1).

The user is an English learner. Your job is a learning card they can understand in a few seconds, then reuse.

Learner-first rules:
- Put meaning first. Grammar comes after the learner already understands the idea.
- Write the whole card in \(explanationLanguage).
- \(styleGuide)
- Use short sentences. One idea per bullet.
- Do not use grammar jargon alone. If you need a term, add a plain-language gloss in parentheses, then show it inside the learner's actual text.
- Always explain with the learner's words. Never give empty patterns like "S + V + O" without filling them from the text.
- After meaning, always teach the grammar that actually appears in the text.
- Cover articles (a / an / the / none), prepositions, tense and verb form, and any other grammar that matters here (countable vs uncountable nouns, verb patterns, auxiliaries, relative clauses, comparatives, conditionals, word order). Only explain what is in this text.
- For each grammar point: name it in simple words, show the exact words from the text, say why this form is used, and give a short contrast when it helps (for example a vs the, in vs at, I go vs I am going).
- If the text is English, do not skip grammar. Even one word has a word class, an article choice, or a word form to explain.
- If the source text is not English, explain the grammar of the natural English equivalent, plus any original-language point the learner needs.
- If the source text is English, teach that English: meaning, stress, useful chunks, and when to say it.
- If the source text is not English, still help an English learner: give a natural English equivalent they can remember, plus anything needed to understand the original.
- Mark the target word or phrase in **bold** in examples.
- Keep examples short and useful in daily life.
- For English, mark stress with CAPITALS on the strong syllable (for example proCRASTinate) and give one practical pronunciation tip.
- For Vietnamese source text, include tone and pronunciation help.
- Do not pad. If a field does not apply, write the localized equivalent of "Not applicable" with a brief reason.

Output rules:
- Markdown only. No greeting and no label such as "Learning card:".
- Use the exact localized headings, field labels, section order, and structure in the template.
- Do not translate the top-level title after "#"; keep the user's original text there.
- Do not leave any heading or field label in English unless \(explanationLanguage) is English.

Template:
\(template)
"""

        let user = """
Create a clear learning card for an English learner. Explain this text in \(explanationLanguage):

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

    private static func writingStyle(for language: String) -> String {
        switch language {
        case "Japanese":
            return "中学生でも読める日本語で書く。ですます調。文法用語を使うなら、すぐにかっこでやさしい言い換えを付ける。"
        case "Vietnamese":
            return "Viết bằng tiếng Việt dễ hiểu, câu ngắn, tránh thuật ngữ trừu tượng trừ khi giải thích ngay."
        case "Korean":
            return "중학생도 읽을 수 있는 쉬운 한국어로 쓴다. 문법 용어를 쓰면 바로 쉬운 말로 풀어 준다."
        case "Simplified Chinese":
            return "用初中生能看懂的简体中文写。句子要短。若使用语法术语，立刻用白话解释。"
        case "Traditional Chinese":
            return "用國中生能看懂的繁體中文寫。句子要短。若使用文法術語，立刻用白話解釋。"
        case "French":
            return "Écris en français simple, phrases courtes. Si tu utilises un terme grammatical, explique-le tout de suite avec des mots faciles."
        case "Spanish":
            return "Escribe en español sencillo, frases cortas. Si usas un término gramatical, explícalo de inmediato con palabras fáciles."
        case "German":
            return "Schreibe in einfachem Deutsch, kurze Sätze. Grammatikbegriffe sofort mit einfachen Worten erklären."
        default:
            return "Write in easy English a B1 learner can follow. Short sentences. Common words. If you use a grammar term, explain it immediately in plain words."
        }
    }

    private static func localizedExplanationTemplate(for language: String) -> String {
        switch language {
        case "Japanese":
            return """
            # {ユーザーの原文}

            ## 1. まずは意味
            - かんたんな言い方:
            - 自然な日本語訳:
            - 自然な英語（学習用）:
            - どんなときに使う:
            - カジュアル / フォーマル:

            ## 2. 発音のポイント
            - 強く読む音:
            - 発音のコツ:

            ## 3. 文のしくみ
            - 種類: 単語 / フレーズ / 文
            - パーツごと（原文の順。「原文」= やさしい意味）:
            - 同じ型で言えるパターン:

            ## 4. 文法の解説
            - 時制・形（いま / 過去 / 進行など）:
            - 冠詞（a / an / the / なし）:
            - 前置詞:
            - この文に出るほかの文法（可算・不可算、動詞の形、助動詞、関係詞など）:
            - なぜこの形なのか（原文の語を使って、似た形との違いも）:

            ## 5. 覚えておきたい語句
            - 2〜5個。各語句は「やさしい意味 / よく一緒に使う語」:

            ## 6. 使える例
            - 例文1（太字で学習箇所を示す）:
            - 意味:
            - 例文2:
            - 意味:

            ## 7. まちがいやすいところ
            - 似た表現との違い:
            - やりがちなミス:

            ## 8. これだけ覚えよう
            - 短いポイントを3つ:
            """
        case "Vietnamese":
            return """
            # {nguyên văn của người dùng}

            ## 1. Ý nghĩa trước
            - Nói dễ hiểu:
            - Bản dịch tiếng Việt tự nhiên:
            - Câu tiếng Anh tự nhiên (để học):
            - Khi nào dùng:
            - Thân mật / trang trọng:

            ## 2. Cách đọc
            - Âm nhấn:
            - Mẹo phát âm:

            ## 3. Cách cấu tạo
            - Loại: từ / cụm từ / câu
            - Từng phần (theo đúng thứ tự nguyên văn):
            - Mẫu câu có thể dùng lại:

            ## 4. Giải thích ngữ pháp
            - Thì / dạng (hiện tại / quá khứ / đang diễn ra...):
            - Mạo từ (a / an / the / không có):
            - Giới từ:
            - Ngữ pháp khác trong câu này (đếm được / không đếm được, dạng động từ, trợ động từ, mệnh đề quan hệ...):
            - Vì sao dùng dạng này (dùng đúng chữ trong nguyên văn, so với dạng gần giống):

            ## 5. Từ cần nhớ
            - 2 đến 5 mục: nghĩa dễ / từ hay đi kèm:

            ## 6. Ví dụ dùng được
            - Ví dụ 1 (in đậm phần cần học):
            - Nghĩa:
            - Ví dụ 2:
            - Nghĩa:

            ## 7. Dễ nhầm
            - Khác với cách nói gần giống:
            - Lỗi người học hay mắc:

            ## 8. Chỉ cần nhớ
            - 3 ý ngắn:
            """
        case "Korean":
            return """
            # {사용자의 원문}

            ## 1. 먼저 의미
            - 쉬운 말:
            - 자연스러운 한국어:
            - 자연스러운 영어 (학습용):
            - 언제 쓰나:
            - 캐주얼 / 격식:

            ## 2. 발음 포인트
            - 강하게 읽는 부분:
            - 발음 팁:

            ## 3. 문장 구조
            - 유형: 단어 / 구 / 문장
            - 조각별로 (원문 순서, 「원문」= 쉬운 뜻):
            - 같은 틀로 말하는 패턴:

            ## 4. 문법 설명
            - 시제 / 형태 (지금 / 과거 / 진행 등):
            - 관사 (a / an / the / 없음):
            - 전치사:
            - 이 문에 나오는 다른 문법 (가산/불가산, 동사 형태, 조동사, 관계절 등):
            - 왜 이 형태인지 (원문 단어를 쓰고, 비슷한 형태와 비교):

            ## 5. 기억할 어휘
            - 2~5개. 각 항목은 쉬운 뜻 / 자주 같이 쓰는 말:

            ## 6. 써보는 예
            - 예문 1 (배울 부분을 굵게):
            - 의미:
            - 예문 2:
            - 의미:

            ## 7. 헷갈리기 쉬운 점
            - 비슷한 표현과의 차이:
            - 학습자가 자주 하는 실수:

            ## 8. 이것만 기억
            - 짧은 포인트 3개:
            """
        case "Simplified Chinese":
            return """
            # {用户的原文}

            ## 1. 先看意思
            - 简单说法:
            - 自然的简体中文:
            - 自然的英语（用来学）:
            - 什么时候用:
            - 随意 / 正式:

            ## 2. 发音要点
            - 重读的部分:
            - 发音提示:

            ## 3. 怎么组成
            - 类型: 单词 / 短语 / 句子
            - 按原文顺序拆开（「原文」= 简单意思）:
            - 可以套用的句型:

            ## 4. 语法说明
            - 时态 / 形式（现在 / 过去 / 进行等）:
            - 冠词（a / an / the / 不用）:
            - 介词:
            - 这句话里其他重要语法（可数/不可数、动词形式、助动词、定语从句等）:
            - 为什么用这个形式（用原文的词，并和相近形式对比）:

            ## 5. 要记住的词
            - 2到5个。每项: 简单意思 / 常一起出现的词:

            ## 6. 可以这样说
            - 例句1（学习部分加粗）:
            - 意思:
            - 例句2:
            - 意思:

            ## 7. 容易搞混
            - 和相近说法的差别:
            - 学习者常犯的错:

            ## 8. 只记这些
            - 3个短要点:
            """
        case "Traditional Chinese":
            return """
            # {使用者的原文}

            ## 1. 先看意思
            - 簡單說法:
            - 自然的繁體中文:
            - 自然的英語（用來學）:
            - 什麼時候用:
            - 隨興 / 正式:

            ## 2. 發音重點
            - 重讀的部分:
            - 發音提示:

            ## 3. 怎麼組成
            - 類型: 單字 / 片語 / 句子
            - 依原文順序拆開（「原文」= 簡單意思）:
            - 可以套用的句型:

            ## 4. 文法說明
            - 時態 / 形式（現在 / 過去 / 進行等）:
            - 冠詞（a / an / the / 不用）:
            - 介詞:
            - 這句裡其他重要文法（可數/不可數、動詞形式、助動詞、關係子句等）:
            - 為什麼用這個形式（用原文的詞，並和相近形式對比）:

            ## 5. 要記住的詞
            - 2到5個。每項: 簡單意思 / 常一起出現的詞:

            ## 6. 可以這樣說
            - 例句1（學習部分加粗）:
            - 意思:
            - 例句2:
            - 意思:

            ## 7. 容易搞混
            - 和相近說法的差別:
            - 學習者常犯的錯:

            ## 8. 只記這些
            - 3個短要點:
            """
        case "French":
            return """
            # {texte original de l'utilisateur}

            ## 1. D'abord le sens
            - En mots simples:
            - Traduction naturelle en français:
            - Anglais naturel (à apprendre):
            - Quand l'utiliser:
            - Familier / formel:

            ## 2. Comment ça se prononce
            - Accent (syllabe forte):
            - Conseil de prononciation:

            ## 3. Comment c'est construit
            - Type: mot / groupe de mots / phrase
            - Morceau par morceau (dans l'ordre du texte):
            - Un modèle à réutiliser:

            ## 4. Grammaire
            - Temps / forme (présent / passé / en cours...):
            - Articles (a / an / the / aucun):
            - Prépositions:
            - Autre grammaire dans ce texte (comptable / non comptable, forme du verbe, auxiliaires, relatives...):
            - Pourquoi cette forme (avec les mots du texte, et un court contraste):

            ## 5. Mots utiles
            - 2 à 5 items: sens facile / mots qui vont souvent ensemble:

            ## 6. Exemples à essayer
            - Exemple 1 (mettre en gras le point à apprendre):
            - Sens:
            - Exemple 2:
            - Sens:

            ## 7. Facile à confondre
            - Différence avec une expression proche:
            - Erreur fréquente des apprenants:

            ## 8. À retenir
            - 3 points courts:
            """
        case "Spanish":
            return """
            # {texto original del usuario}

            ## 1. Primero el significado
            - En palabras fáciles:
            - Traducción natural al español:
            - Inglés natural (para aprender):
            - Cuándo usarlo:
            - Informal / formal:

            ## 2. Cómo suena
            - Acento (sílaba fuerte):
            - Consejo de pronunciación:

            ## 3. Cómo está construido
            - Tipo: palabra / frase / oración
            - Trozo a trozo (en el mismo orden del texto):
            - Un patrón para reutilizar:

            ## 4. Gramática
            - Tiempo / forma (presente / pasado / en curso...):
            - Artículos (a / an / the / ninguno):
            - Preposiciones:
            - Otra gramática de este texto (contable / incontable, forma del verbo, auxiliares, oraciones de relativo...):
            - Por qué se usa esta forma (con las palabras del texto y un contraste breve):

            ## 5. Palabras útiles
            - 2 a 5 ítems: significado fácil / palabras que suelen ir juntas:

            ## 6. Prueba estos ejemplos
            - Ejemplo 1 (en negrita lo que hay que aprender):
            - Significado:
            - Ejemplo 2:
            - Significado:

            ## 7. Fácil de confundir
            - Diferencia con una expresión parecida:
            - Error frecuente de quienes aprenden:

            ## 8. Recuerda
            - 3 puntos cortos:
            """
        case "German":
            return """
            # {Originaltext des Benutzers}

            ## 1. Zuerst die Bedeutung
            - In einfachen Worten:
            - Natürliche deutsche Übersetzung:
            - Natürliches Englisch (zum Lernen):
            - Wann man es sagt:
            - Locker / förmlich:

            ## 2. Aussprache
            - Betonte Silbe:
            - Aussprachetipp:

            ## 3. So ist es gebaut
            - Typ: Wort / Phrase / Satz
            - Stück für Stück (in der Reihenfolge des Texts):
            - Ein Muster zum Wiederverwenden:

            ## 4. Grammatik
            - Zeitform (jetzt / Vergangenheit / Verlauf...):
            - Artikel (a / an / the / keiner):
            - Präpositionen:
            - Weitere Grammatik in diesem Text (zählbar / unzählbar, Verbform, Hilfsverben, Relativsätze...):
            - Warum diese Form (mit den Wörtern aus dem Text und einem kurzen Vergleich):

            ## 5. Nützliche Wörter
            - 2 bis 5 Einträge: einfache Bedeutung / Wörter, die oft dazugehören:

            ## 6. Beispiele zum Ausprobieren
            - Beispiel 1 (Lernstelle fett):
            - Bedeutung:
            - Beispiel 2:
            - Bedeutung:

            ## 7. Leicht zu verwechseln
            - Unterschied zu einer ähnlichen Wendung:
            - Typischer Fehler von Lernenden:

            ## 8. Merken
            - 3 kurze Punkte:
            """
        default:
            return """
            # {the user's original text}

            ## 1. Simple meaning
            - In easy words:
            - Natural translation in \(language):
            - Natural English to remember:
            - When to use it:
            - Casual or formal:

            ## 2. How it sounds
            - Stress (CAPITALS on the strong part):
            - Pronunciation tip:

            ## 3. How it is built
            - Type: word / phrase / sentence
            - Piece by piece (same order as the text; "original" = easy meaning):
            - A pattern you can reuse:

            ## 4. Grammar
            - Tense / form (now / past / ongoing, etc.):
            - Articles (a / an / the / none):
            - Prepositions:
            - Other grammar in this text (countable vs uncountable, verb form, auxiliaries, relative clauses, etc.):
            - Why this form is used (with the original words, plus a short contrast):

            ## 5. Useful words
            - 2 to 5 items: easy meaning / words that often go with it:

            ## 6. Try these
            - Example 1 (bold the part to learn):
            - Meaning:
            - Example 2:
            - Meaning:

            ## 7. Easy to mix up
            - Similar expression vs this one:
            - Common learner mistake:

            ## 8. Remember
            - 3 short points:
            """
        }
    }
    
    /// テキストを音声に変換して再生する
    /// - Parameters:
    ///   - text: 読み上げるテキスト
    ///   - voice: 音声の種類。聞き取りやすさを優先し、既定ではOpenAI推奨の高品質音声を使う
    ///   - speed: 読み上げ速度 (0.25〜4.0)
    /// - Returns: 音声データの一時ファイルURL
    func textToSpeech(text: String, voice: String = Self.defaultTTSVoice, speed: Double = 0.9) async throws -> URL {
        var urlString = baseURL.absoluteString
        while urlString.hasSuffix("/") {
            urlString.removeLast()
        }
        urlString += "/v1/audio/speech"
        
        guard let url = URL(string: urlString) else {
            throw OpenAIError.invalidBaseURL
        }
        guard url.scheme?.lowercased() == "https" else {
            throw OpenAIError.invalidBaseURL
        }
        
        let body = TTSRequest(
            model: Self.defaultTTSModel,
            voice: voice,
            input: text,
            speed: speed,
            instructions: Self.defaultTTSInstructions
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
    let instructions: String
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
            return "The Base URL is invalid. Check your settings."
        case .invalidResponse:
            return "The API response was invalid."
        case .http(let status, let message):
            // 特定のステータスコードに対して分かりやすいメッセージを表示
            if status == 429 {
                return """
                Quota exceeded (429)
                
                Your OpenAI API usage limit has been reached.
                
                How to fix it:
                1. Check your usage in the OpenAI dashboard:
                   https://platform.openai.com/account/usage
                
                2. Add a payment method if needed:
                   https://platform.openai.com/account/billing
                
                3. Increase your usage limit.
                
                Details: \(message ?? "No details")
                """
            } else if status == 401 {
                return """
                Authentication error (401)
                
                The API key is invalid or expired.
                
                How to fix it:
                1. Check your API key in Settings.
                2. Generate a new API key:
                   https://platform.openai.com/api-keys
                
                Details: \(message ?? "No details")
                """
            } else if status == 403 {
                return """
                Access denied (403)
                
                This API key does not have permission to access this resource.
                
                How to fix it:
                1. Check your OpenAI account settings.
                2. Check your organization permissions.
                
                Details: \(message ?? "No details")
                """
            } else if (500...599).contains(status) {
                return """
                Server error (\(status))
                
                OpenAI may be experiencing a temporary issue.
                
                How to fix it:
                1. Try again in a few minutes.
                2. Check the OpenAI status page:
                   https://status.openai.com
                
                Details: \(message ?? "No details")
                """
            }
            
            if let message, !message.isEmpty {
                return "API error (\(status)): \(message)"
            }
            return "API error (\(status))"
        case .emptyCompletion:
            return "The AI response was empty."
        case .networkError(let url, let underlying):
            if (underlying as NSError).domain == NSURLErrorDomain {
                let code = (underlying as NSError).code
                if code == NSURLErrorCannotFindHost {
                    return "The server could not be found.\nEndpoint: \(url)\n\nCheck the Base URL in Settings.\nCorrect URL: https://api.openai.com"
                } else if code == NSURLErrorNotConnectedToInternet {
                    return "No internet connection."
                } else if code == NSURLErrorTimedOut {
                    return "The connection timed out."
                }
            }
            return "Network error: \(underlying.localizedDescription)\nEndpoint: \(url)"
        }
    }
}

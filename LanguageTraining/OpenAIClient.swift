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

        let template = Self.localizedExplanationTemplate(for: explanationLanguage)
        let system = """
You are a multilingual language-learning teacher. Explain the pasted word, phrase, or sentence as a learning card, regardless of the source language.

Output rules:
- Always write in Markdown.
- Do not include greetings, prefaces, or labels such as "Learning card:".
- Always use the exact localized section headings, field labels, section order, and structure in the template below.
- Do not omit any section. If a section does not apply, use the localized equivalent of "Not applicable" with a brief reason.
- Write the full explanation in \(explanationLanguage).
- Do not translate the top-level title after "#"; keep the user's original text there.
- Do not leave any section heading or field label in English unless \(explanationLanguage) is English.
- Keep grammar explanations concrete and easy for beginner to intermediate learners to follow.
- Detect the source language from the user's text.
- Explicitly support Vietnamese input, including Vietnamese tone marks and pronunciation notes.
- If the source text is not English, include a translation in \(explanationLanguage) and explain any source-language grammar that matters for understanding it.
- If the source text is already in \(explanationLanguage), use the original text as the translation.
- Preserve the original script for examples, and add romanization only when it helps learners read the text.

Template:
\(template)
"""

        let user = """
Explain the following text in \(explanationLanguage).

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

    private static func localizedExplanationTemplate(for language: String) -> String {
        switch language {
        case "Japanese":
            return """
            # {ユーザーの原文}

            ## 1. 元の言語と訳
            - 元の言語:
            - 日本語訳:
            - ニュアンス:

            ## 2. 文法と構造
            - 種別: 単語 / フレーズ / 文
            - 品詞または文型:
            - 主語・動詞・目的語・補語:
            - 修飾関係:
            - 時制・助詞・助動詞・語順・活用・前置詞・関係節など:
            - ベトナム語の場合は、声調、類別詞、助詞、語順、アスペクト標識、代名詞、丁寧さも必要に応じて説明:

            ## 3. 重要語句
            - 原文から重要な語句を3〜6個説明:
            - 必要に応じてローマ字表記や発音メモ:

            ## 4. 使い方と例文
            - 元の言語の例文1:
            - 日本語での意味:
            - 元の言語の例文2:
            - 日本語での意味:

            ## 5. 間違えやすいポイント
            - 発音、使い方、文法、レジスター、似た表現との違い:

            ## 6. 覚えるポイント
            - 重要点を3〜5個の短い箇条書きで要約:
            """
        case "Vietnamese":
            return """
            # {nguyên văn của người dùng}

            ## 1. Ngôn ngữ gốc và bản dịch
            - Ngôn ngữ gốc:
            - Bản dịch tiếng Việt:
            - Sắc thái:

            ## 2. Ngữ pháp và cấu trúc
            - Loại: từ / cụm từ / câu
            - Từ loại hoặc mẫu câu:
            - Chủ ngữ, động từ, tân ngữ, bổ ngữ:
            - Thành phần bổ nghĩa:
            - Thì, tiểu từ, trợ động từ, trật tự từ, biến đổi hình thái, giới từ, mệnh đề quan hệ hoặc ngữ pháp quan trọng khác:
            - Với tiếng Việt, hãy giải thích thanh điệu, lượng từ, tiểu từ, trật tự từ, dấu hiệu thể, đại từ và sắc thái lịch sự khi phù hợp:

            ## 3. Từ vựng quan trọng
            - Giải thích 3 đến 6 từ hoặc cụm từ quan trọng trong nguyên văn:
            - Thêm ghi chú phát âm hoặc phiên âm khi hữu ích:

            ## 4. Cách dùng và ví dụ
            - Ví dụ 1 bằng ngôn ngữ gốc:
            - Nghĩa tiếng Việt:
            - Ví dụ 2 bằng ngôn ngữ gốc:
            - Nghĩa tiếng Việt:

            ## 5. Điểm dễ nhầm lẫn
            - Phát âm, cách dùng, ngữ pháp, sắc thái giao tiếp hoặc điểm khác với cách diễn đạt tương tự:

            ## 6. Điểm cần ghi nhớ
            - Tóm tắt các điểm quan trọng nhất bằng 3 đến 5 gạch đầu dòng ngắn:
            """
        case "Korean":
            return """
            # {사용자의 원문}

            ## 1. 원어와 번역
            - 원어:
            - 한국어 번역:
            - 뉘앙스:

            ## 2. 문법과 구조
            - 유형: 단어 / 구 / 문장
            - 품사 또는 문장 패턴:
            - 주어, 동사, 목적어, 보어:
            - 수식 관계:
            - 시제, 조사, 조동사, 어순, 활용, 전치사, 관계절 또는 기타 핵심 문법:
            - 베트남어인 경우 성조, 분류사, 조사, 어순, 상 표지, 대명사, 격식을 필요에 따라 설명:

            ## 3. 핵심 어휘
            - 원문에서 중요한 단어나 표현 3~6개 설명:
            - 필요하면 로마자 표기나 발음 메모 추가:

            ## 4. 사용법과 예문
            - 원어 예문 1:
            - 한국어 의미:
            - 원어 예문 2:
            - 한국어 의미:

            ## 5. 헷갈리기 쉬운 점
            - 발음, 용법, 문법, 격식, 비슷한 표현과의 차이:

            ## 6. 기억할 핵심
            - 가장 중요한 점을 3~5개의 짧은 bullet로 요약:
            """
        case "Simplified Chinese":
            return """
            # {用户的原文}

            ## 1. 原语言和翻译
            - 原语言:
            - 简体中文翻译:
            - 语气和细微差别:

            ## 2. 语法和结构
            - 类型: 单词 / 短语 / 句子
            - 词性或句型:
            - 主语、动词、宾语、补语:
            - 修饰关系:
            - 时态、助词、助动词、语序、屈折变化、介词、关系从句或其他重点语法:
            - 如果是越南语，请根据需要说明声调、量词、小品词、语序、体标记、代词和语体:

            ## 3. 重点词汇
            - 从原文中解释3到6个重要单词或短语:
            - 必要时加入罗马字或发音说明:

            ## 4. 用法和例句
            - 原语言例句1:
            - 简体中文意思:
            - 原语言例句2:
            - 简体中文意思:

            ## 5. 容易混淆的点
            - 发音、用法、语法、语体或相似表达的区别:

            ## 6. 记忆要点
            - 用3到5条简短要点总结:
            """
        case "Traditional Chinese":
            return """
            # {使用者的原文}

            ## 1. 原語言和翻譯
            - 原語言:
            - 繁體中文翻譯:
            - 語氣和細微差別:

            ## 2. 文法和結構
            - 類型: 單字 / 片語 / 句子
            - 詞性或句型:
            - 主詞、動詞、受詞、補語:
            - 修飾關係:
            - 時態、助詞、助動詞、語序、屈折變化、介詞、關係子句或其他重點文法:
            - 如果是越南語，請視需要說明聲調、量詞、小品詞、語序、體標記、代名詞和語體:

            ## 3. 重點詞彙
            - 從原文中說明3到6個重要單字或片語:
            - 必要時加入羅馬字或發音說明:

            ## 4. 用法和例句
            - 原語言例句1:
            - 繁體中文意思:
            - 原語言例句2:
            - 繁體中文意思:

            ## 5. 容易混淆的點
            - 發音、用法、文法、語體或相似表達的差異:

            ## 6. 記憶重點
            - 用3到5條簡短要點總結:
            """
        case "French":
            return """
            # {texte original de l'utilisateur}

            ## 1. Langue source et traduction
            - Langue source:
            - Traduction en français:
            - Nuance:

            ## 2. Grammaire et structure
            - Type: mot / groupe de mots / phrase
            - Nature grammaticale ou modèle de phrase:
            - Sujet, verbe, objet, complément:
            - Modificateurs:
            - Temps, particules, auxiliaires, ordre des mots, flexion, prépositions, propositions relatives ou autre point de grammaire important:
            - Pour le vietnamien, expliquer les tons, classificateurs, particules, ordre des mots, marqueurs d'aspect, pronoms et registre si pertinent:

            ## 3. Vocabulaire clé
            - Expliquer 3 à 6 mots ou expressions importants du texte source:
            - Ajouter une romanisation ou des notes de prononciation si utile:

            ## 4. Usage et exemples
            - Exemple 1 dans la langue source:
            - Sens en français:
            - Exemple 2 dans la langue source:
            - Sens en français:

            ## 5. Points souvent confondus
            - Prononciation, usage, grammaire, registre ou différences avec des expressions proches:

            ## 6. Points à retenir
            - Résumer les points essentiels en 3 à 5 puces courtes:
            """
        case "Spanish":
            return """
            # {texto original del usuario}

            ## 1. Idioma de origen y traducción
            - Idioma de origen:
            - Traducción al español:
            - Matiz:

            ## 2. Gramática y estructura
            - Tipo: palabra / frase / oración
            - Categoría gramatical o patrón de oración:
            - Sujeto, verbo, objeto, complemento:
            - Modificadores:
            - Tiempo verbal, partículas, auxiliares, orden de palabras, flexión, preposiciones, oraciones relativas u otra gramática clave:
            - Para vietnamita, explicar tonos, clasificadores, partículas, orden de palabras, marcadores de aspecto, pronombres y registro cuando sea relevante:

            ## 3. Vocabulario clave
            - Explicar de 3 a 6 palabras o expresiones importantes del texto original:
            - Añadir romanización o notas de pronunciación cuando sea útil:

            ## 4. Uso y ejemplos
            - Ejemplo 1 en el idioma de origen:
            - Significado en español:
            - Ejemplo 2 en el idioma de origen:
            - Significado en español:

            ## 5. Puntos que suelen causar confusión
            - Pronunciación, uso, gramática, registro o diferencias con expresiones similares:

            ## 6. Puntos clave
            - Resumir lo más importante en 3 a 5 viñetas breves:
            """
        case "German":
            return """
            # {Originaltext des Benutzers}

            ## 1. Ausgangssprache und Übersetzung
            - Ausgangssprache:
            - Deutsche Übersetzung:
            - Nuance:

            ## 2. Grammatik und Struktur
            - Typ: Wort / Phrase / Satz
            - Wortart oder Satzmuster:
            - Subjekt, Verb, Objekt, Ergänzung:
            - Modifikatoren:
            - Tempus, Partikeln, Hilfsverben, Wortstellung, Flexion, Präpositionen, Relativsätze oder andere wichtige Grammatik:
            - Bei Vietnamesisch nach Bedarf Töne, Klassifikatoren, Partikeln, Wortstellung, Aspektmarker, Pronomen und Register erklären:

            ## 3. Wichtiger Wortschatz
            - 3 bis 6 wichtige Wörter oder Ausdrücke aus dem Originaltext erklären:
            - Bei Bedarf Romanisierung oder Aussprachehinweise hinzufügen:

            ## 4. Verwendung und Beispiele
            - Beispiel 1 in der Ausgangssprache:
            - Bedeutung auf Deutsch:
            - Beispiel 2 in der Ausgangssprache:
            - Bedeutung auf Deutsch:

            ## 5. Häufige Stolperstellen
            - Aussprache, Verwendung, Grammatik, Register oder Unterschiede zu ähnlichen Ausdrücken:

            ## 6. Merkpunkte
            - Die wichtigsten Punkte in 3 bis 5 kurzen Stichpunkten zusammenfassen:
            """
        default:
            return """
            # {the user's original text}

            ## 1. Source Language and Translation
            - Source language:
            - Translation in \(language):
            - Nuance:

            ## 2. Grammar and Structure
            - Type: word / phrase / sentence
            - Part of speech or sentence pattern:
            - Subject, verb, object, complement:
            - Modifiers:
            - Tense, particles, auxiliaries, word order, inflection, prepositions, relative clauses, or other key grammar:
            - For Vietnamese, include tones, classifiers, particles, word order, aspect markers, pronouns, and register when relevant:

            ## 3. Key Vocabulary
            - Explain 3 to 6 important words or phrases from the source text:
            - Include romanization or pronunciation notes when useful:

            ## 4. Usage and Examples
            - Example 1 in the source language:
            - Meaning in \(language):
            - Example 2 in the source language:
            - Meaning in \(language):

            ## 5. Common Pitfalls
            - Explain important pronunciation, usage, grammar, register, or differences from similar expressions:

            ## 6. Key Takeaways
            - Summarize the most important points in 3 to 5 short bullets:
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

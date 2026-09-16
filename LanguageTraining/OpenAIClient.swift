import Foundation
import AVFoundation

struct OpenAIClient {
    let baseURL: URL
    let apiKey: String
    let model: String

    nonisolated static let defaultTTSModel = "gpt-4o-mini-tts"
    nonisolated static let defaultTTSVoice = "marin"
    nonisolated static let defaultTTSInstructions = "Speak clearly for language learners. Use a calm, natural pace with crisp articulation, natural intonation, and slightly emphasized word boundaries."

    func explainEnglish(text: String, explanationLanguage: String = "English") async throws -> ExplanationResult {
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

        let useStructuredJapanese = explanationLanguage == "Japanese"
        let styleGuide = Self.writingStyle(for: explanationLanguage)
        let system: String
        let user: String
        let responseFormat: ChatCompletionsRequest.ResponseFormat?

        if useStructuredJapanese {
            system = """
You are a patient English teacher for one adult learner.

The learner is a man in his 50s. His English is about CEFR A2. He wants to work at a foreign company. Treat him as a capable adult: clear, respectful, and practical. Never write as if for a child or a junior-high student.

Your job is a learning card he can understand quickly, then reuse at work and in adult daily life.

Learner-first rules:
- Put meaning first. Grammar comes after the learner already understands the idea.
- Write field values in Japanese, except structure chunks, the reusable pattern, and vocabulary english entries, which must keep SOURCE English.
- \(styleGuide)
- Use short sentences. One idea per field. The japanese translation field is an exception: write one idiomatic sentence a native speaker would actually say, not a word-by-word gloss.
- Never follow English word order in the translation. Recast it.
- Do not use grammar jargon alone. If you need a term, add a plain-language gloss in parentheses.
- Always explain with the learner's words from the text.
- Structure.parts: split the SOURCE English in order. Each chunk is `English = short Japanese gloss`.
- Structure.pattern: English pattern the learner can copy, plus a short Japanese gloss.
- Vocabulary items: english is the English chunk; gloss is Japanese; collocations are English.
- Mark the target word or phrase with **bold** inside example sentences.
- Keep examples short. Prefer workplace English and adult daily life.
- For stress, use CAPITALS on the strong syllable (for example proCRASTinate).
- If a field does not apply, write 「該当なし」 with a brief reason.
- Do not include the original source text in any field. The app already shows it.
- Return ONLY a JSON object. No markdown fencing.

JSON schema:
{
  "translation": {
    "japanese": "自然な日本語訳",
    "naturalEnglish": "自然な英語（学習用）",
    "usage": "どんなときに使う",
    "formality": "カジュアル / フォーマル"
  },
  "pronunciation": { "stress": "強く読む音", "tips": "発音のコツ" },
  "structure": { "kind": "単語 / フレーズ / 文", "parts": "パーツごと", "pattern": "同じ型で言えるパターン" },
  "grammar": {
    "tense": "時制・形",
    "articles": "冠詞",
    "prepositions": "前置詞",
    "other": "この文に出るほかの文法",
    "why": "なぜこの形なのか"
  },
  "vocabulary": [{ "english": "English chunk", "gloss": "日本語", "collocations": "collocations" }],
  "examples": [{ "sentence": "example with **bold**", "meaning": "意味" }],
  "notes": { "similar": "似た表現との違い", "mistakes": "やりがちなミス" },
  "summary": ["要点1", "要点2", "要点3"]
}
"""
            user = """
Create a structured learning card as JSON for this English text:

\(text)
"""
            responseFormat = .init(type: "json_object")
        } else {
            let template = Self.localizedExplanationTemplate(for: explanationLanguage)
            system = """
You are a patient English teacher for one adult learner.

The learner is a man in his 50s. His English is about CEFR A2. He wants to work at a foreign company. Treat him as a capable adult: clear, respectful, and practical. Never write as if for a child or a junior-high student.

Your job is a learning card he can understand quickly, then reuse at work and in adult daily life.

Learner-first rules:
- Put meaning first. Grammar comes after the learner already understands the idea.
- Write the whole card in \(explanationLanguage), except the structure chunks, the reusable pattern, and the useful-word entries, which must keep the SOURCE English.
- \(styleGuide)
- Use short sentences. One idea per bullet. The natural-translation field is an exception: write one idiomatic sentence a native speaker would actually say, not a word-by-word gloss.
- Never follow English word order in the translation. Recast it. English "That is where X came in" means "that is when / why X became the solution", not a physical place. Bad Japanese: 「それがXが登場したところです。」 Good Japanese: 「そこで登場したのが、Xです。」
- Do not use grammar jargon alone. If you need a term, add a plain-language gloss in parentheses, then show it inside the learner's actual text.
- Always explain with the learner's words. Never give empty patterns like "S + V + O" without filling them from the text.
- After meaning, always teach the grammar that actually appears in the text.
- Cover articles (a / an / the / none), prepositions, tense and verb form, and any other grammar that matters here (countable vs uncountable nouns, verb patterns, auxiliaries, relative clauses, comparatives, conditionals, word order). Only explain what is in this text.
- For each grammar point: name it in simple words, show the exact words from the text, say why this form is used, and give a short contrast when it helps (for example a vs the, in vs at, I go vs I am going).
- If the text is English, do not skip grammar. Even one word has a word class, an article choice, or a word form to explain.
- If the source text is not English, explain the grammar of the natural English equivalent, plus any original-language point the learner needs.
- If the source text is English, teach that English: meaning, stress, useful chunks, and when to say it.
- If the source text is not English, still help an English learner: give a natural English equivalent they can remember, plus anything needed to understand the original.
- Structure section: split the SOURCE English in order, never the translation. Each chunk is `English = short gloss in \(explanationLanguage)`. The reusable pattern must be English the learner can copy, plus a short gloss. Bad: 「XはYではありません。」 Good: "X is not just Y."（Xは単なるYではない）.
- Useful words section: the items to remember are English words or chunks, not translations. Format: `**English** = gloss in \(explanationLanguage) / English collocations`. Bad: エージェンティックAI / 単なる. Good: **agentic AI** = 自ら考えて動くAI / **not just**, **with a few tools**.
- Mark the target word or phrase in **bold** in examples.
- Keep examples short. Prefer workplace English and adult daily life (meetings, email, colleagues, clients, travel for work), not schoolroom examples.
- For English, mark stress with CAPITALS on the strong syllable (for example proCRASTinate) and give one practical pronunciation tip.
- For Vietnamese source text, include tone and pronunciation help.
- Do not pad. If a field does not apply, write the localized equivalent of "Not applicable" with a brief reason.

Output rules:
- Markdown only. No greeting and no label such as "Learning card:".
- Use the exact localized headings, field labels, section order, and structure in the template.
- Do not repeat the original source text as a heading or title. The app already shows it separately. Start with section 1.
- Do not leave any heading or field label in English unless \(explanationLanguage) is English.

Template:
\(template)
"""
            user = """
Create a clear learning card for an English learner. Explain this text in \(explanationLanguage):

\(text)
"""
            responseFormat = nil
        }

        let body = ChatCompletionsRequest(
            model: model,
            messages: [
                .init(role: "system", content: system),
                .init(role: "user", content: user)
            ],
            temperature: 0.2,
            responseFormat: responseFormat
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
        let fallbackPrompt = APICost.estimateTokenCount(system) + APICost.estimateTokenCount(user)
        let usage = APICost.ChatUsage(
            promptTokens: decoded.usage?.resolvedPromptTokens ?? fallbackPrompt,
            completionTokens: decoded.usage?.resolvedCompletionTokens ?? APICost.estimateTokenCount(content),
            cachedPromptTokens: decoded.usage?.cachedPromptTokens ?? 0
        )

        if useStructuredJapanese {
            let cleaned = content
                .replacingOccurrences(of: "```json", with: "")
                .replacingOccurrences(of: "```", with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            guard let jsonData = cleaned.data(using: .utf8),
                  let dto = try? JSONDecoder().decode(CardExplanationDTO.self, from: jsonData) else {
                // Fall back to markdown parse if the model ignored JSON mode.
                return ExplanationResult(markdown: content, usage: usage)
            }
            return ExplanationResult(markdown: dto.makeExplanation().asMarkdown(), explanation: dto.makeExplanation(), usage: usage)
        }

        return ExplanationResult(markdown: content, usage: usage)
    }

    private static func writingStyle(for language: String) -> String {
        switch language {
        case "Japanese":
            return "対象は英語A2レベルの、外資企業を目指す50代の成人男性。子どもや中学生向けには書かない。丁寧で、見下さない大人の日本語。ですます調。文法用語を使うなら、すぐにかっこで平易な言い換えを付ける。「自然な日本語訳」は、英語の語順をなぞらない。日本語として自然な語順に組み替える。慣用句は意味で訳す（where / come in / that's why などを直訳しない）。専門用語は通称を残し、初出でかっこ補足する。悪い訳の例: 「それがCAN（コントローラーエリアネットワーク）が登場したところです。」（それが／が／ところです、が英語の骨格のまま）。良い訳の例: 「そこで登場したのが、CAN（コントローラー・エリア・ネットワーク）です。」"
        case "Vietnamese":
            return "Viết bằng tiếng Việt tự nhiên, lịch sự, dành cho người lớn trình độ A2 muốn làm việc ở công ty nước ngoài. Không viết như cho học sinh. Câu ngắn. Thuật ngữ ngữ pháp thì giải thích ngay bằng lời dễ hiểu."
        case "Korean":
            return "영어 A2 수준이며 외국계 기업을 목표로 하는 50대 성인 남성을 대상으로 쓴다. 아이나 중학생에게 말하듯 쓰지 않는다. 공손하고 어른스러운 한국어. 문법 용어를 쓰면 바로 쉬운 말로 풀어 준다. 번역은 직역하지 않고, 직장에서도 쓸 수 있는 자연스러운 한국어로 한다."
        case "Simplified Chinese":
            return "写给英语约A2、想进入外企的50多岁成年男性。不要写成给中学生看的。用礼貌、不俯就的成人简体中文。句子要短。若使用语法术语，立刻用白话解释。翻译不要逐字直译，要用职场也能用的自然中文。"
        case "Traditional Chinese":
            return "寫給英語約A2、想進入外商公司的50多歲成年男性。不要寫成給國中生看的。用禮貌、不俯就的成人繁體中文。句子要短。若使用文法術語，立刻用白話解釋。翻譯不要逐字直譯，要用職場也能用的自然中文。"
        case "French":
            return "Écris en français naturel et respectueux, pour un homme d'une cinquantaine d'années (anglais A2) qui vise une entreprise étrangère. Pas un ton scolaire. Phrases courtes. Si tu utilises un terme grammatical, explique-le tout de suite. La traduction doit être idiomatique, utile au travail, pas mot à mot."
        case "Spanish":
            return "Escribe en español natural y respetuoso, para un hombre de unos 50 años (inglés A2) que quiere trabajar en una empresa extranjera. Nada de tono escolar. Frases cortas. Si usas un término gramatical, explícalo de inmediato. La traducción debe ser idiomática y útil en el trabajo, no literal."
        case "German":
            return "Schreibe in natürlichem, respektvollem Deutsch für einen Mann Anfang/Mitte 50 mit Englisch auf A2, der in einem ausländischen Unternehmen arbeiten will. Kein Schulbuchton. Kurze Sätze. Grammatikbegriffe sofort erklären. Die Übersetzung soll idiomatisch und im Beruf brauchbar sein, nicht wörtlich."
        default:
            return "Write in clear adult English an A2 learner can follow. Short sentences. Common words. Respectful, not childish. If you use a grammar term, explain it immediately in plain words. Translations should sound natural at work, not word-for-word."
        }
    }

    private static func localizedExplanationTemplate(for language: String) -> String {
        switch language {
        case "Japanese":
            return """
            ## 1. 日本語訳
            - 自然な日本語訳:
            - 自然な英語（学習用）:
            - どんなときに使う:
            - カジュアル / フォーマル:

            ## 2. 発音
            - 強く読む音:
            - 発音のコツ:

            ## 3. 構造
            - 種類: 単語 / フレーズ / 文
            - パーツごと（英語の原文を切る。各パーツは「英語 = 日本語」。訳文は切らない）:
            - 同じ型で言えるパターン（英語の型 + 短い日本語。日本語の文型にしない）:

            ## 4. 文法
            - 時制・形（いま / 過去 / 進行など）:
            - 冠詞（a / an / the / なし）:
            - 前置詞:
            - この文に出るほかの文法（可算・不可算、動詞の形、助動詞、関係詞など）:
            - なぜこの形なのか（原文の語を使って、似た形との違いも）:

            ## 5. 語彙
            - 2〜5個。各項目は「**英語の語句** = 日本語の意味 / よく一緒に使う英語」。日本語の語句を並べない:

            ## 6. 例文
            - 例文1（太字で学習箇所を示す）:
            - 意味:
            - 例文2:
            - 意味:

            ## 7. 注意点
            - 似た表現との違い:
            - やりがちなミス:

            ## 8. 要点
            - 短いポイントを3つ:
            """
        case "Vietnamese":
            return """
            ## 1. Ý nghĩa
            - Bản dịch tiếng Việt tự nhiên:
            - Câu tiếng Anh tự nhiên (để học):
            - Khi nào dùng:
            - Thân mật / trang trọng:

            ## 2. Cách đọc
            - Âm nhấn:
            - Mẹo phát âm:

            ## 3. Cấu trúc
            - Loại: từ / cụm từ / câu
            - Từng phần (cắt tiếng Anh gốc theo thứ tự. Mỗi phần: English = nghĩa tiếng Việt. Không cắt bản dịch):
            - Mẫu câu có thể dùng lại (mẫu tiếng Anh + nghĩa ngắn):

            ## 4. Ngữ pháp
            - Thì / dạng (hiện tại / quá khứ / đang diễn ra...):
            - Mạo từ (a / an / the / không có):
            - Giới từ:
            - Ngữ pháp khác trong câu này (đếm được / không đếm được, dạng động từ, trợ động từ, mệnh đề quan hệ...):
            - Vì sao dùng dạng này (dùng đúng chữ trong nguyên văn, so với dạng gần giống):

            ## 5. Từ vựng
            - 2 đến 5 mục. Mỗi mục: **English** = nghĩa tiếng Việt / cụm tiếng Anh đi kèm. Không liệt kê bản dịch:

            ## 6. Ví dụ
            - Ví dụ 1 (in đậm phần cần học):
            - Nghĩa:
            - Ví dụ 2:
            - Nghĩa:

            ## 7. Lưu ý
            - Khác với cách nói gần giống:
            - Lỗi người học hay mắc:

            ## 8. Điểm chính
            - 3 ý ngắn:
            """
        case "Korean":
            return """
            ## 1. 의미
            - 자연스러운 한국어:
            - 자연스러운 영어 (학습용):
            - 언제 쓰나:
            - 캐주얼 / 격식:

            ## 2. 발음
            - 강하게 읽는 부분:
            - 발음 팁:

            ## 3. 구조
            - 유형: 단어 / 구 / 문장
            - 조각별로 (영어 원문을 자른다. 각 조각은 English = 한국어. 번역문은 자르지 않는다):
            - 같은 틀로 말하는 패턴 (영어 틀 + 짧은 한국어. 한국어 문형으로 쓰지 않는다):

            ## 4. 문법
            - 시제 / 형태 (지금 / 과거 / 진행 등):
            - 관사 (a / an / the / 없음):
            - 전치사:
            - 이 문에 나오는 다른 문법 (가산/불가산, 동사 형태, 조동사, 관계절 등):
            - 왜 이 형태인지 (원문 단어를 쓰고, 비슷한 형태와 비교):

            ## 5. 어휘
            - 2~5개. 각 항목은 **English** = 한국어 뜻 / 자주 같이 쓰는 영어. 번역어를 항목으로 쓰지 않는다:

            ## 6. 예문
            - 예문 1 (배울 부분을 굵게):
            - 의미:
            - 예문 2:
            - 의미:

            ## 7. 주의점
            - 비슷한 표현과의 차이:
            - 학습자가 자주 하는 실수:

            ## 8. 요점
            - 짧은 포인트 3개:
            """
        case "Simplified Chinese":
            return """
            ## 1. 意思
            - 自然的简体中文:
            - 自然的英语（用来学）:
            - 什么时候用:
            - 随意 / 正式:

            ## 2. 发音
            - 重读的部分:
            - 发音提示:

            ## 3. 结构
            - 类型: 单词 / 短语 / 句子
            - 按英语原文拆开（每段: English = 中文。不要拆译文）:
            - 可以套用的句型（英语句型 + 短中文。不要写成中文句型）:

            ## 4. 语法
            - 时态 / 形式（现在 / 过去 / 进行等）:
            - 冠词（a / an / the / 不用）:
            - 介词:
            - 这句话里其他重要语法（可数/不可数、动词形式、助动词、定语从句等）:
            - 为什么用这个形式（用原文的词，并和相近形式对比）:

            ## 5. 词汇
            - 2到5个。每项: **English** = 中文意思 / 常一起出现的英语。不要把译文当成要记的词:

            ## 6. 例句
            - 例句1（学习部分加粗）:
            - 意思:
            - 例句2:
            - 意思:

            ## 7. 注意
            - 和相近说法的差别:
            - 学习者常犯的错:

            ## 8. 要点
            - 3个短要点:
            """
        case "Traditional Chinese":
            return """
            ## 1. 意思
            - 自然的繁體中文:
            - 自然的英語（用來學）:
            - 什麼時候用:
            - 隨興 / 正式:

            ## 2. 發音
            - 重讀的部分:
            - 發音提示:

            ## 3. 結構
            - 類型: 單字 / 片語 / 句子
            - 依英語原文拆開（每段: English = 中文。不要拆譯文）:
            - 可以套用的句型（英語句型 + 短中文。不要寫成中文句型）:

            ## 4. 文法
            - 時態 / 形式（現在 / 過去 / 進行等）:
            - 冠詞（a / an / the / 不用）:
            - 介詞:
            - 這句裡其他重要文法（可數/不可數、動詞形式、助動詞、關係子句等）:
            - 為什麼用這個形式（用原文的詞，並和相近形式對比）:

            ## 5. 詞彙
            - 2到5個。每項: **English** = 中文意思 / 常一起出現的英語。不要把譯文當成要記的詞:

            ## 6. 例句
            - 例句1（學習部分加粗）:
            - 意思:
            - 例句2:
            - 意思:

            ## 7. 注意
            - 和相近說法的差別:
            - 學習者常犯的錯:

            ## 8. 要點
            - 3個短要點:
            """
        case "French":
            return """
            ## 1. Sens
            - Traduction naturelle en français:
            - Anglais naturel (à apprendre):
            - Quand l'utiliser:
            - Familier / formel:

            ## 2. Prononciation
            - Accent (syllabe forte):
            - Conseil de prononciation:

            ## 3. Structure
            - Type: mot / groupe de mots / phrase
            - Morceau par morceau (couper l'anglais source. Chaque morceau: English = français. Ne pas couper la traduction):
            - Un modèle à réutiliser (modèle anglais + court français):

            ## 4. Grammaire
            - Temps / forme (présent / passé / en cours...):
            - Articles (a / an / the / aucun):
            - Prépositions:
            - Autre grammaire dans ce texte (comptable / non comptable, forme du verbe, auxiliaires, relatives...):
            - Pourquoi cette forme (avec les mots du texte, et un court contraste):

            ## 5. Lexique
            - 2 à 5 items. Chaque item: **English** = sens en français / collocations anglaises. Ne pas lister la traduction:

            ## 6. Exemples
            - Exemple 1 (mettre en gras le point à apprendre):
            - Sens:
            - Exemple 2:
            - Sens:

            ## 7. Points d'attention
            - Différence avec une expression proche:
            - Erreur fréquente des apprenants:

            ## 8. À retenir
            - 3 points courts:
            """
        case "Spanish":
            return """
            ## 1. Significado
            - Traducción natural al español:
            - Inglés natural (para aprender):
            - Cuándo usarlo:
            - Informal / formal:

            ## 2. Pronunciación
            - Acento (sílaba fuerte):
            - Consejo de pronunciación:

            ## 3. Estructura
            - Tipo: palabra / frase / oración
            - Trozo a trozo (cortar el inglés original. Cada trozo: English = español. No cortar la traducción):
            - Un patrón para reutilizar (patrón en inglés + español breve):

            ## 4. Gramática
            - Tiempo / forma (presente / pasado / en curso...):
            - Artículos (a / an / the / ninguno):
            - Preposiciones:
            - Otra gramática de este texto (contable / incontable, forma del verbo, auxiliares, oraciones de relativo...):
            - Por qué se usa esta forma (con las palabras del texto y un contraste breve):

            ## 5. Léxico
            - 2 a 5 ítems. Cada ítem: **English** = significado en español / colocaciones en inglés. No listar la traducción:

            ## 6. Ejemplos
            - Ejemplo 1 (en negrita lo que hay que aprender):
            - Significado:
            - Ejemplo 2:
            - Significado:

            ## 7. Atención
            - Diferencia con una expresión parecida:
            - Error frecuente de quienes aprenden:

            ## 8. Puntos clave
            - 3 puntos cortos:
            """
        case "German":
            return """
            ## 1. Bedeutung
            - Natürliche deutsche Übersetzung:
            - Natürliches Englisch (zum Lernen):
            - Wann man es sagt:
            - Locker / förmlich:

            ## 2. Aussprache
            - Betonte Silbe:
            - Aussprachetipp:

            ## 3. Struktur
            - Typ: Wort / Phrase / Satz
            - Stück für Stück (das englische Original zerlegen. Jedes Stück: English = Deutsch. Nicht die Übersetzung zerlegen):
            - Ein Muster zum Wiederverwenden (englisches Muster + kurzes Deutsch):

            ## 4. Grammatik
            - Zeitform (jetzt / Vergangenheit / Verlauf...):
            - Artikel (a / an / the / keiner):
            - Präpositionen:
            - Weitere Grammatik in diesem Text (zählbar / unzählbar, Verbform, Hilfsverben, Relativsätze...):
            - Warum diese Form (mit den Wörtern aus dem Text und einem kurzen Vergleich):

            ## 5. Wortschatz
            - 2 bis 5 Einträge. Jeder Eintrag: **English** = deutsche Bedeutung / englische Kollokationen. Nicht die Übersetzung auflisten:

            ## 6. Beispiele
            - Beispiel 1 (Lernstelle fett):
            - Bedeutung:
            - Beispiel 2:
            - Bedeutung:

            ## 7. Hinweise
            - Unterschied zu einer ähnlichen Wendung:
            - Typischer Fehler von Lernenden:

            ## 8. Kernpunkte
            - 3 kurze Punkte:
            """
        default:
            return """
            ## 1. Meaning
            - Natural translation in \(language):
            - Natural English to remember:
            - When to use it:
            - Casual or formal:

            ## 2. Pronunciation
            - Stress (CAPITALS on the strong part):
            - Pronunciation tip:

            ## 3. Structure
            - Type: word / phrase / sentence
            - Piece by piece (split the SOURCE English in order. Each chunk: English = easy meaning. Do not split the translation):
            - A pattern you can reuse (an English pattern + a short gloss):

            ## 4. Grammar
            - Tense / form (now / past / ongoing, etc.):
            - Articles (a / an / the / none):
            - Prepositions:
            - Other grammar in this text (countable vs uncountable, verb form, auxiliaries, relative clauses, etc.):
            - Why this form is used (with the original words, plus a short contrast):

            ## 5. Vocabulary
            - 2 to 5 items. Each item: **English** = easy meaning / English collocations. Do not list translations as the words to remember:

            ## 6. Examples
            - Example 1 (bold the part to learn):
            - Meaning:
            - Example 2:
            - Meaning:

            ## 7. Notes
            - Similar expression vs this one:
            - Common learner mistake:

            ## 8. Takeaways
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
    struct ResponseFormat: Codable {
        let type: String
    }
    let model: String
    let messages: [Message]
    let temperature: Double?
    let responseFormat: ResponseFormat?

    enum CodingKeys: String, CodingKey {
        case model
        case messages
        case temperature
        case responseFormat = "response_format"
    }
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
    struct Usage: Codable {
        let promptTokens: Int?
        let completionTokens: Int?
        let inputTokens: Int?
        let outputTokens: Int?
        let promptTokensDetails: PromptTokensDetails?

        struct PromptTokensDetails: Codable {
            let cachedTokens: Int?

            enum CodingKeys: String, CodingKey {
                case cachedTokens = "cached_tokens"
            }
        }

        enum CodingKeys: String, CodingKey {
            case promptTokens = "prompt_tokens"
            case completionTokens = "completion_tokens"
            case inputTokens = "input_tokens"
            case outputTokens = "output_tokens"
            case promptTokensDetails = "prompt_tokens_details"
        }

        var resolvedPromptTokens: Int? { promptTokens ?? inputTokens }
        var resolvedCompletionTokens: Int? { completionTokens ?? outputTokens }
        var cachedPromptTokens: Int { promptTokensDetails?.cachedTokens ?? 0 }
    }
    let choices: [Choice]
    let usage: Usage?
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

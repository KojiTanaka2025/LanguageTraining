import SwiftUI
import Combine

struct SettingsView: View {
    @EnvironmentObject private var settings: AppSettings
    @Environment(\.dismiss) private var dismiss

    @State private var errorMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("設定")
                .font(.title2)
                .bold()

            Form {
                Section("OpenAI") {
                    SecureField("APIキー（Keychainに保存）", text: $settings.apiKey)
                        .textContentType(.password)

                    TextField("モデル", text: $settings.openAIModel)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        TextField("Base URL", text: $settings.openAIBaseURL)
                            .autocorrectionDisabled()
                        
                        Text("例: https://api.openai.com")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        
                        if let previewURL = constructedURL {
                            Text("実際の接続先: \(previewURL)")
                                .font(.caption)
                                .foregroundStyle(.blue)
                                .textSelection(.enabled)
                        } else {
                            Text("⚠️ URLが不正です")
                                .font(.caption)
                                .foregroundStyle(.red)
                        }
                    }
                }
            }
            .formStyle(.grouped)

            if let errorMessage {
                Text(errorMessage)
                    .foregroundStyle(.red)
                    .font(.callout)
                    .textSelection(.enabled)
            }

            HStack {
                Spacer()
                Button("キャンセル") { dismiss() }
                Button("保存") {
                    do {
                        try settings.save()
                        dismiss()
                    } catch {
                        errorMessage = error.localizedDescription
                    }
                }
                .keyboardShortcut(.defaultAction)
            }
            
            // デバッグ情報
            Divider()
            Text("💡 ヒント: Base URLは通常変更不要です。デフォルト値で動作します。")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(20)
        .frame(width: 600)
    }
    
    private var constructedURL: String? {
        let trimmed = settings.openAIBaseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let base = URL(string: trimmed) else { return nil }
        var urlString = base.absoluteString
        while urlString.hasSuffix("/") {
            urlString.removeLast()
        }
        urlString += "/v1/chat/completions"
        return urlString
    }
}


import Foundation
import SwiftUI
import Combine

@MainActor
final class AppSettings: ObservableObject {
    @Published var isSettingsPresented: Bool = false

    @Published var openAIModel: String = "gpt-4o-mini" {
        didSet {
            UserDefaults.standard.set(openAIModel, forKey: "openAIModel")
        }
    }
    
    @Published var openAIBaseURL: String = "https://api.openai.com" {
        didSet {
            UserDefaults.standard.set(openAIBaseURL, forKey: "openAIBaseURL")
        }
    }

    @Published var apiKey: String = "" {
        didSet { apiKeyDirty = true }
    }
    private var apiKeyDirty = false

    private let service = "EnglishCard"
    private let account = "OPENAI_API_KEY"

    init() {
        // UserDefaultsから設定を読み込み
        if let savedModel = UserDefaults.standard.string(forKey: "openAIModel") {
            self.openAIModel = savedModel
        }
        if let savedBaseURL = UserDefaults.standard.string(forKey: "openAIBaseURL") {
            self.openAIBaseURL = savedBaseURL
        }
        
        // 初期化時に同期的にKeychainから読み込む
        self.apiKey = (try? Keychain.readString(service: service, account: account)) ?? ""
        self.apiKeyDirty = false
    }

    func save() throws {
        if apiKey.isEmpty {
            try Keychain.delete(service: service, account: account)
        } else if apiKeyDirty {
            try Keychain.upsertString(apiKey, service: service, account: account)
        }
        apiKeyDirty = false
        
        // UserDefaultsに設定を保存
        UserDefaults.standard.set(openAIModel, forKey: "openAIModel")
        UserDefaults.standard.set(openAIBaseURL, forKey: "openAIBaseURL")
    }
}


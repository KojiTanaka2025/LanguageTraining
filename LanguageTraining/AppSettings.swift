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

    @Published var explanationLanguage: String = "English" {
        didSet {
            UserDefaults.standard.set(explanationLanguage, forKey: "explanationLanguage")
        }
    }

    @Published var apiKey: String = "" {
        didSet { apiKeyDirty = true }
    }
    private var apiKeyDirty = false

    private let service = "LanguageTraining"
    private let legacyService = "EnglishCard"
    private let account = "OPENAI_API_KEY"
    private var loadedAPIKeyFromLegacyService = false

    init() {
        // UserDefaultsから設定を読み込み
        if let savedModel = UserDefaults.standard.string(forKey: "openAIModel") {
            self.openAIModel = savedModel
        }
        if let savedBaseURL = UserDefaults.standard.string(forKey: "openAIBaseURL") {
            self.openAIBaseURL = savedBaseURL
        }
        if let savedExplanationLanguage = UserDefaults.standard.string(forKey: "explanationLanguage") {
            self.explanationLanguage = savedExplanationLanguage
        }
        
        // 初期化時に同期的にKeychainから読み込む
        if let savedAPIKey = try? Keychain.readString(service: service, account: account) {
            self.apiKey = savedAPIKey
        } else if let legacyAPIKey = try? Keychain.readString(service: legacyService, account: account) {
            self.apiKey = legacyAPIKey
            self.loadedAPIKeyFromLegacyService = true
        }
        self.apiKeyDirty = false
    }

    func save() throws {
        if apiKey.isEmpty {
            try Keychain.delete(service: service, account: account)
            try Keychain.delete(service: legacyService, account: account)
        } else if apiKeyDirty || loadedAPIKeyFromLegacyService {
            try Keychain.upsertString(apiKey, service: service, account: account)
        }
        apiKeyDirty = false
        loadedAPIKeyFromLegacyService = false
        
        // UserDefaultsに設定を保存
        UserDefaults.standard.set(openAIModel, forKey: "openAIModel")
        UserDefaults.standard.set(openAIBaseURL, forKey: "openAIBaseURL")
        UserDefaults.standard.set(explanationLanguage, forKey: "explanationLanguage")
    }
}

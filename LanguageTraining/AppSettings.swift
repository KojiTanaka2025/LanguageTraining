import Foundation
import SwiftUI
import Combine

@MainActor
final class AppSettings: ObservableObject {
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

    /// User-defined category names in addition to the built-in presets.
    @Published var customCategories: [String] = [] {
        didSet {
            UserDefaults.standard.set(customCategories, forKey: "customCategories")
        }
    }

    /// Last category chosen when saving a card.
    @Published var lastSaveCategory: String = CardCategory.presets[0] {
        didSet {
            UserDefaults.standard.set(lastSaveCategory, forKey: "lastSaveCategory")
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
        if let savedCustom = UserDefaults.standard.stringArray(forKey: "customCategories") {
            self.customCategories = savedCustom
                .map(CardCategory.normalized)
                .filter { !$0.isEmpty && !CardCategory.presets.contains($0) }
        }
        if let savedLastCategory = UserDefaults.standard.string(forKey: "lastSaveCategory") {
            self.lastSaveCategory = savedLastCategory
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

    func categoryChoices(usedOnCards: [String] = []) -> [String] {
        CardCategory.availableNames(custom: customCategories, usedOnCards: usedOnCards)
    }

    func addCustomCategory(_ name: String) -> Bool {
        let trimmed = CardCategory.normalized(name)
        guard !trimmed.isEmpty else { return false }
        guard !CardCategory.presets.contains(trimmed) else { return true }
        guard !customCategories.contains(trimmed) else { return true }
        customCategories.append(trimmed)
        return true
    }

    func removeCustomCategory(_ name: String) {
        let trimmed = CardCategory.normalized(name)
        customCategories.removeAll { $0 == trimmed }
        if lastSaveCategory == trimmed {
            lastSaveCategory = CardCategory.presets[0]
        }
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
        UserDefaults.standard.set(customCategories, forKey: "customCategories")
        UserDefaults.standard.set(lastSaveCategory, forKey: "lastSaveCategory")
    }
}

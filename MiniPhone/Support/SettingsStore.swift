import Foundation
import Observation

/// P0 阶段只存三样东西：接口地址、模型名、密钥。
/// 地址和模型走 UserDefaults，密钥只进 Keychain。
///
/// 刻意不用属性观察器：`@Observable` 宏会把存储属性改造成计算属性，
/// 叠 didSet 容易踩宏展开的坑。改成显式 `persist()`，由界面在改动时调用。
@Observable
final class SettingsStore {
    private enum DefaultsKey {
        static let baseURL = "llm.baseURL"
        static let model = "llm.model"
    }

    private static let keychainAccount = "llm.apiKey"

    var baseURL: String = LLMConfig.defaultBaseURL
    var model: String = LLMConfig.defaultModel
    var apiKey: String = ""

    init() {
        let defaults = UserDefaults.standard
        if let storedBaseURL = defaults.string(forKey: DefaultsKey.baseURL) {
            baseURL = storedBaseURL
        }
        if let storedModel = defaults.string(forKey: DefaultsKey.model) {
            model = storedModel
        }
        if let storedKey = KeychainStore.string(for: Self.keychainAccount) {
            apiKey = storedKey
        }
    }

    var config: LLMConfig {
        LLMConfig(baseURL: baseURL, model: model, apiKey: apiKey)
    }

    var isConfigured: Bool {
        !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    func persist() {
        UserDefaults.standard.set(baseURL, forKey: DefaultsKey.baseURL)
        UserDefaults.standard.set(model, forKey: DefaultsKey.model)
        KeychainStore.set(apiKey, for: Self.keychainAccount)
    }
}

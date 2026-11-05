import Foundation
import Observation

/// 本机设置。
///
/// 接口地址、模型名、采样参数、壁纸走 UserDefaults；密钥只进 Keychain，不落 UserDefaults。
///
/// 刻意不用属性观察器：`@Observable` 宏会把存储属性改造成计算属性，
/// 叠 didSet 容易踩宏展开的坑。改成显式 `persist()`，由界面在改动时调用。
@Observable
final class SettingsStore {
    private enum DefaultsKey {
        static let baseURL = "llm.baseURL"
        static let model = "llm.model"
        static let wallpaper = "shell.wallpaper"
        static let temperature = "llm.temperature"
        static let maxTokens = "llm.maxTokens"
        static let notifyReplies = "notify.replies"
        static let billingMode = "llm.billingMode"
        static let billingByModel = "llm.billingByModel"
        static let allowPhoneLookups = "privacy.allowPhoneLookups"
        static let videoWallpaper = "shell.videoWallpaper"
    }

    private static let keychainAccount = "llm.apiKey"

    var baseURL: String = LLMConfig.defaultBaseURL
    var model: String = LLMConfig.defaultModel
    var apiKey: String = ""
    var wallpaperRaw: String = WallpaperTheme.midnight.rawValue
    var temperature: Double = 0.9
    var maxTokens: Int = 900
    /// 回复到了但 App 不在前台时，发一条本地通知（不需要推送证书）。
    var notifyReplies: Bool = true
    /// 当前模型的计费模式。按模型名记住，换模型时自动带出对应值。
    var billingModeRaw: String = BillingMode.perToken.rawValue
    /// 关掉时，电量、机型、使用记录一律不进提示词。默认关。
    var allowPhoneLookups: Bool = false
    var videoWallpaperEnabled: Bool = false

    /// model → BillingMode.rawValue。
    private var billingByModel: [String: String] = [:]

    init() {
        let defaults = UserDefaults.standard
        if let storedBaseURL = defaults.string(forKey: DefaultsKey.baseURL) {
            baseURL = storedBaseURL
        }
        if let storedModel = defaults.string(forKey: DefaultsKey.model) {
            model = storedModel
        }
        if let storedWallpaper = defaults.string(forKey: DefaultsKey.wallpaper) {
            wallpaperRaw = storedWallpaper
        }
        if defaults.object(forKey: DefaultsKey.temperature) != nil {
            temperature = defaults.double(forKey: DefaultsKey.temperature)
        }
        if defaults.object(forKey: DefaultsKey.maxTokens) != nil {
            maxTokens = defaults.integer(forKey: DefaultsKey.maxTokens)
        }
        if defaults.object(forKey: DefaultsKey.notifyReplies) != nil {
            notifyReplies = defaults.bool(forKey: DefaultsKey.notifyReplies)
        }
        billingByModel = defaults.dictionary(forKey: DefaultsKey.billingByModel) as? [String: String] ?? [:]
        billingModeRaw = billingByModel[model]
            ?? defaults.string(forKey: DefaultsKey.billingMode)
            ?? BillingMode.perToken.rawValue
        allowPhoneLookups = defaults.bool(forKey: DefaultsKey.allowPhoneLookups)
        videoWallpaperEnabled = defaults.bool(forKey: DefaultsKey.videoWallpaper)
        if let storedKey = KeychainStore.string(for: Self.keychainAccount) {
            apiKey = storedKey
        }
    }

    var config: LLMConfig {
        LLMConfig(
            baseURL: baseURL,
            model: model,
            apiKey: apiKey,
            temperature: temperature,
            maxTokens: maxTokens
        )
    }

    var isConfigured: Bool {
        !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var wallpaperTheme: WallpaperTheme {
        WallpaperTheme(rawValue: wallpaperRaw) ?? .midnight
    }

    var billingMode: BillingMode {
        BillingMode(rawValue: billingModeRaw) ?? .perToken
    }

    var generationPlan: GenerationPlan {
        GenerationPlan(mode: billingMode)
    }

    func setBillingMode(_ mode: BillingMode) {
        billingModeRaw = mode.rawValue
        billingByModel[model] = mode.rawValue
        persist()
    }

    /// 换模型后把该模型上次选的计费模式带出来。
    func syncBillingModeForModel() {
        let expected = billingByModel[model] ?? BillingMode.perToken.rawValue
        if billingModeRaw != expected {
            billingModeRaw = expected
        }
    }

    func setWallpaper(_ theme: WallpaperTheme) {
        guard wallpaperRaw != theme.rawValue else { return }
        wallpaperRaw = theme.rawValue
        persist()
    }

    func persist() {
        let defaults = UserDefaults.standard
        defaults.set(baseURL, forKey: DefaultsKey.baseURL)
        defaults.set(model, forKey: DefaultsKey.model)
        defaults.set(wallpaperRaw, forKey: DefaultsKey.wallpaper)
        defaults.set(temperature, forKey: DefaultsKey.temperature)
        defaults.set(maxTokens, forKey: DefaultsKey.maxTokens)
        defaults.set(notifyReplies, forKey: DefaultsKey.notifyReplies)
        defaults.set(billingModeRaw, forKey: DefaultsKey.billingMode)
        defaults.set(billingByModel, forKey: DefaultsKey.billingByModel)
        defaults.set(allowPhoneLookups, forKey: DefaultsKey.allowPhoneLookups)
        defaults.set(videoWallpaperEnabled, forKey: DefaultsKey.videoWallpaper)
        KeychainStore.set(apiKey, for: Self.keychainAccount)
    }
}
